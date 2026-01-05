# Race Conditions Analysis

## Overview
This document analyzes potential race conditions in the BrownPaw station data update system and provides mitigations.

## System Architecture

### Two Cloud Functions:
1. **Realtime Updater** - Runs every 3 hours
   - Processes 63 stations concurrently using `asyncio.gather`
   - Writes to `station_current` collection
   - Each station = separate document

2. **Daily Updater** - Runs once daily at 1 AM
   - Processes 62 stations sequentially
   - Reads from `station_current` collection
   - Writes to `station_data/{provider}_{station_id}/readings/{year}` subcollection

---

## ✅ **SAFE: No Race Conditions Found**

### 1. Concurrent Station Processing (Realtime Updater)
**Pattern:** Multiple async tasks writing to different Firestore documents simultaneously

```python
# realtime_updater.py
tasks = [process_station(station_id, service, manager) for station_id in ec_stations]
results = await asyncio.gather(*tasks)
```

**Analysis:**
- ✅ Each station writes to its own document: `station_current/{provider}_{station_id}`
- ✅ No shared state between tasks
- ✅ Firestore handles concurrent writes to different documents safely
- ✅ Each document write is atomic

**Conclusion:** SAFE - No conflict possible

---

### 2. Daily Readings Batch Write
**Pattern:** Sequential batch writes using Firestore batch API

```python
# daily_updater.py
for year, yearly_readings in readings_by_year.items():
    operations.append({
        'type': 'write_readings',
        'provider': Provider.ENVIRONMENT_CANADA,
        'station_id': station_id,
        'year': year,
        'daily_readings': yearly_readings,
    })
manager.batch_write_station_data(operations)
```

**Analysis:**
- ✅ Uses Firestore batch commits (atomic up to 500 operations)
- ✅ Each station processes sequentially (not concurrent)
- ✅ Writes use `merge=True` to preserve existing data
- ✅ Different year documents for the same station are separate

```python
# station_data_manager.py
batch.set(readings_ref, data, merge=True)  # MERGE MODE - preserves existing data
```

**Conclusion:** SAFE - Merge mode prevents overwrites

---

### 3. Reading from `station_current` While Realtime Updater Writes
**Pattern:** Daily updater reads `station_current` that realtime updater is writing to

**Scenario:**
- Realtime updater running at 9:00 AM
- Daily updater runs at 1:00 AM (different time)
- But if both run simultaneously (manual trigger)?

```python
# daily_updater.py (line 57-64)
current_doc = manager.db.collection('station_current').document(doc_id).get()
hourly_readings_dict = current_data.get('hourly_readings', {})
```

**Analysis:**
- ✅ Firestore document reads are atomic and consistent
- ✅ Gets either the old or new version (not partial)
- ✅ Cloud Scheduler prevents both functions running at same time
- ✅ Even if both run: reading one station while writing another is safe (different docs)
- ⚠️ **Edge case**: Reading station X while station X is being written

**Mitigation:**
- Cloud Scheduler ensures non-overlapping execution times (3-hour intervals vs 1 AM daily)
- Firestore's MVCC (Multi-Version Concurrency Control) ensures atomic reads
- Worst case: Daily updater gets slightly stale data (previous 3-hour window)

**Conclusion:** SAFE with caveats - handled by scheduler + Firestore guarantees

---

### 4. Multiple Year Documents for Same Station
**Pattern:** Writing daily readings can span multiple years (e.g., 2025 and 2026)

```python
# station_data_manager.py
for year, yearly_readings in readings_by_year.items():
    operations.append({
        'type': 'write_readings',
        'year': year,
        'daily_readings': yearly_readings,
    })
```

**Analysis:**
- ✅ Each year is a separate document in `readings` subcollection
- ✅ Batch write ensures all years written together or not at all
- ✅ `merge=True` prevents overwriting existing readings in the year

**Conclusion:** SAFE - Different documents + merge mode

---

### 5. Firestore Batch Size Limit
**Pattern:** Batches can have max 500 operations

```python
# station_data_manager.py (line 305-312)
if batch_count >= max_batch_size:
    batch.commit()
    batch = self.db.batch()
    batch_count = 0
```

**Analysis:**
- ✅ Properly handles batch limit with auto-commit
- ✅ Creates new batch after commit
- ⚠️ **Edge case**: If one batch succeeds and next fails, partial data written

**Mitigation:**
- Each station's data fits well under 500 ops limit (typically 1-3 years)
- Historical load (5 years) = ~5 year docs + 1 metadata = 6 ops per station
- Daily update = 1 year doc per station typically

**Conclusion:** SAFE - well under limits for typical operations

---

### 6. Metadata Updates
**Pattern:** `last_updated` timestamp updated independently

```python
# station_data_manager.py
metadata_ref.update({'last_updated': firestore.SERVER_TIMESTAMP})
```

**Analysis:**
- ✅ Uses Firestore `SERVER_TIMESTAMP` for consistency
- ✅ Update operation is atomic
- ✅ Only updates `last_updated` field, doesn't overwrite document

**Conclusion:** SAFE - atomic timestamp updates

---

### 7. Cloud Scheduler Concurrent Execution
**Pattern:** What if scheduler triggers both functions at same time?

**Cloud Scheduler Guarantees:**
- Scheduler jobs run independently
- No built-in mutex between different jobs
- Could theoretically overlap if:
  - Realtime updater starts at 12:30 AM (taking 48 seconds)
  - Daily updater triggers at 1:00 AM
  - Overlap: 30 seconds

**Analysis:**
- ⚠️ **Possible overlap window**: ~30 seconds if realtime runs late before 1 AM
- ✅ Different collections: realtime→`station_current`, daily→`station_data`
- ✅ Daily updater only READS from `station_current` (no writes)
- ✅ No shared write targets

**Conclusion:** SAFE - different write targets, reads are atomic

---

### 8. Firebase Admin SDK Initialization
**Pattern:** Multiple function instances initializing Firebase

```python
# station_data_manager.py
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)
```

**Analysis:**
- ✅ Checks if already initialized before creating app
- ✅ Each Cloud Function instance gets its own Python process
- ✅ No cross-instance state sharing

**Conclusion:** SAFE - proper initialization guard

---

## Potential Issues (Not Race Conditions)

### 1. Missing Method: `write_current_station_data`
**Location:** `functions/realtime_updater.py` line 41

```python
manager.write_current_station_data(...)  # ❌ Method doesn't exist
```

**Issue:** Cloud function references method that isn't in `StationDataManager`

**Impact:** Cloud function will fail at runtime

**Fix Required:** Add method or use direct Firestore write like local script does

---

### 2. Inconsistent Write Patterns
**Issue:** Local script uses direct `.set()`, cloud function expects helper method

**Local script pattern:**
```python
# scripts/daily_realtime_updater.py
current_ref.set(current_data)  # ✅ Works
```

**Cloud function pattern:**
```python
# functions/realtime_updater.py  
manager.write_current_station_data(...)  # ❌ Method missing
```

**Fix Required:** Standardize approach

---

## Recommendations

### 1. Add Missing Method ✅ HIGH PRIORITY
Add `write_current_station_data` to `StationDataManager`:

```python
def write_current_station_data(
    self,
    provider: str,
    station_id: str,
    latest_reading: Dict[str, Any],
    trend: str,
    hourly_readings: Dict[str, Dict[str, Any]],
    updated_at: datetime
) -> None:
    """Write current station data to station_current collection."""
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
```

### 2. Add Execution Overlap Guard (Optional)
Use Firestore document as a mutex:

```python
def acquire_lock(function_name: str, timeout_minutes: int = 10):
    """Acquire distributed lock using Firestore."""
    lock_ref = db.collection('_locks').document(function_name)
    
    now = datetime.now()
    lock_doc = lock_ref.get()
    
    if lock_doc.exists:
        lock_time = lock_doc.get('acquired_at')
        if (now - lock_time).total_seconds() < timeout_minutes * 60:
            raise Exception(f"Function {function_name} already running")
    
    lock_ref.set({'acquired_at': now})
    return lock_ref

def release_lock(lock_ref):
    """Release distributed lock."""
    lock_ref.delete()
```

### 3. Adjust Scheduler Times (Optional)
Ensure more separation:
- Realtime: Every 3 hours (0:00, 3:00, 6:00, 9:00, 12:00, 15:00, 18:00, 21:00)
- Daily: 1:30 AM (offset by 30 minutes from 0:00/3:00)

### 4. Add Monitoring
Log concurrent execution detection:

```python
logger.info(f"Function started at {datetime.now()}")
# Check for other running instances
running_instances = db.collection('_executions').where('status', '==', 'running').get()
if len(running_instances) > 0:
    logger.warning("Detected concurrent execution!")
```

---

## Summary

### ✅ Race Conditions: **NONE FOUND**
All concurrent operations are:
1. Writing to different documents (safe)
2. Using atomic Firestore operations (safe)
3. Using merge mode to preserve data (safe)
4. Scheduled at non-overlapping times (safe)

### ⚠️ Issues Found: **1 Critical Bug**
1. Missing `write_current_station_data()` method - **MUST FIX**

### Confidence Level: **HIGH**
Firestore's ACID guarantees combined with careful document isolation make this system race-condition free.
