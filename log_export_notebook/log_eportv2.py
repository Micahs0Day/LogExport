def export_table(table_name, start_time, end_time, time_chunk):
    logger.info(f"Starting export for {table_name}")
    # Ensure container exists
    container_name = table_name.lower()
    container_name = remove_special_characters(container_name)
    try:
        container_client = blob_service_client.create_container(container_name)
    except ResourceExistsError:
        container_client = blob_service_client.get_container_client(container_name)
    # Collect data in chunks
    current = start_time
    all_chunks = []
    while current < end_time:
        next_time = min(current + time_chunk, end_time)
        kql = f"{table_name} | where TimeGenerated between (startofday(datetime({current.isoformat()})) .. startofday(datetime({next_time.isoformat()})))"
        logger.info(f"Querying {table_name} from {current} to {next_time}")
        # Simple retry logic for query
        for attempt in range(3):
            try:
                resp = logs_client.query_workspace(workspace_id, query=kql, timespan=(current, next_time))
                break
            except Exception as err:
                logger.warning(f"Query attempt {attempt+1} failed: {err}")
                time.sleep(2 ** attempt)
        else:
            logger.error(f"All query attempts failed for range {current} - {next_time}; skipping")
            current = next_time
            continue
        # Handle response
        if resp.status == LogsQueryStatus.SUCCESS:
            tables = resp.tables
        else:
            logger.warning(f"Partial result for {table_name} at {current}: {resp.partial_error}")
            tables = resp.partial_data
        # Convert to DataFrame
        for table in tables:
            df_chunk = pd.DataFrame(data=table.rows, columns=table.columns)
            all_chunks.append(df_chunk)
        current = next_time
    if not all_chunks:
        logger.info(f"No data for {table_name}")
        return
    df_table = pd.concat(all_chunks, ignore_index=True)
    logger.info(f"Exported {len(df_table)} rows for {table_name}")
    # Upload DataFrame as CSV
    csv_bytes = df_table.to_csv(index=False).encode('utf-8')
    blob_name = f"{table_name}_{start_time.date()}_{end_time.date()}.csv"
    blob_client = container_client.get_blob_client(blob=blob_name)
    # Retry on upload
    for attempt in range(3):
        try:
            blob_client.upload_blob(io.BytesIO(csv_bytes), overwrite=True)
            logger.info(f"Uploaded {blob_name} to container {container_name}")
            break
        except Exception as err:
            logger.warning(f"Upload attempt {attempt+1} failed: {err}")
            time.sleep(2 ** attempt)
    else:
        logger.error(f"Failed to upload {blob_name} after retries")

# List of tables and ranges to export
tables = [""]
# (Year, Month, Day)
# Starts at the beginning of this day
start_time = datetime(2025, 7, 14)
# Ends before the start of this day
end_time   = datetime(2025, 7, 22)
# How often to query data
time_chunk = timedelta(days=1)

# Parallel export
with ThreadPoolExecutor(max_workers=len(tables)) as executor:
    futures = [
        executor.submit(export_table, tbl, start_time, end_time, time_chunk)
        for tbl in tables
    ]
    for f in as_completed(futures):
        if f.exception():
            logger.error(f"Error in export: {f.exception()}")

logger.info("All exports completed.")
