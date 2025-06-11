import csv
from pathlib import Path
from typing import List, Dict

TABLE_LIST_PATH = "tables.txt"
METADATA_LOG_PATH = Path("metadata_logs/export_metadata.csv")


def load_table_list() -> List[str]:
    """Load the list of tables to export from a file."""
    if not Path(TABLE_LIST_PATH).exists():
        raise FileNotFoundError(f"Missing required file: {TABLE_LIST_PATH}")

    with open(TABLE_LIST_PATH, "r") as f:
        return [line.strip() for line in f if line.strip()]


def log_metadata(table: str, metadata: Dict):
    """Append metadata info to the metadata CSV log."""
    METADATA_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    write_header = not METADATA_LOG_PATH.exists()

    with open(METADATA_LOG_PATH, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["table", "start_time", "end_time", "rows", "blobs"])
        if write_header:
            writer.writeheader()
        writer.writerow({
            "table": table,
            "start_time": metadata.get("start_time"),
            "end_time": metadata.get("end_time"),
            "rows": metadata.get("rows"),
            "blobs": ",".join(metadata.get("blobs", []))
        })
