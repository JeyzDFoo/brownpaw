import math

import pytest

import live


def test_parse_request():
    assert live.parse_request('environment_canada_08HA011', '6') == (
        'environment_canada', '08HA011', 6)
    assert live.parse_request('metro_vancouver_capilano', '') == (
        'metro_vancouver', 'capilano', 24)
    assert live.parse_request('flowworks_lynn', '9999') == (
        'flowworks', 'lynn', 720)
    assert live.parse_request('environment_canada_08HA011', '0')[2] == 1
    for bad in ['', 'environment_canada_08ha011', '../etc', 'x']:
        with pytest.raises(ValueError):
            live.parse_request(bad, '6')


def test_to_csv_sorts_and_drops_non_finite():
    csv = live.to_csv([
        {'datetime': '2026-11-24T12:00:00Z', 'discharge': 3.5, 'level': None},
        {'datetime': '2026-11-24T11:00:00Z', 'discharge': math.nan, 'level': 1.2},
    ])
    assert csv.split('\n') == [
        'datetime,discharge,level',
        '2026-11-24T11:00:00Z,,1.2',
        '2026-11-24T12:00:00Z,3.5,',
    ]
