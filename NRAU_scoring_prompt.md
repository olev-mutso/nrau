# NRAU-Baltic Contest Score Calculator

## Purpose
Calculate accurate contest scores from Cabrillo logs for NRAU-Baltic contest, which combines both PHONE and CW modes with separate multiplier tracking.

## Task Description
Analyze a Cabrillo log file and calculate the correct NRAU-Baltic contest score. The contest has specific scoring rules that many logging programs get wrong.

## Scoring Rules
- **2 points per QSO** (assuming correct exchange)
- **Multipliers**: Each unique region worked per mode AND band combination
- **Bands**: 80m (3xxx kHz) and 40m (7xxx kHz) 
- **Modes**: PHONE (PH) and CW
- **Final Score**: (Total QSO Points) × (Total Multipliers)

## Key Understanding
This is actually **4 separate contests** in one log:
1. 80m PHONE
2. 40m PHONE  
3. 80m CW
4. 40m CW

Each mode/band combination has its own multiplier count. If you work region "KN" on all 4 combinations, that counts as 4 multipliers total.

## Required Analysis
1. Count QSOs for each mode/band combination
2. Count unique regions (2-letter exchange codes) for each mode/band combination
3. Calculate total QSO points (all QSOs × 2)
4. Calculate total multipliers (sum of all 4 categories)
5. Calculate final score (points × multipliers)

## Expected Output Format
```
NRAU-Baltic Contest Score:

QSO Breakdown:
- 80m PHONE: X QSOs × 2 = X points
- 40m PHONE: X QSOs × 2 = X points  
- 80m CW: X QSOs × 2 = X points
- 40m CW: X QSOs × 2 = X points
Total QSO Points: X

Multipliers:
- 80m PHONE: X unique regions
- 40m PHONE: X unique regions
- 80m CW: X unique regions  
- 40m CW: X unique regions
Total Multipliers: X

Final Score: X points × X multipliers = X
```

## Notes
- Ignore comment lines (starting with #)
- Band identification: Column 2 frequency (3xxx = 80m, 7xxx = 40m)
- Mode identification: Column 3 mode field (PH or CW) - NOT random text in exchange!
- Region code is the last field in each QSO line
- Contest logging software often miscalculates this due to complex multiplier rules

## Correct Parsing Commands
Use positional parsing to avoid false matches:
```bash
# 80m PHONE QSOs
grep "^QSO:" logfile.log | awk '$3=="PH" && $2~/^3/ {print}'

# 40m PHONE QSOs  
grep "^QSO:" logfile.log | awk '$3=="PH" && $2~/^7/ {print}'

# 80m CW QSOs
grep "^QSO:" logfile.log | awk '$3=="CW" && $2~/^3/ {print}'

# 40m CW QSOs
grep "^QSO:" logfile.log | awk '$3=="CW" && $2~/^7/ {print}'
```

**WARNING**: Never use simple grep patterns like `grep " PH "` as this will match region exchanges containing "PH" (like "001 PH"), not the actual mode field!