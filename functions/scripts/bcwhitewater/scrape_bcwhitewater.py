import requests
from bs4 import BeautifulSoup
import json
import re

def scrape_reach_page(url, region=None):
    """Scrape detailed information from a specific reach page
    
    Args:
        url: The URL of the reach page
        region: Optional region name (e.g., 'Cariboo', 'Vancouver Island', etc.)
                If not provided, will be set to 'BC'
    """
    print(f"Scraping: {url}")
    
    response = requests.get(url)
    response.raise_for_status()
    
    soup = BeautifulSoup(response.content, 'html.parser')
    
    data = {
        'url': url,
        'province': 'BC',
        'region': region or 'BC',  # Use provided region or default to 'BC'
        'title': None,
        'class': None,
        'description': None,
        'scouting': None,
        'time': None,
        'season': None,
        'gauge_info': None,
        'gauge_station': None,
        'put_in': None,
        'take_out': None,
        'images': [],  # List of image URLs
        'full_text': None
    }
    
    # Extract title
    h1 = soup.find('h1')
    if h1:
        data['title'] = h1.get_text(strip=True)
    
    # Try to extract sub-region from page
    # Look for region/zone in links, breadcrumbs, or filters
    if not region:
        # Check for links that might indicate the region
        all_links = soup.find_all('a', href=True)
        for link in all_links:
            href = link.get('href', '')
            text = link.get_text(strip=True)
            # Look for region filters or zone parameters
            if 'region=' in href or 'zone=' in href:
                # Extract the region value
                if 'region=' in href:
                    region_match = re.search(r'region=([^&]+)', href)
                    if region_match:
                        data['region'] = region_match.group(1).replace('+', ' ').replace('%20', ' ')
                        break
    
    # Get all text content
    body = soup.find('body')
    if body:
        text = body.get_text(separator='\n', strip=True)
        data['full_text'] = text
        
        # Parse structured information from the text
        lines = text.split('\n')
        
        # Extract fields that appear before the main description
        for i, line in enumerate(lines):
            if line.strip() == 'Class' and i + 1 < len(lines):
                data['class'] = lines[i + 1].strip()
            elif line.strip() == 'Scouting / Portaging' and i + 1 < len(lines):
                data['scouting'] = lines[i + 1].strip()
            elif line.strip() == 'Time' and i + 1 < len(lines):
                data['time'] = lines[i + 1].strip()
            elif line.strip() == 'When to Go' and i + 1 < len(lines):
                data['season'] = lines[i + 1].strip()
            elif line.strip() == 'Gauge' and i + 1 < len(lines):
                data['gauge_info'] = lines[i + 1].strip()
            elif line.strip() == 'What It\'s Like' and i + 1 < len(lines):
                data['description'] = lines[i + 1].strip()
        
        # Extract gauge station from the description text
        # Look for patterns like "gauge on the SALMON RIVER NEAR SAYWARD (08HD006)"
        gauge_pattern = r'gauge on the ([\w\s]+)\s*\((\w+)\)'
        match = re.search(gauge_pattern, text, re.IGNORECASE)
        if match:
            station_name = match.group(1).strip()
            station_code = match.group(2).strip()
            data['gauge_station'] = {
                'name': station_name,
                'code': station_code
            }
    
    # Look for GPS coordinates in the HTML
    # Check for iframe, script tags, or data attributes that might contain coordinates
    
    # Look for Google Maps iframes
    iframes = soup.find_all('iframe')
    for iframe in iframes:
        src = iframe.get('src', '')
        if 'google.com/maps' in src or 'maps' in src.lower():
            print(f"\n=== Found map iframe ===")
            print(f"Source: {src}")
            # Extract coordinates from Google Maps URL
            coord_pattern = r'@(-?\d+\.\d+),(-?\d+\.\d+)'
            coord_match = re.search(coord_pattern, src)
            if coord_match:
                lat = float(coord_match.group(1))
                lon = float(coord_match.group(2))
                print(f"Coordinates from iframe: {lat}, {lon}")
    
    # Look for data attributes or script tags with coordinates
    scripts = soup.find_all('script')
    for script in scripts:
        script_text = script.string if script.string else ''
        # Look for reachPois data structure
        if 'reachPois' in script_text:
            print(f"\n=== Found reachPois data ===")
            # Extract the reachPois array
            pattern = r'reachPois\s*=\s*(\[.*?\]);'
            match = re.search(pattern, script_text, re.DOTALL)
            if match:
                try:
                    pois_json = match.group(1)
                    pois = json.loads(pois_json)
                    
                    # Extract put-in and take-out
                    for poi in pois:
                        if poi.get('point_type') == 'putin':
                            lon, lat = poi['lonlat']
                            data['put_in'] = {
                                'name': poi.get('name'),
                                'description': poi.get('description'),
                                'latitude': lat,
                                'longitude': lon
                            }
                        elif poi.get('point_type') == 'takeout':
                            lon, lat = poi['lonlat']
                            # Take the first takeout point (there might be multiple)
                            if not data['take_out']:
                                data['take_out'] = {
                                    'name': poi.get('name'),
                                    'description': poi.get('description'),
                                    'latitude': lat,
                                    'longitude': lon
                                }
                    
                    print(f"Put-in: {data['put_in']}")
                    print(f"Take-out: {data['take_out']}")
                except Exception as e:
                    print(f"Error parsing reachPois: {e}")
    
    # Look for any elements with data-lat, data-lng attributes
    elements_with_coords = soup.find_all(attrs={'data-lat': True}) + soup.find_all(attrs={'data-lng': True})
    if elements_with_coords:
        print(f"\n=== Found {len(elements_with_coords)} elements with coordinate attributes ===")
        for elem in elements_with_coords:
            print(f"Element: {elem.name}, lat: {elem.get('data-lat')}, lng: {elem.get('data-lng')}")
    
    # Extract images
    # Look for images in the content area (excluding nav, header, footer)
    content_images = []
    
    # Find action-text-attachment figures (these are the main content images)
    action_text_attachments = soup.find_all('action-text-attachment')
    for attachment in action_text_attachments:
        img_url = attachment.get('url')
        caption = attachment.get('caption', '')
        if img_url:
            content_images.append({
                'url': img_url,
                'caption': caption
            })
            print(f"\n=== Found image: {caption or 'No caption'} ===")
    
    # Also look for regular img tags in the main content
    imgs = soup.find_all('img')
    for img in imgs:
        src = img.get('src', '')
        alt = img.get('alt', '')
        # Filter out nav/logo images
        if 'active_storage' in src or 'rails' in src:
            # This is likely a content image
            if not any(existing['url'] == src for existing in content_images):
                content_images.append({
                    'url': src,
                    'caption': alt
                })
    
    data['images'] = content_images
    
    return data

def scrape_adam_river():
    """Scrape Adam River specific page"""
    url = "https://www.bcwhitewater.org/reaches/adam-river"
    # Adam River is in the Sayward area on Vancouver Island
    return scrape_reach_page(url, region='Vancouver Island')

if __name__ == "__main__":
    data = scrape_adam_river()
    print("\n=== Extracted Data ===")
    print(json.dumps(data, indent=2))
