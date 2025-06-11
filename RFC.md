## RFC: Log Analytics Export Architecture & Implementation

### Overview
This document outlines the design rationale, architectural decisions, and implementation strategy behind the Azure Log Analytics export pipeline project. The system is designed for efficient, secure, and scalable export of log data using MSTICPy, Azure Machine Learning, and Azure Storage.

---

### Goals
- Export data from multiple Log Analytics tables over a 365-day range
- Batching in 1-hour increments for manageable export sizes
- Secure blob storage and tightly scoped access
- Resilient, parallelized data export pipeline
- Auditable output with metadata CSV logs

---

### Architecture
**Cloud Resources:**
- **Azure ML Compute Instance (Standard_D8s_v3)**: Used for running the Python export workload in a cost-efficient, burstable fashion.
- **Azure Blob Storage**: Stores exported data, segregated per table.
- **Azure Virtual Network & Subnet**: Hosts the AML instance securely with NSG and subnet-level restrictions.

**Security Considerations:**
- Public blob access disabled
- TLS 1.2 enforced
- Access granted only to:
  - Internal subnet
  - One allow-listed external IP (for downstream system access)
- Retention policies set

---

### Implementation
**Key Features:**
- Uses MSTICPy to query KQL in 1-hour batches
- Automatically adjusts time ranges to stay within 500,000 row / 64MB limits
- Saves results to JSON and uploads to table-specific blob containers
- Retry logic handles transient failures (via `tenacity`)
- Parallel processing across tables using `ThreadPoolExecutor`
- CSV logging of metadata: table name, time range, row count, blob URL

**Code Modules:**
- `kql_exporter.py`: Time range management, KQL querying, row limiting
- `blob_uploader.py`: Blob upload + retry
- `logger.py`: Central logging with `loguru`
- `config.py`: Secrets + configuration from `.env`
- `main.py`: Orchestrator - loads config, spawns workers, manages logs

---

### Trade-offs
- **AML Compute vs. Azure Function**: Chose AML for better library support (MSTICPy) and larger compute requirements
- **Batching strategy**: 1-hour increments balances throughput with reliability
- **JSON export**: More readable and flexible than Parquet for downstream consumers

---

### Future Improvements
- Add Parquet option for performance
- Integrate Azure Key Vault for secret management
- Replace AML instance with containerized job on Azure Batch

---

### Conclusion
This system balances flexibility, performance, and security for the bulk export of log data to blob storage. It’s modular, scalable, and can be extended for additional analytics, transformations, or cross-cloud ingestion.
