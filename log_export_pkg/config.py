import os
from dotenv import load_dotenv

# Load .env file if present
load_dotenv()

class Settings:
    # Azure
    tenant_id = os.getenv("AZURE_TENANT_ID")
    client_id = os.getenv("AZURE_CLIENT_ID")
    client_secret = os.getenv("AZURE_CLIENT_SECRET")
    workspace_id = os.getenv("LOG_ANALYTICS_WORKSPACE_ID")
    storage_account_name = os.getenv("STORAGE_ACCOUNT_NAME")
    storage_container_base_url = os.getenv("STORAGE_CONTAINER_BASE_URL")
    storage_sas_token = os.getenv("STORAGE_SAS_TOKEN")

    # Export control
    batch_interval_minutes = int(os.getenv("BATCH_INTERVAL_MINUTES", 60))
    max_parallel_tables = int(os.getenv("MAX_PARALLEL_TABLES", 4))
    export_days_lookback = int(os.getenv("EXPORT_DAYS_LOOKBACK", 365))
    export_dir = os.getenv("EXPORT_OUTPUT_DIR", "export_output")
    metadata_log_path = os.getenv("METADATA_LOG_PATH", "metadata_logs/export_metadata.csv")

    # Retry policy
    max_retries = int(os.getenv("MAX_RETRIES", 5))
    retry_delay_seconds = int(os.getenv("RETRY_DELAY_SECONDS", 10))

settings = Settings()
