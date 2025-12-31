"""
Data models for brownpaw Firestore collections.

These models define the structure for station data from various providers
(Environment Canada, USGS, etc.) and their real-time water level readings.
"""

from datetime import datetime
from typing import Optional, Dict, Any, Literal, List
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


class RiverRun:
    """
    River run metadata for whitewater sections.
    
    Collection: river_runs
    Document ID: {riverId} (e.g., "beaver-river-kinbasket-canyon")
    """
    
    def __init__(
        self,
        name: str,
        river: str,
        region: str,
        river_id: str,
        difficulty_class: str,
        description: Optional[str] = None,
        difficulty_min: Optional[float] = None,
        difficulty_max: Optional[float] = None,
        estimated_time: Optional[str] = None,
        season: Optional[str] = None,
        flow_unit: str = "cms",
        station_id: Optional[str] = None,
        permits: Optional[str] = None,
        access: Optional[str] = None,
        shuttle: Optional[str] = None,
        gradient: Optional[str] = None,
        length: Optional[str] = None,
        flow_ranges: Optional[Dict[str, Any]] = None,
        source: Optional[str] = None,
        source_url: Optional[str] = None,
        created_by: Optional[str] = None,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None,
        # Additional fields found in actual data
        coordinates: Optional[Dict[str, float]] = None,
        hazards: Optional[str] = None,
        put_in: Optional[str] = None,
        take_out: Optional[str] = None,
        min_recommended_flow: Optional[float] = None,
        max_recommended_flow: Optional[float] = None,
        optimal_flow_min: Optional[float] = None,
        optimal_flow_max: Optional[float] = None,
        has_valid_station: Optional[bool] = None
    ):
        self.name = name
        self.river = river
        self.region = region
        self.river_id = river_id
        self.difficulty_class = difficulty_class
        self.description = description
        self.difficulty_min = difficulty_min
        self.difficulty_max = difficulty_max
        self.estimated_time = estimated_time
        self.season = season
        self.flow_unit = flow_unit
        self.station_id = station_id
        self.permits = permits
        self.access = access
        self.shuttle = shuttle
        self.gradient = gradient
        self.length = length
        self.flow_ranges = flow_ranges
        self.source = source
        self.source_url = source_url
        self.created_by = created_by
        self.created_at = created_at
        self.updated_at = updated_at
        self.coordinates = coordinates
        self.hazards = hazards
        self.put_in = put_in
        self.take_out = take_out
        self.min_recommended_flow = min_recommended_flow
        self.max_recommended_flow = max_recommended_flow
        self.optimal_flow_min = optimal_flow_min
        self.optimal_flow_max = optimal_flow_max
        self.has_valid_station = has_valid_station
    
    @property
    def document_id(self) -> str:
        """Generate the Firestore document ID."""
        return self.river_id
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for Firestore."""
        data = {
            'name': self.name,
            'river': self.river,
            'region': self.region,
            'riverId': self.river_id,
            'difficultyClass': self.difficulty_class,
            'description': self.description,
            'difficultyMin': self.difficulty_min,
            'difficultyMax': self.difficulty_max,
            'estimatedTime': self.estimated_time,
            'season': self.season,
            'flowUnit': self.flow_unit,
            'stationId': self.station_id,
            'permits': self.permits,
            'access': self.access,
            'shuttle': self.shuttle,
            'gradient': self.gradient,
            'length': self.length,
            'flowRanges': self.flow_ranges,
            'source': self.source,
            'sourceUrl': self.source_url,
            'createdBy': self.created_by,
            'createdAt': self.created_at,
            'updatedAt': self.updated_at,
            'coordinates': self.coordinates,
            'hazards': self.hazards,
            'putIn': self.put_in,
            'takeOut': self.take_out,
            'minRecommendedFlow': self.min_recommended_flow,
            'maxRecommendedFlow': self.max_recommended_flow,
            'optimalFlowMin': self.optimal_flow_min,
            'optimalFlowMax': self.optimal_flow_max,
            'hasValidStation': self.has_valid_station
        }
        # Remove None values to keep documents clean
        return {k: v for k, v in data.items() if v is not None}
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'RiverRun':
        """Create RiverRun from Firestore document."""
        return cls(
            name=data['name'],
            river=data['river'],
            region=data['region'],
            river_id=data['riverId'],
            difficulty_class=data['difficultyClass'],
            description=data.get('description'),
            difficulty_min=data.get('difficultyMin'),
            difficulty_max=data.get('difficultyMax'),
            estimated_time=data.get('estimatedTime'),
            season=data.get('season'),
            flow_unit=data.get('flowUnit', 'cms'),
            station_id=data.get('stationId'),
            permits=data.get('permits'),
            access=data.get('access'),
            shuttle=data.get('shuttle'),
            gradient=data.get('gradient'),
            length=data.get('length'),
            flow_ranges=data.get('flowRanges'),
            source=data.get('source'),
            source_url=data.get('sourceUrl'),
            created_by=data.get('createdBy'),
            created_at=data.get('createdAt'),
            updated_at=data.get('updatedAt'),
            coordinates=data.get('coordinates'),
            hazards=data.get('hazards'),
            put_in=data.get('putIn'),
            take_out=data.get('takeOut'),
            min_recommended_flow=data.get('minRecommendedFlow'),
            max_recommended_flow=data.get('maxRecommendedFlow'),
            optimal_flow_min=data.get('optimalFlowMin'),
            optimal_flow_max=data.get('optimalFlowMax'),
            has_valid_station=data.get('hasValidStation')
        )


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
    
    # Example: Create a river run
    run = RiverRun(
        name="Beaver River (Kinbasket Canyon)",
        river="Beaver River",
        region="AB",
        river_id="beaver-river-kinbasket-canyon",
        difficulty_class="Class IV/IV+",
        difficulty_min=4,
        difficulty_max=4,
        description="Overview: Early season warm up run with a linear class I to IV+ progression.",
        estimated_time="2 hours",
        season="Early Spring",
        flow_unit="cms",
        station_id="08NB019",
        permits="Everything is scoutable (the 2nd drop of the double drop is hard to get a really good look at)",
        source="bcwhitewater.org",
        source_url="https://www.bcwhitewater.org/reaches/beaver-river-kinbasket-canyon",
        created_by="bcwhitewater-import"
    )
    
    print("\nRiver Run Document ID:", run.document_id)
    print("River Run Data:", run.to_dict())
