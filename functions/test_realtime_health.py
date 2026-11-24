"""Tests for the realtime updater's health record. Run: pytest -q"""

import sys
import types
from datetime import datetime, timezone

# realtime_updater imports Firebase-backed modules; stub the ones that
# can't load without credentials so the pure helpers can be tested.
import importlib  # noqa: E402

for name in ('flow_alerts', 'flowworks', 'metro_vancouver', 'scripts',
             'scripts.station_data_manager', 'scripts.models',
             'scripts.environment_canada',
             'scripts.environment_canada.realtime_data_service'):
    try:
        importlib.import_module(name)
    except Exception:
        sys.modules[name] = types.ModuleType(name)
for module, attr, value in (
    ('scripts.station_data_manager', 'StationDataManager', object),
    ('scripts.models', 'Provider', types.SimpleNamespace(
        ENVIRONMENT_CANADA=types.SimpleNamespace(value='environment_canada'))),
    ('scripts.environment_canada.realtime_data_service',
     'RealtimeDataService', object),
):
    if not hasattr(sys.modules[module], attr):
        setattr(sys.modules[module], attr, value)

import realtime_updater as ru  # noqa: E402


def test_degraded():
    assert not ru.degraded(10, 0)
    assert not ru.degraded(8, 2)
    assert ru.degraded(7, 3)
    assert ru.degraded(0, 1)
    assert not ru.degraded(0, 0)


class FakeDb:
    def __init__(self):
        self.written = {}

    def collection(self, name):
        db = self

        class Col:
            def document(self, doc_id):
                class Doc:
                    def set(self, data):
                        db.written[f'{name}/{doc_id}'] = data
                return Doc()
        return Col()


def test_write_health():
    db = FakeDb()
    now = datetime(2026, 11, 24, tzinfo=timezone.utc)
    ru.write_health(db, 9, ['08GA072'], ['metro_vancouver_capilano'], now=now)
    health = db.written['app_config/gauge_health']
    assert health['lastRunAt'] == now
    assert health['environmentCanadaOk'] == 9
    assert health['environmentCanadaFailed'] == ['08GA072']
    assert health['degraded'] is False
