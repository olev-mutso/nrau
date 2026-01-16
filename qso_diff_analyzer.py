#!/usr/bin/env python3

import sys
import re

def extract_qsos(filename):
    """Extract QSO lines from cabrillo file, ignoring comments."""
    qsos = []
    with open(filename, 'r') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if line.startswith('QSO:'):
                qsos.append((line_num, line))
    return qsos

def parse_qso(qso_line):
    """Parse QSO line into components for comparison."""
    parts = qso_line.split()
    if len(parts) >= 13:
        return {
            'freq': parts[1],
            'mode': parts[2], 
            'date': parts[3],
            'time': parts[4],
            'mycall': parts[5],
            'rst_sent': parts[6],
            'seq_sent': parts[7],
            'my_region': parts[8],
            'other_call': parts[9],
            'rst_rcvd': parts[10],
            'seq_rcvd': parts[11],
            'other_region': parts[12]
        }
    return None

def compare_qsos(rev0_file, rev4_file):
    """Compare QSOs between two revisions and show differences."""
    
    rev0_qsos = extract_qsos(rev0_file)
    rev4_qsos = extract_qsos(rev4_file)
    
    print("=" * 80)
    print("QSO AMENDMENT REPORT: REV_0 → REV_4")
    print("=" * 80)
    
    amendment_count = 0
    
    # Compare by position (assuming QSOs are in same order)
    max_len = max(len(rev0_qsos), len(rev4_qsos))
    
    for i in range(max_len):
        if i < len(rev0_qsos) and i < len(rev4_qsos):
            orig_line, orig_qso = rev0_qsos[i]
            new_line, new_qso = rev4_qsos[i]
            
            if orig_qso != new_qso:
                amendment_count += 1
                
                print(f"\n{'-' * 60}")
                print(f"AMENDMENT #{amendment_count:03d}")
                print(f"{'-' * 60}")
                print(f"ORIGINAL (REV_0 L{orig_line}):")
                print(f"  {orig_qso}")
                print(f"AMENDED  (REV_4 L{new_line}):")
                print(f"  {new_qso}")
                
                # Show field-by-field differences
                orig_parsed = parse_qso(orig_qso)
                new_parsed = parse_qso(new_qso)
                
                if orig_parsed and new_parsed:
                    changes = []
                    for field in orig_parsed:
                        if orig_parsed[field] != new_parsed[field]:
                            changes.append(f"{field}: '{orig_parsed[field]}' → '{new_parsed[field]}'")
                    
                    if changes:
                        print(f"CHANGES: {', '.join(changes)}")
        
        elif i < len(rev0_qsos):
            # QSO removed
            amendment_count += 1
            orig_line, orig_qso = rev0_qsos[i]
            print(f"\n{'-' * 60}")
            print(f"AMENDMENT #{amendment_count:03d}")
            print(f"{'-' * 60}")
            print(f"REMOVED (REV_0 L{orig_line}):")
            print(f"  {orig_qso}")
            
        elif i < len(rev4_qsos):
            # QSO added
            amendment_count += 1
            new_line, new_qso = rev4_qsos[i]
            print(f"\n{'-' * 60}")
            print(f"AMENDMENT #{amendment_count:03d}")
            print(f"{'-' * 60}")
            print(f"ADDED (REV_4 L{new_line}):")
            print(f"  {new_qso}")
    
    print(f"\n{'=' * 80}")
    print(f"TOTAL AMENDMENTS: {amendment_count}")
    print(f"{'=' * 80}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 qso_diff_analyzer.py rev_0.log rev_4.log")
        sys.exit(1)
    
    compare_qsos(sys.argv[1], sys.argv[2])