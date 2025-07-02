# 🔄 Log Export Pipeline

## Overview

The **Log Export Pipeline** is a Python-based solution that automates the export of historical data from Azure Log Analytics to Azure Blob Storage. It is designed for high-volume, batched, and resilient data exports using MSTICPy. The system supports parallel table processing, export logging, retries, and configuration via environment variables.

---

## 🧱 Project Structure

```bash
log-export-pipeline/
├── run_export_pipeline.ipynb   # Jupyter notebook to orchestrate export
├── export_pipeline/            # Python package for the export logic
│   ├── __init__.py
│   ├── main.py                 # Coordinates the export process per table
│   ├── kql_exporter.py         # Runs KQL queries via MSTICPy
│   ├── blob_uploader.py        # Handles robust upload to Azure Blob
│   ├── utils.py                # Helpers: metadata logging, batching, etc.
│   ├── config.py               # Loads all configuration and secrets
│   └── logger.py               # Centralized logging
├── terraform/                  # Terraform config to deploy Azure infra
├── .env.example                # Template for required env vars
├── requirements.txt            # Project dependencies
├── LEARNING_PLAN.md            # Guide to learn how to build this
├── RFC.md                      # Architecture and design rationale
└── README.md                   # This file
```

---

## 🔗 References

# Docs
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
https://learn.microsoft.com/en-us/azure/machine-learning/how-to-secure-workspace-vnet?view=azureml-api-2&tabs=required%2Cpe%2Ccli
https://learn.microsoft.com/en-us/azure/machine-learning/how-to-network-security-overview?view=azureml-api-2

# Terraform
https://learn.microsoft.com/en-us/azure/machine-learning/how-to-manage-workspace-terraform?view=azureml-api-2&tabs=privateworkspace
https://learn.microsoft.com/en-us/azure/firewall-manager/quick-firewall-policy-terraform
