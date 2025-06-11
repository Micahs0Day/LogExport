# Log Export Pipeline

## Project Overview

This project implements a resilient, scalable pipeline to export Azure Log Analytics data to Azure Blob Storage in batches, using Python and MSTICPy. It is optimized for large tables, parallel execution, and provides robust retry and logging mechanisms. The solution includes infrastructure-as-code via Terraform, a Python package for export logic, and an interactive Jupyter notebook for orchestration.

---

## Class Overview, Functionality, Key Features & Purpose

### `LogAnalyticsExporter` (in `kql_exporter.py`)

- **Purpose:**  
  Connects to Azure Log Analytics and runs Kusto Query Language (KQL) queries in configurable time windows to retrieve log data.

- **Key Functionality:**  
  - Establishes authenticated connection using MSTICPy QueryProvider.  
  - Executes parameterized KQL queries over defined time ranges.  
  - Supports incremental batching by generating consecutive time windows.  
  - Returns query results as pandas DataFrames for further processing.

- **Key Features:**  
  - Automatic batching with customizable window size (e.g., 1 hour).  
  - Handles empty or no-result queries gracefully.  
  - Logs query execution status and row counts.

---

### `BlobUploader` (functions in `blob_uploader.py`)

- **Purpose:**  
  Uploads exported data files (e.g., JSON) to Azure Blob Storage containers securely and reliably.

- **Key Functionality:**  
  - Connects to Azure Blob Storage with SAS token or credentials.  
  - Uploads files with retry logic on transient failures.  
  - Logs success and failure with detailed messages.

- **Key Features:**  
  - Configurable max retries and backoff delay.  
  - Supports container-specific uploads, enabling per-table segregation.  
  - Exception handling and logging ensure export resilience.

---

### `Settings` (in `config.py`)

- **Purpose:**  
  Centralizes all environment configurations and constants used across the pipeline.

- **Key Functionality:**  
  - Loads sensitive Azure credentials and workspace info from environment or `.env` file.  
  - Defines batch sizes, parallelism limits, retry parameters, and export paths.  

- **Key Features:**  
  - Easy parameter tuning without code changes.  
  - Facilitates secure management of secrets via environment variables.

---

### `Logger` (in `logger.py`)

- **Purpose:**  
  Provides standardized logging setup for the entire pipeline.

- **Key Functionality:**  
  - Configures console and file logging handlers.  
  - Uses timestamped, leveled log messages for clarity.  
  - Ensures logs directory existence and rotates logs.

- **Key Features:**  
  - Centralized logging simplifies debugging and monitoring.  
  - Log files capture detailed export workflow traces.

---

### Utility Functions (in `utils.py`)

- **Purpose:**  
  Provides helper functions to support the main export workflow.

- **Key Functionality:**  
  - Loads the list of tables to export from config or files.  
  - Writes and updates metadata CSV logs tracking export details (row counts, timestamps, file paths).  
  - Miscellaneous helpers such as safe file writes and directory checks.

- **Key Features:**  
  - Metadata logging enables auditability and monitoring.  
  - Decouples common reusable logic from main workflow.

---

### Main Orchestration (`process_table` in `main.py`)

- **Purpose:**  
  Coordinates the entire export process for each table, combining querying, batching, file generation, uploading, and metadata logging.

- **Key Functionality:**  
  - For each configured table:  
    - Generates time window batches based on lookback period and batch interval.  
    - Queries Log Analytics data using `LogAnalyticsExporter`.  
    - Serializes DataFrame results to JSON files.  
    - Uploads JSON files to Azure Blob Storage via `BlobUploader`.  
    - Records detailed metadata for each batch export.  
  - Supports parallel execution for multiple tables with thread pooling.

- **Key Features:**  
  - Robust error handling and retries at each step.  
  - Efficient batching optimizes query and upload sizes.  
  - Modular design allows easy extension or integration.

---

## Usage Summary

- Deploy required Azure resources using Terraform (VM, virtual network, storage account).  
- Configure environment variables securely (credentials, workspace IDs, SAS tokens).  
- Install dependencies from `requirements.txt`.  
- Use the provided Jupyter notebook `run_export_pipeline.ipynb` or run `main.py` script for export orchestration.  
- Monitor detailed logs and metadata CSV for export status and audit.

---

## Final Notes

This pipeline is designed for production-ready, cost-conscious exports of large-scale Azure Log Analytics data to Blob Storage, with a focus on reliability, maintainability, and security.

---

*Last updated: 2025-06-11*
