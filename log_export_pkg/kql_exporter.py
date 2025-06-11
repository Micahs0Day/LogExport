# export_pipeline/kql_exporter.py

"""
Module: kql_exporter
Purpose: Query Log Analytics using MSTICPy and process results into DataFrames.
"""

import logging
from datetime import datetime, timedelta
from typing import Optional
import pandas as pd
from msticpy.data import QueryProvider
from export_pipeline.config import settings
from export_pipeline.logger import logger


class LogAnalyticsExporter:
    """
    Handles querying Azure Log Analytics workspace with MSTICPy and batching time windows.
    """

    def __init__(self):
        self.provider = QueryProvider("AzureLogAnalytics")
        self.provider.connect(
            tenant_id=settings.tenant_id,
            client_id=settings.client_id,
            client_secret=settings.client_secret,
            workspace_id=settings.workspace_id,
        )
        logger.info("Connected to Azure Log Analytics workspace.")

    def query(
        self,
        kql_query: str,
        start_time: datetime,
        end_time: datetime,
        timeout_seconds: int = 300,
    ) -> Optional[pd.DataFrame]:
        """
        Execute a KQL query over a time window and return the results as a DataFrame.

        Args:
            kql_query (str): KQL query with placeholders for start and end timestamps.
            start_time (datetime): Start time for the query.
            end_time (datetime): End time for the query.
            timeout_seconds (int): Timeout for the query.

        Returns:
            Optional[pd.DataFrame]: Resulting DataFrame or None if failed.
        """
        formatted_query = kql_query.format(
            start=start_time.isoformat(), end=end_time.isoformat()
        )

        try:
            df = self.provider.query(formatted_query, timeout=timeout_seconds)
            if df is not None and not df.empty:
                logger.info(
                    f"Queried data from {start_time} to {end_time}, rows returned: {len(df)}"
                )
                return df
            else:
                logger.info(f"No data returned for time range {start_time} to {end_time}")
                return None
        except Exception as ex:
            logger.error(f"Error querying data: {ex}")
            return None

    def generate_time_windows(
        self,
        start_time: datetime,
        end_time: datetime,
        window_minutes: int,
    ):
        """
        Generates a list of (start, end) time tuples for batching queries.

        Args:
            start_time (datetime): The earliest start time.
            end_time (datetime): The latest end time.
            window_minutes (int): Length of each batch window in minutes.

        Yields:
            Tuple[datetime, datetime]: Start and end of each batch window.
        """
        current_start = start_time
        delta = timedelta(minutes=window_minutes)

        while current_start < end_time:
            current_end = min(current_start + delta, end_time)
            yield current_start, current_end
            current_start = current_end
