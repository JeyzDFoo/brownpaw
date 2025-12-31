import requests
from bs4 import BeautifulSoup
import json
import re
import time

# Import the scraping function we already built
from scrape_bcwhitewater import scrape_reach_page

def get_all_reaches():
    """Fetch list of all river reaches from BC Whitewater"""
    print("Fetching list of all reaches from BC Whitewater...")
    
    # BC Whitewater uses a JSON API for their rivers list
    # Try to find the API endpoint or scrape the main page
    url = "https://www.bcwhitewater.org/reaches/"
    response = requests.get(url)
    response.raise_for_status()
    
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # Find all river/reach rows in the table
    reaches = []
    rows = soup.find_all('tr', class_='reach')
    
    for row in rows:
        # Find the link to the reach page
        link = row.find('a', href=lambda x: x and '/reaches/' in x)
        if not link:
            continue
            
        href = link.get('href')
        
        # Extract the reach slug
        match = re.search(r'/reaches/([^/?#]+)', href)
        if not match:
            continue
            
        slug = match.group(1)
        name = link.get_text(strip=True)
        
        # Build full URL
        if href.startswith('http'):
            full_url = href
        else:
            full_url = f"https://www.bcwhitewater.org{href}"
        
        # Extract region from the row's classes
        # The row has classes like ['reach', 'vancouver-island'] or ['reach', 'cariboo']
        region = None
        row_classes = row.get('class', [])
        for cls in row_classes:
            if cls != 'reach':
                # Convert kebab-case to Title Case (e.g., 'vancouver-island' -> 'Vancouver Island')
                region = cls.replace('-', ' ').title()
                break
        
        # Avoid duplicates
        if not any(r['url'] == full_url for r in reaches):
            reaches.append({
                'slug': slug,
                'name': name,
                'url': full_url,
                'region': region or 'BC'
            })
    
    print(f"Found {len(reaches)} unique reaches")
    return reaches

def scrape_all_reaches(output_file='bc_whitewater_data.json', delay=1, limit=None):
    """Scrape all reaches and save to JSON file
    
    Args:
        output_file: Path to save the scraped data
        delay: Delay in seconds between requests (be nice to the server)
        limit: Maximum number of reaches to scrape (None for all)
    """
    reaches_list = get_all_reaches()
    
    if not reaches_list:
        print("No reaches found!")
        return []
    
    # Limit the number of reaches if specified
    if limit:
        reaches_list = reaches_list[:limit]
        print(f"Limited to first {limit} reaches")
    
    all_data = []
    failed = []
    
    print(f"\nStarting to scrape {len(reaches_list)} reaches...")
    print(f"Delay between requests: {delay} seconds\n")
    
    for i, reach_info in enumerate(reaches_list, 1):
        print(f"\n[{i}/{len(reaches_list)}] Scraping: {reach_info['name']}")
        print(f"URL: {reach_info['url']}")
        print(f"Region: {reach_info['region']}")
        
        try:
            # Scrape the reach page with region info
            data = scrape_reach_page(reach_info['url'], region=reach_info['region'])
            
            # Add the slug for reference
            data['slug'] = reach_info['slug']
            
            all_data.append(data)
            print(f"✓ Successfully scraped {data['title']}")
            
            # Be nice to the server
            if i < len(reaches_list):
                time.sleep(delay)
                
        except Exception as e:
            print(f"✗ Failed to scrape {reach_info['name']}: {e}")
            failed.append({
                'reach': reach_info,
                'error': str(e)
            })
    
    # Save results
    print(f"\n\nSaving results to {output_file}...")
    with open(output_file, 'w') as f:
        json.dump({
            'success_count': len(all_data),
            'failed_count': len(failed),
            'reaches': all_data,
            'failed': failed
        }, f, indent=2)
    
    print(f"\n{'='*60}")
    print(f"Scraping complete!")
    print(f"Successfully scraped: {len(all_data)}")
    print(f"Failed: {len(failed)}")
    print(f"Data saved to: {output_file}")
    print(f"{'='*60}")
    
    if failed:
        print("\nFailed reaches:")
        for item in failed:
            print(f"  - {item['reach']['name']}: {item['error']}")
    
    return all_data

if __name__ == '__main__':
    import sys
    
    # Check if limit is specified
    limit = None
    if len(sys.argv) > 1:
        try:
            limit = int(sys.argv[1])
            print(f"Limiting to first {limit} reaches for testing")
        except ValueError:
            print("Usage: python3 scrape_all_bc_whitewater.py [limit]")
            sys.exit(1)
    
    # Scrape all reaches (or limited number) with a 1-second delay between requests
    scrape_all_reaches(
        output_file='bc_whitewater_all_data.json',
        delay=1,  # Be respectful to the server
        limit=limit
    )
