"""
Quick test to verify CSV approach works locally before deploying.
"""
import asyncio
from datetime import datetime
from station_data_manager import StationDataManager
from models import Provider
from environment_canada.realtime_data_service import RealtimeDataService

async def test_one_station():
    """Test the CSV approach with one station."""
    station_id = "08MG005"  # Adam River
    
    print(f"Testing CSV approach with station {station_id}...")
    
    # Initialize services
    manager = StationDataManager()
    
    async with RealtimeDataService() as service:
        # Fetch data
        print(f"  Fetching 720 hours of data...")
        readings = await service.fetch_latest_readings(station_id, hours=720)
        print(f"  Got {len(readings)} readings")
        
        # Get status
        status = await service.get_station_status(station_id)
        print(f"  Latest: {status['latest_reading']}")
        
        # Convert to CSV
        csv_lines = ['datetime,discharge,level']
        for r in readings:
            discharge = r.get('discharge', '')
            level = r.get('level', '')
            csv_lines.append(f"{r['datetime']},{discharge},{level}")
        readings_csv = '\n'.join(csv_lines)
        
        csv_size = len(readings_csv.encode('utf-8'))
        print(f"  CSV size: {csv_size:,} bytes ({csv_size/1024:.1f} KB)")
        print(f"  CSV lines: {len(csv_lines)}")
        
        # Test writing to Firestore
        print(f"  Writing to Firestore...")
        manager.write_current_station_data(
            provider=Provider.ENVIRONMENT_CANADA.value,
            station_id=station_id,
            latest_reading=status['latest_reading'],
            trend=status['trend'],
            hourly_readings_csv=readings_csv,
            updated_at=datetime.now()
        )
        print(f"  ✓ Successfully wrote to Firestore!")
        
        # Test reading back
        print(f"  Reading back from Firestore...")
        doc_id = f"{Provider.ENVIRONMENT_CANADA.value}_{station_id}"
        doc = manager.db.collection('station_current').document(doc_id).get()
        data = doc.to_dict()
        
        csv_back = data.get('hourly_readings_csv', '')
        print(f"  Retrieved CSV size: {len(csv_back):,} bytes")
        
        # Parse CSV back to array
        parsed_readings = []
        for line in csv_back.split('\n')[1:]:
            if not line.strip():
                continue
            parts = line.split(',')
            if len(parts) >= 3:
                reading = {'datetime': parts[0]}
                if parts[1]:
                    reading['discharge'] = float(parts[1])
                if parts[2]:
                    reading['level'] = float(parts[2])
                parsed_readings.append(reading)
        
        print(f"  Parsed {len(parsed_readings)} readings from CSV")
        print(f"  First reading: {parsed_readings[0] if parsed_readings else 'none'}")
        print(f"  Last reading: {parsed_readings[-1] if parsed_readings else 'none'}")
        
        print(f"\n✅ CSV approach works! Size is manageable and no index issues.")

if __name__ == "__main__":
    asyncio.run(test_one_station())
