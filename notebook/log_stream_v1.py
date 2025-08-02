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

# Setup logging
logger = logging.getLogger("ExportPipeline")
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
handler.setFormatter(formatter)
logger.addHandler(handler)

# Auth and clients
credential = AzureCliCredential()  # or ManagedIdentityCredential()
workspace_id = "<WORKSPACE_ID>"
logs_client = LogsQueryClient(credential)
storage_account_name = "<STORAGE_ACCOUNT>"
account_url = f"https://{storage_account_name}.blob.core.windows.net"
blob_service_client = BlobServiceClient(account_url, credential=credential,
                                        retry_total=5, retry_connect=5, retry_read=5, retry_status=5)

# Time range: last 365 days up to today
today = datetime.utcnow()
start_of_today = datetime.combine(today, datetime.min.time())
start_time = start_of_today - timedelta(days=365)
end_time = start_of_today
time_chunk = timedelta(hours=1)
table_name = "<TABLE_NAME>"

# Function to export a time range for a table
def export_table(table_name, start_time, end_time, time_chunk, total_count_estimate):
    logger.info(f"[{table_name}] Exporting {start_time.date()} to {end_time.date()}")
    # Create or get container
    container_name = re.sub(r'[^a-zA-Z0-9]', '', table_name.lower())
    try:
        container_client = blob_service_client.create_container(container_name)
        logger.debug(f"Created container: {container_name}")
    except ResourceExistsError:
        container_client = blob_service_client.get_container_client(container_name)

    current = start_time
    original_chunk = time_chunk
    chunk_index = 0
    total_rows = 0

    while current < end_time:
        next_time = min(current + time_chunk, end_time)
        kql = (f"{table_name} | where TimeGenerated >= datetime({current.isoformat()}) "
               f"and TimeGenerated < datetime({next_time.isoformat()})")
        logger.debug(f"[{table_name}] Querying {current} to {next_time}")
        resp = None

        # Query with retries
        for attempt in range(3):
            try:
                resp = logs_client.query_workspace(workspace_id, query=kql, timespan=(current, next_time))
                break
            except Exception as err:
                logger.warning(f"[{table_name}] Query attempt {attempt+1} failed: {err}")
                time.sleep(2 ** attempt)
        if resp is None:
            logger.error(f"[{table_name}] All query attempts failed for {current} - {next_time}")
            current = next_time
            time_chunk = original_chunk
            continue

        # Determine data tables to process
        if resp.status == LogsQueryStatus.SUCCESS:
            data_tables = resp.tables
        elif resp.status == LogsQueryStatus.PARTIAL:
            logger.warning(f"[{table_name}] Partial result {current} to {next_time}: {resp.partial_error}")
            data_tables = resp.partial_data
        else:
            logger.error(f"[{table_name}] Unexpected status {resp.status} at {current}-{next_time}")
            data_tables = []

        # Process each returned table
        for table in data_tables:
            df_chunk = pd.DataFrame(table.rows, columns=[col.name for col in table.columns])
            if df_chunk.empty:
                continue
            total_rows += len(df_chunk)
            json_bytes = df_chunk.to_json(orient='records', lines=True).encode('utf-8')
            blob_name = f"{table_name}_{current.date()}_{next_time.date()}_{chunk_index}.json"
            blob_client = container_client.get_blob_client(blob=blob_name)
            # Upload with retries
            for attempt in range(3):
                try:
                    blob_client.upload_blob(io.BytesIO(json_bytes), overwrite=True)
                    logger.info(f"[{table_name}] Uploaded {blob_name} ({len(df_chunk)} rows)")
                    break
                except Exception as err:
                    logger.warning(f"[{table_name}] Upload attempt {attempt+1} failed: {err}")
                    time.sleep(2 ** attempt)
            else:
                logger.error(f"[{table_name}] Failed to upload chunk {chunk_index}")
            chunk_index += 1

        # Log progress
        if total_count_estimate:
            pct = total_rows / total_count_estimate * 100
            logger.info(f"[{table_name}] Progress: {total_rows}/{total_count_estimate} rows ({pct:.1f}%) exported")

        # Advance or adjust time
        if resp.status == LogsQueryStatus.SUCCESS:
            current = next_time
            time_chunk = original_chunk
        elif resp.status == LogsQueryStatus.PARTIAL:
            if time_chunk.total_seconds() > 60:
                time_chunk = time_chunk / 2  # smaller chunk on partial
                # keep current the same to retry this subrange
            else:
                logger.error(f"[{table_name}] Cannot split chunk further; skipping {current}-{next_time}")
                current = next_time
                time_chunk = original_chunk
        else:
            current = next_time
            time_chunk = original_chunk

    logger.info(f"[{table_name}] Finished export; total {total_rows} rows.")
    return total_rows

# Pre-count total rows for progress tracking
logger.info("Estimating total rows for export...")
count_resp = logs_client.query_workspace(workspace_id, query=f"{table_name} | count",
                                         timespan=(start_time, end_time))
if count_resp.status == LogsQueryStatus.SUCCESS and count_resp.tables:
    total_count = int(count_resp.tables[0].rows[0][0])
    logger.info(f"Estimated {total_count} total rows in {table_name}")
else:
    total_count = None
    logger.warning("Row count estimation failed or returned partial.")

# Split time range across workers
max_workers = 16
total_days = (end_time - start_time).days
days_per_worker = total_days // max_workers
remainder = total_days % max_workers
time_ranges = []
cs = start_time
for i in range(max_workers):
    extra = 1 if i < remainder else 0
    days = days_per_worker + extra
    ce = min(cs + timedelta(days=days), end_time)
    time_ranges.append((cs, ce))
    cs = ce

# Run exports in parallel
total_exported = 0
with ThreadPoolExecutor(max_workers=max_workers) as executor:
    futures = [
        executor.submit(export_table, table_name, ts, te, time_chunk, total_count)
        for ts, te in time_ranges
    ]
    for future in as_completed(futures):
        if future.exception():
            logger.error(f"Thread error: {future.exception()}")
        else:
            total_exported += future.result()

logger.info(f"✅ Export complete. Total rows exported: {total_exported}")
