import logging
import warnings
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed, Semaphore
from azure.identity import AzureCliCredential
from azure.monitor.query import LogsQueryClient, LogsQueryStatus, LogsBatchQuery
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceExistsError
import time
import pandas as pd
import io
import re
import sys

# Suppress datetime tzinfo warnings from Azure SDK
warnings.filterwarnings(
    "ignore",
    message=r"Datetime with no tzinfo.*",
    category=UserWarning
)

# Setup logging (console only shows INFO for daily progress)
logger = logging.getLogger("ExportPipeline")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

# Auth and clients
credential = AzureCliCredential()
workspace_id = "<WORKSPACE_ID>"
logs_client = LogsQueryClient(credential)
storage_account_name = "<STORAGE_ACCOUNT>"
account_url = f"https://{storage_account_name}.blob.core.windows.net"
blob_service_client = BlobServiceClient(
    account_url,
    credential=credential,
    retry_total=5, retry_connect=5, retry_read=5, retry_status=5
)

# Time range: last 365 days up to today (using UTC timezone)
today = datetime.now(timezone.utc)
start_of_today = datetime.combine(today.date(), datetime.min.time(), tzinfo=timezone.utc)
start_time = start_of_today - timedelta(days=365)
end_time = start_of_today
table_name = "<TABLE_NAME>"

# Estimate optimal chunk size based on probe query
def estimate_optimal_chunk_size(table_name, day_start):
    probe_start = day_start
    probe_end = probe_start + timedelta(hours=1)
    kql = (f"{table_name} | where TimeGenerated >= datetime({probe_start.isoformat()}) "
           f"and TimeGenerated < datetime({probe_end.isoformat()})")
    try:
        resp = logs_client.query_workspace(
            workspace_id,
            query=kql,
            timespan=(probe_start, probe_end),
            include_statistics=True
        )
        stats = resp.statistics
        if not stats:
            return timedelta(hours=1)
        bytes_returned = stats["query"]["resultSize"]["tables"]["bytes"]
        duration_sec = (probe_end - probe_start).total_seconds()
        rate = bytes_returned / duration_sec
        target_bytes = 50 * 1024 * 1024  # 50MB
        optimal_sec = target_bytes / rate
        optimal = timedelta(seconds=optimal_sec)
        return min(max(optimal, timedelta(minutes=1)), timedelta(hours=3))
    except Exception as e:
        logger.warning(f"Fallback to 1h chunk: Failed to estimate size for {day_start.date()}: {e}")
        return timedelta(hours=1)

# Export a single day's data using batch query
def export_day(table_name, day_start, container_client, semaphore):
    failures = []
    day_str = day_start.strftime('%Y-%m-%d')
    day_end = day_start + timedelta(days=1)

    # Estimate best chunk size
    chunk = estimate_optimal_chunk_size(table_name, day_start)
    intervals = []
    current = day_start
    while current < day_end:
        next_time = min(current + chunk, day_end)
        intervals.append((current, next_time))
        current = next_time

    # Prepare batch
    batch = LogsBatchQuery()
    for i, (start, end) in enumerate(intervals):
        query = f"{table_name} | where TimeGenerated >= datetime({start.isoformat()}) and TimeGenerated < datetime({end.isoformat()})"
        batch.add_query(
            workspace_id=workspace_id,
            query=query,
            timespan=(start, end),
            include_statistics=True,
            query_id=f"chunk_{i}"
        )

    # Send batch with semaphore for rate limiting
    with semaphore:
        try:
            results = logs_client.query_batch(batch)
        except Exception as e:
            failures.append(f"Batch query failed for {day_str}: {e}")
            return day_str, failures

    # Process results
    for qid, response in results.items():
        i = int(qid.split("_")[-1])
        start, end = intervals[i]
        if response.status == LogsQueryStatus.SUCCESS:
            tables = response.tables
        elif response.status == LogsQueryStatus.PARTIAL:
            failures.append(f"Partial data for {day_str} {start}-{end}: {response.partial_error}")
            tables = response.partial_data or []
        else:
            failures.append(f"Query {qid} failed with status {response.status} for {day_str} {start}-{end}")
            continue

        for table in tables:
            df = pd.DataFrame(table.rows, columns=[col.name for col in table.columns])
            if df.empty:
                continue
            blob_name = f"{table_name}_{day_str}_{i}.json"
            blob_client = container_client.get_blob_client(blob=blob_name)
            json_bytes = df.to_json(orient='records', lines=True).encode('utf-8')
            for attempt in range(3):
                try:
                    blob_client.upload_blob(io.BytesIO(json_bytes), overwrite=True)
                    break
                except Exception as err:
                    failures.append(f"Upload attempt {attempt+1} failed for {blob_name}: {err}")
                    time.sleep(2 ** attempt)
            else:
                failures.append(f"Failed to upload {blob_name}")

    return day_str, failures

# Create or get container
container_name = re.sub(r'[^a-zA-Z0-9]', '', table_name.lower())
try:
    container_client = blob_service_client.create_container(container_name)
except ResourceExistsError:
    container_client = blob_service_client.get_container_client(container_name)

# Build list of days in reverse order
days = [start_time + timedelta(days=i) for i in range((end_time - start_time).days)]
total_days = len(days)
completed = 0

# Limit concurrent client requests (rate limiting)
semaphore = Semaphore(10)  # max 10 concurrent requests

# Parallel daily exports
max_workers = 16
with ThreadPoolExecutor(max_workers=max_workers) as executor:
    futures = {
        executor.submit(export_day, table_name, ds, container_client, semaphore): ds
        for ds in reversed(days)
    }
    for future in as_completed(futures):
        day_str, issues = future.result()
        completed += 1
        if issues:
            error_blob_name = f"00_export_issues_{day_str}.txt"
            error_blob_client = container_client.get_blob_client(blob=error_blob_name)
            error_content = "\n".join(issues).encode('utf-8')
            error_blob_client.upload_blob(io.BytesIO(error_content), overwrite=True)
        logger.info(f"Exported {day_str} ({completed}/{total_days} days, {completed/total_days*100:.1f}%)")

logger.info(f"All {total_days} days exported.")
