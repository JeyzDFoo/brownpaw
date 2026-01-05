#!/usr/bin/env python3
"""
Extract gauge station codes from bcwhitewater.org pages by scraping the gauge links.

This script re-scrapes the gauge links from bcwhitewater pages to extract
Environment Canada station codes from wateroffice URLs.
"""

import requests
from bs4 import BeautifulSoup
import json
import re
import time
from typing import Optional, Dict

def extract_station_from_url(url: str) -> Optional[str]:
    """Extract station code from wateroffice URL."""
    # Pattern: stn=08KH001
    match = re.search(r'stn=([A-Z0-9]+)', url, re.IGNORECASE)
    if match:
        return match.group(1)
    return None

def scrape_gauge_link(page_url: str) -> Optional[Dict[str, str]]:
    """
    Scrape gauge station link from a bcwhitewater reach page.
    
    Returns:
        Dict with 'code' and optionally 'name', or None if not found
    """
    try:
        response = requests.get(page_url, timeout=10)
        response.raise_for_status()
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Find all links
        all_links = soup.find_all('a', href=True)
        
        for link in all_links:
            href = link.get('href', '')
            
            # Check if it's a wateroffice link
            if 'wateroffice.ec.gc.ca' in href or 'ec.gc.ca' in href:
                station_code = extract_station_from_url(href)
                
                if station_code:
                    # Try to get station name if available in the link text or nearby
                    link_text = link.get_text(strip=True)
                    
                    return {
                        'code': station_code,
                        'url': href,
                        'gauge_display': link_text
                    }
        
        return None
        
    except Exception as e:
        print(f"  Error scraping {page_url}: {e}")
        return None

def main():
    """Re-scrape all bcwhitewater pages to extract gauge station codes."""
    
    # Load existing data
    print("Loading existing bcwhitewater data...")
    with open('bc_whitewater_all_data.json', 'r') as f:
        data = json.load(f)
    
    reaches = data['reaches']
    print(f"Found {len(reaches)} reaches to process")
    
    updated_count = 0
    already_had = 0
    not_found = 0
    
    for i, reach in enumerate(reaches, 1):
        url = reach['url']
        title = reach['title']
        
        # Skip if already has gauge_station with code
        gauge_station = reach.get('gauge_station')
        if gauge_station and isinstance(gauge_station, dict) and gauge_station.get('code'):
            already_had += 1
            continue
        
        # Only process if it has gauge_info (indicator that page has gauge data)
        if not reach.get('gauge_info'):
            not_found += 1
            continue
        
        print(f"\n[{i}/{len(reaches)}] {title}")
        print(f"  Scraping gauge link from {url}")
        
        gauge_data = scrape_gauge_link(url)
        
        if gauge_data:
            reach['gauge_station'] = {
                'code': gauge_data['code'],
                'name': reach.get('gauge_info', '').split('(')[0].strip() if reach.get('gauge_info') else ''
            }
            reach['gauge_link'] = gauge_data['url']
            updated_count += 1
            print(f"  ✓ Found station: {gauge_data['code']}")
        else:
            not_found += 1
            print(f"  ✗ No gauge link found")
        
        # Be nice to the server
        time.sleep(0.5)
    
    # Save updated data
    output_file = 'bc_whitewater_all_data_with_stations.json'
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Already had station codes: {already_had}")
    print(f"Newly extracted: {updated_count}")
    print(f"No gauge link found: {not_found}")
    print(f"Total with station codes: {already_had + updated_count}")
    print(f"\nUpdated data saved to: {output_file}")

if __name__ == '__main__':
    main()
