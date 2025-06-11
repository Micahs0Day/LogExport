# export_pipeline/blob_uploader.py

"""
Module: blob_uploader
Purpose: Uploads data files to Azure Blob Storage with retry logic.
"""

import time
import requests
from pathlib import Path
from export_pipeline.config import settings
from export_pipeline.logger import logger


def upload_blob(file_path: Path, container_name: str) -> bool:
    """
    Uploads a local file to Azure Blob Storage using a pre-generated SAS token.
    
    Args:
        file_path (Path): Path to the local file to upload.
        container_name (str): Target container name in Blob Storage.
        
    Returns:
        bool: True if upload is successful, False otherwise.
    """
    blob_name = file_path.name
    blob_url = f"{settings.storage_container_base_url}{container_name}/{blob_name}?{settings.storage_sas_token}"

    headers = {
        "x-ms-blob-type": "BlockBlob",
        "Content-Type": "application/json"
    }

    for attempt in range(1, settings.max_retries + 1):
        try:
            with open(file_path, "rb") as data:
                response = requests.put(blob_url, headers=headers, data=data)
                if response.status_code in [201, 202]:
                    logger.info(f"✅ Uploaded {file_path.name} to container {container_name}")
                    return True
                else:
                    logger.warning(f"⚠️ Attempt {attempt}: Failed to upload {file_path.name} — Status {response.status_code}, Response: {response.text}")
        except Exception as e:
            logger.error(f"❌ Attempt {attempt}: Exception during upload — {str(e)}")

        time.sleep(settings.retry_delay_seconds)

    logger.error(f"❌ Failed to upload {file_path.name} after {settings.max_retries} attempts.")
    return False
