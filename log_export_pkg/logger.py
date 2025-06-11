import logging
import os
from pathlib import Path

# Ensure logs directory exists
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

# Define log file path
log_file_path = log_dir / "pipeline.log"

# Create logger
logger = logging.getLogger("export_pipeline")
logger.setLevel(logging.INFO)

# Console handler
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
console_formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
console_handler.setFormatter(console_formatter)

# File handler
file_handler = logging.FileHandler(log_file_path)
file_handler.setLevel(logging.INFO)
file_formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(name)s - %(message)s")
file_handler.setFormatter(file_formatter)

# Add handlers if not already added
if not logger.hasHandlers():
    logger.addHandler(console_handler)
    logger.addHandler(file_handler)
