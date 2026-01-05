#!/usr/bin/env python3
"""
Real-time Station Data Service - Fetches current/recent real-time readings.

This service handles fetching real-time (hourly) data from Environment Canada
for current river conditions, as opposed to daily means which have significant lag.
"""

import aiohttp
import asyncio
import ssl
import sys
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional
from pathlib import Path
import time

# Add parent directory to path to import models
sys.path.insert(0, str(Path(__file__).parent.parent))
from models import StationLevel


class RealtimeDataService:
    """Service for fetching real-time hourly data from Environment Canada."""
    
    BASE_URL = "https://api.weather.gc.ca/collections/hydrometric-realtime/items"
    DEFAULT_TIMEOUT = 30
    MAX_RETRIES = 3
    RETRY_DELAY = 2  # seconds
    
    def __init__(self, timeout: int = DEFAULT_TIMEOUT):
        """
        Initialize the service.
        
        Args:
            timeout: Request timeout in seconds
        """
        self.timeout = aiohttp.ClientTimeout(total=timeout)
        self.session = None
        # Disable SSL verification (api.weather.gc.ca has certificate issues)
        self.ssl_context = ssl.create_default_context()
        self.ssl_context.check_hostname = False
        self.ssl_context.verify_mode = ssl.CERT_NONE
    
    async def __aenter__(self):
        """Async context manager entry."""
        connector = aiohttp.TCPConnector(ssl=self.ssl_context)
        self.session = aiohttp.ClientSession(timeout=self.timeout, connector=connector)
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.session:
            await self.session.close()
    
    async def fetch_latest_readings(
        self,
        station_id: str,
        hours: int = 48
    ) -> List[Dict[str, Any]]:
        """
        Fetch the latest real-time readings for a station.
        
        Args:
            station_id: Environment Canada station identifier
            hours: Number of hours to fetch (default: 48)
            
        Returns:
            List of reading dicts with timestamp, level, discharge, etc.
        """
        end_date = datetime.now(timezone.utc)
        start_date = end_date - timedelta(hours=hours)
        
        return await self._fetch_date_range(
            station_id,
            start_date.strftime('%Y-%m-%dT%H:%M:%SZ'),
            end_date.strftime('%Y-%m-%dT%H:%M:%SZ')
        )
    
    async def fetch_current_reading(
        self,
        station_id: str
    ) -> Optional[Dict[str, Any]]:
        """
        Fetch the most recent reading for a station.
        
        Args:
            station_id: Environment Canada station identifier
            
        Returns:
            Dict with latest reading or None if not available
        """
        readings = await self.fetch_latest_readings(station_id, hours=24)
        
        if readings:
            # Return the most recent reading
            return readings[0]
        
        return None
    
    async def _fetch_date_range(
        self,
        station_id: str,
        start_datetime: str,
        end_datetime: str
    ) -> List[Dict[str, Any]]:
        """
        Fetch real-time data for a specific datetime range.
        
        Args:
            station_id: Environment Canada station identifier
            start_datetime: Start datetime in ISO format
            end_datetime: End datetime in ISO format
            
        Returns:
            List of reading dicts
        """
        if not self.session:
            raise RuntimeError("Service must be used as async context manager")
        
        params = {
            'STATION_NUMBER': station_id,
            'f': 'json',
            'sortby': '-DATETIME',  # Most recent first
            'limit': 10000,
            'datetime': f"{start_datetime}/{end_datetime}"
        }
        
        # Retry logic
        for attempt in range(self.MAX_RETRIES):
            try:
                async with self.session.get(self.BASE_URL, params=params) as response:
                    response.raise_for_status()
                    data = await response.json()
                    return self._parse_response(data)
                
            except (aiohttp.ClientError, asyncio.TimeoutError) as e:
                if attempt < self.MAX_RETRIES - 1:
                    await asyncio.sleep(self.RETRY_DELAY * (attempt + 1))
                else:
                    raise
        
        return []
    
    def _parse_response(self, json_data: dict) -> List[Dict[str, Any]]:
        """
        Parse API response into list of readings.
        
        Args:
            json_data: JSON response from API
            
        Returns:
            List of reading dicts sorted by datetime (most recent first)
        """
        features = json_data.get('features', [])
        
        readings = []
        
        for feature in features:
            try:
                props = feature.get('properties', {})
                
                reading = {
                    'datetime': props.get('DATETIME'),
                    'discharge': props.get('DISCHARGE'),
                    'level': props.get('LEVEL'),
                    'station_name': props.get('STATION_NAME'),
                    'station_number': props.get('STATION_NUMBER'),
                }
                
                # Only add if we have at least one measurement
                if reading['discharge'] is not None or reading['level'] is not None:
                    readings.append(reading)
                    
            except (KeyError, TypeError, ValueError):
                # Skip invalid readings
                continue
        
        return readings
    
    async def get_station_status(
        self,
        station_id: str
    ) -> Dict[str, Any]:
        """
        Get current status summary for a station.
        
        Args:
            station_id: Environment Canada station identifier
            
        Returns:
            Dict with current status including latest reading and trend
        """
        readings = await self.fetch_latest_readings(station_id, hours=48)
        
        if not readings:
            return {
                'station_id': station_id,
                'status': 'no_data',
                'latest_reading': None,
                'data_age_hours': None,
                'trend': None
            }
        
        latest = readings[0]
        latest_time = datetime.fromisoformat(latest['datetime'].replace('Z', '+00:00'))
        data_age = datetime.now(timezone.utc) - latest_time
        
        # Calculate trend if we have multiple readings
        trend = 'stable'
        if len(readings) >= 2:
            # Compare latest level with reading from 6 hours ago
            recent_levels = [r['level'] for r in readings[:7] if r.get('level')]
            
            if len(recent_levels) >= 2:
                if recent_levels[0] > recent_levels[-1] + 0.05:
                    trend = 'rising'
                elif recent_levels[0] < recent_levels[-1] - 0.05:
                    trend = 'falling'
        
        return {
            'station_id': station_id,
            'status': 'active',
            'latest_reading': latest,
            'data_age_hours': data_age.total_seconds() / 3600,
            'trend': trend,
            'readings_48h': len(readings)
        }
