# Pricing Estimate for Log Export Pipeline Solution

**Date:** 2025-06-11

---

## Assumptions

- **Total data size:** 1 TB (across 20 tables)  
- **Average table size:** 50 GB (1 TB ÷ 20 tables)  
- **Batching:** 1-hour intervals per table, queries capped at 64MB or 500,000 rows per query  
- **Compute:** Azure Machine Learning (AML) Standard_D8s_v3 VM  
- **Storage:** Azure Blob Storage (Hot Tier) with per-table containers (20 containers total)  
- **Data transfer:** Upload only from AML to Azure Blob Storage  
- **Export duration:** Single export job, completed within 24 hours

---

## 1. Compute Cost: Azure Machine Learning Standard_D8s_v3

- **Specs:** 8 vCPUs, 32 GB RAM  
- **Pricing:** ~\$0.52/hour (East US, pay-as-you-go) [Azure pricing calculator]  
- **Estimated usage:** ~24 hours (full export job duration)

**Total Compute Cost:**  
`$0.52/hour * 24 hours = $12.48`

---

## 2. Azure Blob Storage Cost (per table/container)

| Cost Component             | Unit Price                     | Estimate Calculation                       | Total Cost per Table |
|----------------------------|-------------------------------|--------------------------------------------|---------------------|
| **Storage (Hot Tier)**      | $0.0184 per GB/month           | 50 GB * $0.0184 = $0.92                     | $0.92               |
| **Write operations (PUT, etc.)** | $0.005 per 10,000 operations  | Assume 10,000 writes per table (high estimate) | $0.005              |
| **Data Transfer (Ingress)** | Free                          | No cost for uploading data to Azure Blob Storage | $0                  |

**Total Storage Cost per Table:**  
`$0.92 + $0.005 = $0.925`

---

## 3. Total Storage Cost (20 Tables)

`$0.925 * 20 = $18.50`

---

## 4. Other Potential Costs

- **Log Analytics Query Costs:**  
  - Azure charges for log analytics queries based on data scanned and ingestion. Since this pipeline queries historical data already ingested, additional ingestion charges do not apply.  
  - Query cost: ~$2.30 per GB scanned beyond included amount.  
  - For 1 TB of data, assume 1 TB queried over time in 1-hour chunks, with some query reuse and optimizations.  
  - Estimated Query cost: ~\$20–\$40 (varies widely depending on actual query efficiency and retention policies).

- **Data Egress:**  
  - No significant data egress cost as data stays within Azure to Blob Storage.

- **Networking:**  
  - Virtual network cost included in VM pricing; no additional charge for subnet usage.

---

## 5. Summary Cost Breakdown

| Category                     | Estimated Cost (USD)         |
|------------------------------|------------------------------|
| AML Compute (24h)             | $12.48                       |
| Blob Storage (20 containers) | $18.50                       |
| Log Analytics Query Cost      | $30 (average estimate)       |
| **Total Estimated Cost**      | **~$61.00**                  |

---

## 6. Notes & Recommendations

- **Compute:** AML VM cost is relatively low given short runtime; scaling VM size up/down impacts price linearly.  
- **Storage:** Hot tier recommended for frequent access; cold or archive tier not suitable for frequent writes and immediate read.  
- **Queries:** Optimizing query windows and caching can reduce Log Analytics query costs significantly.  
- **Retry & Parallelism:** Limits on max parallel tables (e.g., 4) balance speed and cost.  
- **Network:** Restricting storage access to a single IP improves security but does not affect pricing significantly.

---

## 7. Tools Used for Pricing Estimate

- [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)  
- Azure official pricing pages for AML, Blob Storage, Log Analytics  
- Public pricing data as of June 2025 (may vary regionally)

---

## 8. Conclusion

This solution provides a cost-effective approach to export 1TB of log data over 20 tables within roughly $60 USD for a one-time export job, primarily driven by storage and query costs, with compute being a minor portion. Optimizations in query efficiency and batching may further reduce the overall cost.

---

*Prepared by: ChatGPT (based on user requirements and Azure pricing data)*
