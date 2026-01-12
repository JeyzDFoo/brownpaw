import json

# Read the full data
with open('bc_whitewater_all_data.json', 'r') as f:
    data = json.load(f)

# Create GeoJSON FeatureCollection
features = []

for reach in data['reaches']:
    # Create put_in feature if available
    if reach.get('put_in') and reach['put_in'].get('latitude') and reach['put_in'].get('longitude'):
        put_in_feature = {
            'type': 'Feature',
            'geometry': {
                'type': 'Point',
                'coordinates': [reach['put_in']['longitude'], reach['put_in']['latitude']]
            },
            'properties': {
                'title': reach['title'],
                'region': reach['region'],
                'class': reach['class'],
                'location_type': 'put_in',
                'description': reach['put_in'].get('description', ''),
                'url': reach.get('url', '')
            }
        }
        features.append(put_in_feature)
    
    # Create take_out feature if available
    if reach.get('take_out') and reach['take_out'].get('latitude') and reach['take_out'].get('longitude'):
        take_out_feature = {
            'type': 'Feature',
            'geometry': {
                'type': 'Point',
                'coordinates': [reach['take_out']['longitude'], reach['take_out']['latitude']]
            },
            'properties': {
                'title': reach['title'],
                'region': reach['region'],
                'class': reach['class'],
                'location_type': 'take_out',
                'description': reach['take_out'].get('description', ''),
                'url': reach.get('url', '')
            }
        }
        features.append(take_out_feature)

# Create GeoJSON structure
geojson = {
    'type': 'FeatureCollection',
    'features': features
}

# Write to new file
with open('bc_whitewater_markers.geojson', 'w') as f:
    json.dump(geojson, f, indent=2)

print(f'Created bc_whitewater_markers.geojson with {len(features)} features')
