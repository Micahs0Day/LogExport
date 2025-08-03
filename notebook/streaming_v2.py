import logging
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
from azure.identity import AzureCliCredential
from azure.monitor.query import LogsQueryClient, LogsQueryStatus
from azure.storage.blob import BlobServiceClient
from azure.core.exceptions import ResourceExistsError
import time
import pandas as pd
import io
import re
import sys

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

# Time range: last 365 days up to today
today = datetime.utcnow()
start_of_today = datetime.combine(today, datetime.min.time())
start_time = start_of_today - timedelta(days=365)
end_time = start_of_today
time_chunk = timedelta(hours=1)
table_name = "<TABLE_NAME>"

# Export a single day's data; return date and list of issues
def export_day(table_name, day_start, time_chunk, container_client):
    failures = []
    day_str = day_start.strftime('%Y-%m-%d')
    day_end = day_start + timedelta(days=1)
    current = day_start
    chunk_index = 0
    original_chunk = time_chunk

    while current < day_end:
        next_time = min(current + time_chunk, day_end)
        kql = (
            f"{table_name} | where TimeGenerated >= datetime({current.isoformat()}) "
            f"and TimeGenerated < datetime({next_time.isoformat()})"
        )
        # Query with retries
        resp = None
        for attempt in range(3):
            try:
                resp = logs_client.query_workspace(
                    workspace_id, query=kql, timespan=(current, next_time)
                )
                break
            except Exception as err:
                failures.append(
                    f"Query attempt {attempt+1} failed for {day_str} {current}-{next_time}: {err}"
                )
                time.sleep(2 ** attempt)
        if resp is None:
            failures.append(
                f"All query attempts failed for {day_str} {current}-{next_time}"
            )
            current = next_time
            time_chunk = original_chunk
            continue

        # Handle data or partial
        if resp.status == LogsQueryStatus.SUCCESS:
            tables = resp.tables
        elif resp.status == LogsQueryStatus.PARTIAL:
            failures.append(
                f"Partial data for {day_str} {current}-{next_time}: {resp.partial_error}"
            )
            tables = resp.partial_data or []
        else:
            failures.append(
                f"Unexpected status {resp.status} for {day_str} {current}-{next_time}"
            )
            tables = []

        # Process tables
        for table in tables:
            df = pd.DataFrame(table.rows, columns=[c.name for c in table.columns])
            if df.empty:
                continue
            json_bytes = df.to_json(orient='records', lines=True).encode('utf-8')
            blob_name = f"{table_name}_{day_str}_{chunk_index}.json"
            blob_client = container_client.get_blob_client(blob=blob_name)
            # Upload with retries
            for attempt in range(3):
                try:
                    blob_client.upload_blob(io.BytesIO(json_bytes), overwrite=True)
                    break
                except Exception as err:
                    failures.append(
                        f"Upload attempt {attempt+1} failed for {day_str} chunk {chunk_index}: {err}"
                    )
                    time.sleep(2 ** attempt)
            else:
                failures.append(
                    f"Failed to upload chunk {chunk_index} for {day_str}"
                )
            chunk_index += 1

        # Advance or adjust time_chunk
        if resp.status == LogsQueryStatus.SUCCESS:
            current = next_time
            time_chunk = original_chunk
        elif resp.status == LogsQueryStatus.PARTIAL:
            if time_chunk.total_seconds() > 60:
                time_chunk = time_chunk / 2
            else:
                failures.append(
                    f"Chunk too small; skipped {day_str} {current}-{next_time}"
                )
                current = next_time
                time_chunk = original_chunk
        else:
            current = next_time
            time_chunk = original_chunk

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

# Parallel daily exports
max_workers = 16
with ThreadPoolExecutor(max_workers=max_workers) as executor:
    futures = {
        executor.submit(export_day, table_name, ds, time_chunk, container_client): ds
        for ds in reversed(days)
    }
    for future in as_completed(futures):
        day_str, issues = future.result()
        completed += 1
        # Upload issues to blob storage with prefix to sort first
        if issues:
            error_blob_name = f"00_export_issues_{day_str}.txt"
            error_blob_client = container_client.get_blob_client(blob=error_blob_name)
            error_content = "\n".join(issues).encode('utf-8')
            error_blob_client.upload_blob(io.BytesIO(error_content), overwrite=True)
        # Console progress only
        logger.info(
            f"Exported {day_str} ({completed}/{total_days} days, {completed/total_days*100:.1f}%)"
        )

logger.info(f"All {total_days} days exported.")
