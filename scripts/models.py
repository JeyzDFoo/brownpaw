"""
Data models for brownpaw Firestore collections.

These models define the structure for station data from various providers
(Environment Canada, USGS, etc.) and their real-time water level readings.
"""

from datetime import datetime
from typing import Optional, Dict, Any, Literal
from enum import Enum


class Provider(str, Enum):
    """Supported water level data providers."""
    ENVIRONMENT_CANADA = "environment_canada"
    USGS = "usgs"
    OTHER = "other"


class Trend(str, Enum):
    """Water level trend indicators."""
    RISING = "rising"
    FALLING = "falling"
    STABLE = "stable"


class Station:
    """
    Station metadata for hydrometric monitoring stations.
    
    Collection: stations
    Document ID: {provider}_{station_id} (e.g., "ec_08GA072")
    """
    
    def __init__(
        self,
        provider: Provider,
        station_id: str,
        station_name: str,
        country: str,
        latitude: float,
        longitude: float,
        active: bool = True,
        province_or_state: Optional[str] = None,
        river_id: Optional[str] = None,
        provider_metadata: Optional[Dict[str, Any]] = None,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None
    ):
        self.provider = provider
        self.station_id = station_id
        self.station_name = station_name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.active = active
        self.province_or_state = province_or_state
        self.river_id = river_id
        self.provider_metadata = provider_metadata or {}
        self.created_at = created_at
        self.updated_at = updated_at
    
    @property
    def document_id(self) -> str:
        """Generate the Firestore document ID."""
        provider_str = self.provider.value if hasattr(self.provider, 'value') else str(self.provider)
        return f"{provider_str}_{self.station_id}"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for Firestore."""
        return {
            'provider': self.provider,
            'station_id': self.station_id,
            'station_name': self.station_name,
            'country': self.country,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'active': self.active,
            'province_or_state': self.province_or_state,
            'river_id': self.river_id,
            'provider_metadata': self.provider_metadata,
            'created_at': self.created_at,
            'updated_at': self.updated_at
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Station':
        """Create Station from Firestore document."""
        return cls(
            provider=data['provider'],
            station_id=data['station_id'],
            station_name=data['station_name'],
            country=data['country'],
            latitude=data['latitude'],
            longitude=data['longitude'],
            active=data.get('active', True),
            province_or_state=data.get('province_or_state'),
            river_id=data.get('river_id'),
            provider_metadata=data.get('provider_metadata', {}),
            created_at=data.get('created_at'),
            updated_at=data.get('updated_at')
        )


class StationLevel:
    """
    Current water level data for a monitoring station.
    
    Collection: station_levels
    Document ID: {provider}_{station_id} (e.g., "ec_08GA072")
    """
    
    def __init__(
        self,
        provider: Provider,
        station_id: str,
        level: Optional[float],
        discharge: Optional[float],
        timestamp: datetime,
        trend: Trend = Trend.STABLE,
        level_unit: str = 'm',
        discharge_unit: str = 'm³/s',
        last_updated: Optional[datetime] = None,
        raw_data: Optional[Dict[str, Any]] = None
    ):
        self.provider = provider
        self.station_id = station_id
        self.level = level  # Always in meters
        self.discharge = discharge  # Always in m³/s
        self.timestamp = timestamp
        self.trend = trend
        self.level_unit = level_unit
        self.discharge_unit = discharge_unit
        self.last_updated = last_updated or datetime.now()
        self.raw_data = raw_data or {}
    
    @property
    def document_id(self) -> str:
        """Generate the Firestore document ID."""
        provider_str = self.provider.value if hasattr(self.provider, 'value') else str(self.provider)
        return f"{provider_str}_{self.station_id}"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for Firestore."""
        return {
            'provider': self.provider,
            'station_id': self.station_id,
            'level': self.level,
            'discharge': self.discharge,
            'timestamp': self.timestamp,
            'trend': self.trend,
            'level_unit': self.level_unit,
            'discharge_unit': self.discharge_unit,
            'last_updated': self.last_updated,
            'raw_data': self.raw_data
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'StationLevel':
        """Create StationLevel from Firestore document."""
        return cls(
            provider=data['provider'],
            station_id=data['station_id'],
            level=data.get('level'),
            discharge=data.get('discharge'),
            timestamp=data['timestamp'],
            trend=data.get('trend', Trend.STABLE),
            level_unit=data.get('level_unit', 'm'),
            discharge_unit=data.get('discharge_unit', 'm³/s'),
            last_updated=data.get('last_updated'),
            raw_data=data.get('raw_data', {})
        )
    
    @classmethod
    def from_environment_canada(cls, feature: Dict[str, Any]) -> 'StationLevel':
        """
        Create StationLevel from Environment Canada API response.
        
        Args:
            feature: A single feature from the GeoJSON FeatureCollection
        """
        props = feature.get('properties', {})
        
        # Parse timestamp
        timestamp_str = props.get('DATETIME')
        timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00')) if timestamp_str else datetime.utcnow()
        
        return cls(
            provider=Provider.ENVIRONMENT_CANADA,
            station_id=props.get('STATION_NUMBER'),
            level=props.get('LEVEL'),
            discharge=props.get('DISCHARGE'),
            timestamp=timestamp,
            trend=Trend.STABLE,  # Will be calculated separately
            raw_data={
                'station_name': props.get('STATION_NAME'),
                'province': props.get('PROV_TERR_STATE_LOC'),
                'datetime_local': props.get('DATETIME_LST'),
                'level_symbol': props.get('LEVEL_SYMBOL_EN'),
                'discharge_symbol': props.get('DISCHARGE_SYMBOL_EN'),
                'coordinates': feature.get('geometry', {}).get('coordinates')
            }
        )


class DailyMean:
    """
    Daily mean water level data for historical analysis.
    
    This is used for historical data (daily averages) from HYDAT database,
    as opposed to real-time readings in StationLevel.
    
    Collection: daily_means (subcollection under stations)
    Document ID: {YYYY-MM-DD} (e.g., "2024-12-31")
    """
    
    def __init__(
        self,
        provider: Provider,
        station_id: str,
        date: str,  # YYYY-MM-DD format
        level: Optional[float],
        discharge: Optional[float],
        level_unit: str = 'm',
        discharge_unit: str = 'm³/s',
        raw_data: Optional[Dict[str, Any]] = None
    ):
        self.provider = provider
        self.station_id = station_id
        self.date = date
        self.level = level  # Daily mean in meters
        self.discharge = discharge  # Daily mean in m³/s
        self.level_unit = level_unit
        self.discharge_unit = discharge_unit
        self.raw_data = raw_data or {}
    
    @property
    def document_id(self) -> str:
        """Generate the Firestore document ID (just the date)."""
        return self.date
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for Firestore."""
        return {
            'provider': self.provider,
            'station_id': self.station_id,
            'date': self.date,
            'level': self.level,
            'discharge': self.discharge,
            'level_unit': self.level_unit,
            'discharge_unit': self.discharge_unit,
            'raw_data': self.raw_data
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'DailyMean':
        """Create DailyMean from Firestore document."""
        return cls(
            provider=data['provider'],
            station_id=data['station_id'],
            date=data['date'],
            level=data.get('level'),
            discharge=data.get('discharge'),
            level_unit=data.get('level_unit', 'm'),
            discharge_unit=data.get('discharge_unit', 'm³/s'),
            raw_data=data.get('raw_data', {})
        )
    
    @classmethod
    def from_environment_canada_daily(cls, feature: Dict[str, Any]) -> 'DailyMean':
        """
        Create DailyMean from Environment Canada daily mean API response.
        
        Args:
            feature: A single feature from the GeoJSON FeatureCollection
        """
        props = feature.get('properties', {})
        
        return cls(
            provider=Provider.ENVIRONMENT_CANADA,
            station_id=props.get('STATION_NUMBER'),
            date=props.get('DATE'),
            level=props.get('LEVEL'),
            discharge=props.get('DISCHARGE'),
            raw_data={
                'station_name': props.get('STATION_NAME'),
                'province': props.get('PROV_TERR_STATE_LOC'),
                'level_symbol': props.get('LEVEL_SYMBOL_EN'),
                'discharge_symbol': props.get('DISCHARGE_SYMBOL_EN'),
                'identifier': props.get('IDENTIFIER'),
                'coordinates': feature.get('geometry', {}).get('coordinates')
            }
        )


def calculate_trend(previous_level: Optional[float], current_level: Optional[float], threshold: float = 0.05) -> Trend:
    """
    Calculate water level trend based on previous and current readings.
    
    Args:
        previous_level: Previous water level in meters
        current_level: Current water level in meters
        threshold: Minimum change in meters to register as rising/falling (default: 5cm)
    
    Returns:
        Trend enum value (RISING, FALLING, or STABLE)
    """
    if previous_level is None or current_level is None:
        return Trend.STABLE
    
    difference = current_level - previous_level
    
    if difference > threshold:
        return Trend.RISING
    elif difference < -threshold:
        return Trend.FALLING
    else:
        return Trend.STABLE


# Example usage
if __name__ == "__main__":
    # Example: Create a station
    station = Station(
        provider=Provider.ENVIRONMENT_CANADA,
        station_id="08GA072",
        station_name="CHEAKAMUS RIVER ABOVE MILLAR CREEK",
        country="CA",
        province_or_state="BC",
        latitude=50.07991,
        longitude=-123.03562,
        active=True
    )
    
    print("Station Document ID:", station.document_id)
    print("Station Data:", station.to_dict())
    
    # Example: Create a station level reading
    level = StationLevel(
        provider=Provider.ENVIRONMENT_CANADA,
        station_id="08GA072",
        level=1.854,
        discharge=6.8,
        timestamp=datetime.now(),
        trend=Trend.STABLE
    )
    
    print("\nLevel Document ID:", level.document_id)
    print("Level Data:", level.to_dict())
    
    # Example: Create a daily mean reading
    daily = DailyMean(
        provider=Provider.ENVIRONMENT_CANADA,
        station_id="08GA072",
        date="2024-12-31",
        level=1.937,
        discharge=8.39
    )
    
    print("\nDaily Mean Document ID:", daily.document_id)
    print("Daily Mean Data:", daily.to_dict())
    
    # Example: Calculate trend
    prev_level = 1.85
    curr_level = 1.92
    trend = calculate_trend(prev_level, curr_level)
    print(f"\nTrend from {prev_level}m to {curr_level}m: {trend}")
