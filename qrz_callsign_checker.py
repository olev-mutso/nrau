#!/usr/bin/env python3
"""
QRZ.com Callsign Checker Script
===============================

This script checks callsign existence and details using the QRZ.com XML API.
Requires QRZ.com subscription for XML API access.

Usage:
    python qrz_callsign_checker.py --callsign LB4UH
    python qrz_callsign_checker.py --file callsigns.txt
    python qrz_callsign_checker.py --cabrillo main_2_file_cabrillo.log

Author: Generated for NRAU contest log analysis
"""

import argparse
import requests
import xml.etree.ElementTree as ET
import time
import re
import sys
from typing import List, Dict, Optional, Tuple
import csv
from pathlib import Path

class QRZChecker:
    def __init__(self, username: str, password: str):
        """Initialize QRZ checker with credentials."""
        self.username = username
        self.password = password
        self.session_key = None
        self.base_url = "https://xmldata.qrz.com/xml/current/"
        self.rate_limit_delay = 1.0  # seconds between requests
        
    def login(self) -> bool:
        """Authenticate with QRZ and get session key."""
        try:
            params = {
                'username': self.username,
                'password': self.password,
                'agent': 'nrau_contest_checker_v1.0'
            }
            
            response = requests.get(self.base_url, params=params, timeout=10)
            response.raise_for_status()
            
            root = ET.fromstring(response.content)
            session = root.find('.//Key')
            
            if session is not None:
                self.session_key = session.text
                print(f"✅ Logged into QRZ.com successfully")
                return True
            else:
                error = root.find('.//Error')
                error_msg = error.text if error is not None else "Unknown error"
                print(f"❌ QRZ login failed: {error_msg}")
                return False
                
        except Exception as e:
            print(f"❌ QRZ login error: {e}")
            return False
    
    def lookup_callsign(self, callsign: str) -> Optional[Dict]:
        """Look up a single callsign."""
        if not self.session_key:
            if not self.login():
                return None
        
        try:
            # Clean callsign (remove /P, /M, etc.)
            clean_call = re.sub(r'/[A-Z0-9]+$', '', callsign.upper().strip())
            
            params = {
                's': self.session_key,
                'callsign': clean_call
            }
            
            response = requests.get(self.base_url, params=params, timeout=10)
            response.raise_for_status()
            
            root = ET.fromstring(response.content)
            
            # Check for session expiry
            session_error = root.find('.//Error')
            if session_error is not None and 'Session Timeout' in session_error.text:
                print("🔄 Session expired, re-authenticating...")
                if self.login():
                    return self.lookup_callsign(callsign)  # Retry once
                return None
            
            # Extract callsign data
            callsign_elem = root.find('.//Callsign')
            if callsign_elem is not None:
                result = {
                    'callsign': callsign_elem.find('call').text if callsign_elem.find('call') is not None else clean_call,
                    'name': callsign_elem.find('fname').text if callsign_elem.find('fname') is not None else '',
                    'country': callsign_elem.find('country').text if callsign_elem.find('country') is not None else '',
                    'dxcc': callsign_elem.find('dxcc').text if callsign_elem.find('dxcc') is not None else '',
                    'state': callsign_elem.find('state').text if callsign_elem.find('state') is not None else '',
                    'grid': callsign_elem.find('grid').text if callsign_elem.find('grid') is not None else '',
                    'addr2': callsign_elem.find('addr2').text if callsign_elem.find('addr2') is not None else '',
                    'expires': callsign_elem.find('expdate').text if callsign_elem.find('expdate') is not None else '',
                    'class': callsign_elem.find('class').text if callsign_elem.find('class') is not None else '',
                    'found': True
                }
                return result
            else:
                # Check for error message
                error = root.find('.//Error')
                error_msg = error.text if error is not None else "Not found"
                return {
                    'callsign': clean_call,
                    'error': error_msg,
                    'found': False
                }
                
        except Exception as e:
            return {
                'callsign': callsign,
                'error': f"Lookup error: {e}",
                'found': False
            }
    
    def check_callsigns_from_cabrillo(self, cabrillo_file: str) -> List[Dict]:
        """Extract callsigns from cabrillo log and check them."""
        callsigns = set()
        
        try:
            with open(cabrillo_file, 'r', encoding='utf-8') as f:
                for line_num, line in enumerate(f, 1):
                    if line.startswith('QSO:'):
                        # Parse QSO line
                        # Format: QSO:  freq mode date time mycall rst# myexch callsign rst# theirexch mult
                        parts = line.strip().split()
                        if len(parts) >= 11:
                            worked_callsign = parts[9]  # The station we worked
                            callsigns.add(worked_callsign)
            
            print(f"📊 Found {len(callsigns)} unique callsigns in {cabrillo_file}")
            
        except Exception as e:
            print(f"❌ Error reading cabrillo file: {e}")
            return []
        
        # Check all callsigns
        results = []
        for i, callsign in enumerate(sorted(callsigns), 1):
            print(f"🔍 Checking {i}/{len(callsigns)}: {callsign}")
            result = self.lookup_callsign(callsign)
            if result:
                results.append(result)
            
            # Rate limiting
            if i < len(callsigns):
                time.sleep(self.rate_limit_delay)
        
        return results
    
    def save_results(self, results: List[Dict], output_file: str):
        """Save results to CSV file."""
        try:
            with open(output_file, 'w', newline='', encoding='utf-8') as f:
                if not results:
                    return
                
                fieldnames = ['callsign', 'found', 'name', 'country', 'dxcc', 'state', 'grid', 'addr2', 'expires', 'class', 'error']
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                
                for result in results:
                    # Ensure all fields exist
                    row = {field: result.get(field, '') for field in fieldnames}
                    writer.writerow(row)
            
            print(f"💾 Results saved to {output_file}")
            
        except Exception as e:
            print(f"❌ Error saving results: {e}")

def main():
    parser = argparse.ArgumentParser(description='Check callsign existence using QRZ.com')
    parser.add_argument('--callsign', help='Single callsign to check')
    parser.add_argument('--file', help='File with callsigns (one per line)')
    parser.add_argument('--cabrillo', help='Cabrillo log file to extract callsigns from')
    parser.add_argument('--username', help='QRZ.com username (or set QRZ_USERNAME env var)')
    parser.add_argument('--password', help='QRZ.com password (or set QRZ_PASSWORD env var)')
    parser.add_argument('--output', default='qrz_results.csv', help='Output CSV file')
    parser.add_argument('--delay', type=float, default=1.0, help='Delay between requests (seconds)')
    
    args = parser.parse_args()
    
    # Get credentials
    import os
    username = args.username or os.environ.get('QRZ_USERNAME')
    password = args.password or os.environ.get('QRZ_PASSWORD')
    
    if not username or not password:
        print("❌ QRZ.com credentials required!")
        print("Set QRZ_USERNAME and QRZ_PASSWORD environment variables or use --username/--password")
        print("Example: export QRZ_USERNAME=your_username")
        print("         export QRZ_PASSWORD=your_password")
        sys.exit(1)
    
    # Initialize checker
    checker = QRZChecker(username, password)
    checker.rate_limit_delay = args.delay
    
    if not checker.login():
        sys.exit(1)
    
    results = []
    
    # Process single callsign
    if args.callsign:
        result = checker.lookup_callsign(args.callsign)
        if result:
            results.append(result)
            if result['found']:
                print(f"✅ {result['callsign']}: {result.get('name', 'N/A')} in {result.get('country', 'N/A')}")
            else:
                print(f"❌ {result['callsign']}: {result.get('error', 'Not found')}")
    
    # Process file with callsigns
    elif args.file:
        try:
            with open(args.file, 'r') as f:
                callsigns = [line.strip() for line in f if line.strip()]
            
            for i, callsign in enumerate(callsigns, 1):
                print(f"🔍 Checking {i}/{len(callsigns)}: {callsign}")
                result = checker.lookup_callsign(callsign)
                if result:
                    results.append(result)
                
                if i < len(callsigns):
                    time.sleep(checker.rate_limit_delay)
                    
        except Exception as e:
            print(f"❌ Error reading file: {e}")
            sys.exit(1)
    
    # Process cabrillo log
    elif args.cabrillo:
        results = checker.check_callsigns_from_cabrillo(args.cabrillo)
    
    else:
        print("❌ Please specify --callsign, --file, or --cabrillo")
        sys.exit(1)
    
    # Save results
    if results:
        checker.save_results(results, args.output)
        
        # Summary
        found = sum(1 for r in results if r.get('found', False))
        not_found = len(results) - found
        
        print(f"\n📈 SUMMARY:")
        print(f"   Total checked: {len(results)}")
        print(f"   Found: {found} ({found/len(results)*100:.1f}%)")
        print(f"   Not found: {not_found} ({not_found/len(results)*100:.1f}%)")
        
        if not_found > 0:
            print(f"\n❌ NOT FOUND:")
            for result in results:
                if not result.get('found', False):
                    print(f"   {result['callsign']}: {result.get('error', 'Unknown error')}")

if __name__ == '__main__':
    main()