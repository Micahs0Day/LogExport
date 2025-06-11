import sys
from pathlib import Path

# Add project root to path
sys.path.append(str(Path(".").resolve()))

from concurrent.futures import ThreadPoolExecutor, as_completed
from export_pipeline.config import settings
from export_pipeline.logger import logger
from export_pipeline.main import process_table
from export_pipeline.utils import load_table_list

logger.info("📘 Starting export from notebook...")

# Load list of tables
try:
    tables = load_table_list()
except FileNotFoundError as e:
    logger.error(str(e))
    raise

# Process tables in parallel
results = []
with ThreadPoolExecutor(max_workers=settings.max_parallel_tables) as executor:
    futures = {executor.submit(process_table, t): t for t in tables}
    for future in as_completed(futures):
        table = futures[future]
        try:
            future.result()
            results.append((table, "✅ Success"))
        except Exception as e:
            logger.error(f"❌ Error processing {table}: {str(e)}")
            results.append((table, f"❌ Error: {str(e)}"))

logger.info("✅ All exports complete.")
results
