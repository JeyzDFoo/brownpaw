#!/usr/bin/env python3
"""
Station Data Manager - Handles Firestore operations for station_data collection.

This module manages the station_data collection structure:
- station_data/{provider}_{station_id}/metadata/info
- station_data/{provider}_{station_id}/readings/{year}
"""

import os
import sys
from datetime import datetime, timezone
from typing import Dict, List, Set, Optional, Any
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud.firestore_v1 import WriteBatch

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))
from models import Provider


class StationDataManager:
    """Manages station data in Firestore."""
    
    def __init__(self):
        """Initialize Firestore client."""
        self._init_firebase()
        self.db = firestore.client()
        
    def _init_firebase(self):
        """Initialize Firebase Admin SDK if not already initialized."""
        try:
            firebase_admin.get_app()
        except ValueError:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(script_dir)
            cred_path = os.path.join(project_root, 'firebase-service-account.json')
            
            if not os.path.exists(cred_path):
                raise FileNotFoundError(
                    f"Firebase credentials not found at {cred_path}"
                )
            
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
    
    def get_all_river_run_stations(self) -> Dict[str, Set[str]]:
        """
        Query all river_runs and extract unique station IDs.
        
        Returns:
            Dict mapping provider to set of station IDs
            e.g., {"environment_canada": {"08GA072", "08NM116"}}
        """
        stations_by_provider: Dict[str, Set[str]] = {
            Provider.ENVIRONMENT_CANADA: set(),
        }
        
        runs_ref = self.db.collection('river_runs')
        docs = runs_ref.stream()
        
        for doc in docs:
            data = doc.to_dict()
            
            # Check stationId field
            station_id = data.get('stationId')
            if station_id:
                # Skip if already has provider prefix (malformed data)
                if not station_id.startswith('environment_canada_'):
                    # Assume Environment Canada for now
                    # Can enhance with provider detection logic later
                    stations_by_provider[Provider.ENVIRONMENT_CANADA].add(station_id)
            
            # Check gaugeStation.code field
            gauge_station = data.get('gaugeStation')
            if gauge_station and isinstance(gauge_station, dict):
                code = gauge_station.get('code')
                if code and not code.startswith('environment_canada_'):
                    stations_by_provider[Provider.ENVIRONMENT_CANADA].add(code)
        
        # Remove empty sets
        return {
            provider: stations 
            for provider, stations in stations_by_provider.items() 
            if stations
        }
    
    def get_existing_stations(self, provider: str) -> Set[str]:
        """
        Get set of station IDs that already exist in station_data.
        
        Args:
            provider: Provider name (e.g., "environment_canada")
            
        Returns:
            Set of station IDs that have data
        """
        existing = set()
        prefix = f"{provider}_"
        
        # List all documents in station_data collection
        # We need to check which ones have data (metadata or readings subcollections)
        station_data_ref = self.db.collection('station_data')
        
        # Get all documents with provider prefix
        docs = station_data_ref.list_documents()
        
        for doc_ref in docs:
            doc_id = doc_ref.id
            if doc_id.startswith(prefix):
                # Check if metadata exists
                metadata_ref = doc_ref.collection('metadata').document('info')
                if metadata_ref.get().exists:
                    station_id = doc_id[len(prefix):]
                    existing.add(station_id)
        
        return existing
    
    def get_station_metadata(self, provider: str, station_id: str) -> Optional[Dict[str, Any]]:
        """
        Get metadata for a specific station.
        
        Args:
            provider: Provider name
            station_id: Station identifier
            
        Returns:
            Metadata dict or None if doesn't exist
        """
        doc_id = f"{provider}_{station_id}"
        metadata_ref = (
            self.db.collection('station_data')
            .document(doc_id)
            .collection('metadata')
            .document('info')
        )
        
        doc = metadata_ref.get()
        if doc.exists:
            return doc.to_dict()
        return None
    
    def create_station_metadata(
        self,
        provider: str,
        station_id: str,
        station_name: str,
        river_runs: List[str],
        batch: Optional[WriteBatch] = None
    ) -> None:
        """
        Create initial metadata for a new station.
        
        Args:
            provider: Provider name
            station_id: Station identifier
            station_name: Human-readable station name
            river_runs: List of river_run IDs associated with this station
            batch: Optional WriteBatch for batched operations
        """
        doc_id = f"{provider}_{station_id}"
        metadata_ref = (
            self.db.collection('station_data')
            .document(doc_id)
            .collection('metadata')
            .document('info')
        )
        
        metadata = {
            'station_id': station_id,
            'provider': provider,
            'station_name': station_name,
            'first_data_fetch': firestore.SERVER_TIMESTAMP,
            'last_updated': firestore.SERVER_TIMESTAMP,
            'is_active': True,
            'river_runs': river_runs,
            'created_at': firestore.SERVER_TIMESTAMP,
        }
        
        if batch:
            batch.set(metadata_ref, metadata)
        else:
            metadata_ref.set(metadata)
    
    def update_station_last_updated(
        self,
        provider: str,
        station_id: str,
        batch: Optional[WriteBatch] = None
    ) -> None:
        """
        Update the last_updated timestamp for a station.
        
        Args:
            provider: Provider name
            station_id: Station identifier
            batch: Optional WriteBatch for batched operations
        """
        doc_id = f"{provider}_{station_id}"
        metadata_ref = (
            self.db.collection('station_data')
            .document(doc_id)
            .collection('metadata')
            .document('info')
        )
        
        update_data = {
            'last_updated': firestore.SERVER_TIMESTAMP,
        }
        
        if batch:
            batch.update(metadata_ref, update_data)
        else:
            metadata_ref.update(update_data)
    
    def write_yearly_readings(
        self,
        provider: str,
        station_id: str,
        year: int,
        daily_readings: Dict[str, Dict[str, Any]],
        batch: Optional[WriteBatch] = None
    ) -> None:
        """
        Write or merge daily readings for a specific year.
        
        Args:
            provider: Provider name
            station_id: Station identifier
            year: Year for the readings
            daily_readings: Dict mapping date strings to reading data
                e.g., {"2024-01-01": {"mean_discharge": 45.6, ...}}
            batch: Optional WriteBatch for batched operations
        """
        doc_id = f"{provider}_{station_id}"
        readings_ref = (
            self.db.collection('station_data')
            .document(doc_id)
            .collection('readings')
            .document(str(year))
        )
        
        data = {
            'year': year,
            'daily_readings': daily_readings,
            'updated_at': firestore.SERVER_TIMESTAMP,
        }
        
        if batch:
            # Use set with merge to avoid overwriting existing data
            batch.set(readings_ref, data, merge=True)
        else:
            readings_ref.set(data, merge=True)
    
    def get_yearly_readings(
        self,
        provider: str,
        station_id: str,
        year: int
    ) -> Optional[Dict[str, Any]]:
        """
        Get all daily readings for a specific year.
        
        Args:
            provider: Provider name
            station_id: Station identifier
            year: Year to retrieve
            
        Returns:
            Dict with daily_readings or None if doesn't exist
        """
        doc_id = f"{provider}_{station_id}"
        readings_ref = (
            self.db.collection('station_data')
            .document(doc_id)
            .collection('readings')
            .document(str(year))
        )
        
        doc = readings_ref.get()
        if doc.exists:
            return doc.to_dict()
        return None
    
    def batch_write_station_data(
        self,
        operations: List[Dict[str, Any]]
    ) -> None:
        """
        Execute multiple station data operations in batches.
        
        Args:
            operations: List of operation dicts with keys:
                - type: "create_metadata", "update_metadata", "write_readings"
                - provider, station_id, and other relevant data
        """
        batch = self.db.batch()
        batch_count = 0
        max_batch_size = 500  # Firestore limit
        
        for op in operations:
            op_type = op.get('type')
            
            if op_type == 'create_metadata':
                self.create_station_metadata(
                    op['provider'],
                    op['station_id'],
                    op['station_name'],
                    op['river_runs'],
                    batch=batch
                )
            elif op_type == 'update_metadata':
                self.update_station_last_updated(
                    op['provider'],
                    op['station_id'],
                    batch=batch
                )
            elif op_type == 'write_readings':
                self.write_yearly_readings(
                    op['provider'],
                    op['station_id'],
                    op['year'],
                    op['daily_readings'],
                    batch=batch
                )
            
            batch_count += 1
            
            # Commit batch if we hit the limit
            if batch_count >= max_batch_size:
                batch.commit()
                batch = self.db.batch()
                batch_count = 0
        
        # Commit remaining operations
        if batch_count > 0:
            batch.commit()
    
    def get_stations_needing_update(
        self,
        provider: str,
        all_station_ids: Set[str]
    ) -> tuple[Set[str], Set[str]]:
        """
        Determine which stations are new vs existing.
        
        Args:
            provider: Provider name
            all_station_ids: Set of all station IDs from river_runs
            
        Returns:
            Tuple of (new_stations, existing_stations)
        """
        existing = self.get_existing_stations(provider)
        new_stations = all_station_ids - existing
        existing_stations = all_station_ids & existing
        
        return new_stations, existing_stations
    
    def write_current_station_data(
        self,
        provider: str,
        station_id: str,
        latest_reading: Dict[str, Any],
        trend: str,
        hourly_readings: Dict[str, Dict[str, Any]],
        updated_at: datetime
    ) -> None:
        """
        Write current station data to station_current collection.
        
        This is used by the realtime updater to store the latest conditions
        and 30 days of hourly readings for quick access.
        
        Args:
            provider: Provider name
            station_id: Station identifier
            latest_reading: Most recent reading with datetime, discharge, level
            trend: Trend indicator ("rising", "falling", "stable")
            hourly_readings: Dict mapping datetime strings to reading data
            updated_at: Timestamp of this update
        """
        doc_id = f"{provider}_{station_id}"
        current_ref = self.db.collection('station_current').document(doc_id)
        
        data = {
            'station_id': station_id,
            'provider': provider,
            'latest_reading': latest_reading,
            'trend': trend,
            'hourly_readings': hourly_readings,
            'readings_count': len(hourly_readings),
            'updated_at': updated_at,
        }
        
        current_ref.set(data)
