#!/usr/bin/env python3
"""
Daily Data Service - Fetches daily mean data from Environment Canada.

This service handles fetching historical and recent daily mean data
for Environment Canada hydrometric stations.
"""

import requests
import sys
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional
from pathlib import Path
import time

# Add parent directory to path to import models
sys.path.insert(0, str(Path(__file__).parent.parent))
from models import DailyMean


class DailyDataService:
    """Service for fetching daily mean data from Environment Canada."""
    
    BASE_URL = "https://api.weather.gc.ca/collections/hydrometric-daily-mean/items"
    DEFAULT_TIMEOUT = 15
    MAX_RETRIES = 3
    RETRY_DELAY = 2  # seconds
    
    def __init__(self, timeout: int = DEFAULT_TIMEOUT):
        """
        Initialize the service.
        
        Args:
            timeout: Request timeout in seconds
        """
        self.timeout = timeout
    
    def fetch_historical_data(
        self,
        station_id: str,
        days: int = 1825  # 5 years default
    ) -> Dict[str, Dict[str, Any]]:
        """
        Fetch historical daily mean data for a new station.
        
        Args:
            station_id: Environment Canada station identifier
            days: Number of days to fetch (default: 1825 = 5 years)
            
        Returns:
            Dict mapping date strings to reading data
            e.g., {"2024-01-01": {"mean_discharge": 45.6, "mean_level": 1.23}}
        """
        end_date = datetime.now(timezone.utc)
        start_date = end_date - timedelta(days=days)
        
        return self._fetch_date_range(
            station_id,
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
    
    def fetch_recent_data(
        self,
        station_id: str,
        since_date: datetime
    ) -> Dict[str, Dict[str, Any]]:
        """
        Fetch recent daily mean data since a specific date.
        
        Args:
            station_id: Environment Canada station identifier
            since_date: Fetch data from this date forward
            
        Returns:
            Dict mapping date strings to reading data
        """
        end_date = datetime.now(timezone.utc)
        
        return self._fetch_date_range(
            station_id,
            since_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
    
    def fetch_latest_data(
        self,
        station_id: str,
        days: int = 2
    ) -> Dict[str, Dict[str, Any]]:
        """
        Fetch the latest daily mean data (last few days).
        
        Args:
            station_id: Environment Canada station identifier
            days: Number of recent days to fetch (default: 2)
            
        Returns:
            Dict mapping date strings to reading data
        """
        end_date = datetime.now(timezone.utc)
        start_date = end_date - timedelta(days=days)
        
        return self._fetch_date_range(
            station_id,
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d')
        )
    
    def _fetch_date_range(
        self,
        station_id: str,
        start_date: str,
        end_date: str
    ) -> Dict[str, Dict[str, Any]]:
        """
        Fetch daily mean data for a specific date range.
        
        Args:
            station_id: Environment Canada station identifier
            start_date: Start date in YYYY-MM-DD format
            end_date: End date in YYYY-MM-DD format
            
        Returns:
            Dict mapping date strings to reading data
        """
        params = {
            'STATION_NUMBER': station_id,
            'f': 'json',
            'sortby': 'DATE',
            'limit': 10000,
            'datetime': f"{start_date}T00:00:00Z/{end_date}T23:59:59Z"
        }
        
        # Retry logic
        for attempt in range(self.MAX_RETRIES):
            try:
                response = requests.get(
                    self.BASE_URL,
                    params=params,
                    timeout=self.timeout
                )
                response.raise_for_status()
                
                # Parse and transform data
                return self._parse_response(response.json())
                
            except requests.RequestException as e:
                if attempt < self.MAX_RETRIES - 1:
                    print(f"  Retry {attempt + 1}/{self.MAX_RETRIES} for {station_id} due to: {e}")
                    time.sleep(self.RETRY_DELAY * (attempt + 1))
                else:
                    print(f"  ✗ Failed to fetch data for {station_id}: {e}")
                    raise
        
        return {}
    
    def _parse_response(self, json_data: dict) -> Dict[str, Dict[str, Any]]:
        """
        Parse API response and organize by date.
        
        Args:
            json_data: JSON response from API
            
        Returns:
            Dict mapping date strings to reading data
        """
        features = json_data.get('features', [])
        
        readings_by_date = {}
        
        for feature in features:
            try:
                daily_mean = DailyMean.from_environment_canada_daily(feature)
                
                # Extract date string (YYYY-MM-DD) - already a string from API
                date_str = daily_mean.date
                
                # Build reading data
                reading_data = {}
                
                if daily_mean.discharge is not None:
                    reading_data['mean_discharge'] = daily_mean.discharge
                
                if daily_mean.level is not None:
                    reading_data['mean_level'] = daily_mean.level
                
                # Only add if we have data
                if reading_data:
                    readings_by_date[date_str] = reading_data
                    
            except (KeyError, TypeError, ValueError) as e:
                # Skip invalid readings
                continue
        
        return readings_by_date
    
    def organize_by_year(
        self,
        readings: Dict[str, Dict[str, Any]]
    ) -> Dict[int, Dict[str, Dict[str, Any]]]:
        """
        Organize readings by year for Firestore storage.
        
        Args:
            readings: Dict mapping date strings to reading data
            
        Returns:
            Dict mapping years to date-keyed readings
            e.g., {2024: {"2024-01-01": {...}, ...}, 2023: {...}}
        """
        by_year = {}
        
        for date_str, reading_data in readings.items():
            # Extract year from date string
            year = int(date_str[:4])
            
            if year not in by_year:
                by_year[year] = {}
            
            by_year[year][date_str] = reading_data
        
        return by_year
    
    def get_station_info(self, station_id: str) -> Optional[Dict[str, str]]:
        """
        Fetch basic station information from a sample query.
        
        Args:
            station_id: Environment Canada station identifier
            
        Returns:
            Dict with station name and ID, or None if not found
        """
        try:
            # Fetch just 1 recent reading to get station info
            params = {
                'STATION_NUMBER': station_id,
                'f': 'json',
                'limit': 1
            }
            
            response = requests.get(
                self.BASE_URL,
                params=params,
                timeout=self.timeout
            )
            response.raise_for_status()
            
            data = response.json()
            features = data.get('features', [])
            
            if features:
                props = features[0].get('properties', {})
                return {
                    'station_id': station_id,
                    'station_name': props.get('STATION_NAME', f'Station {station_id}')
                }
            
        except Exception:
            pass
        
        return None
