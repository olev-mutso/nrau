# DXLog .NOT File Merger - Complete Workflow

## Overview
This prompt guides the process of finding DXLog .not files containing operator notes and merging them into the main cabrillo contest log file. The .not files contain corrections, clarifications, and operational notes that need to be integrated with their corresponding QSO entries.

## Input Requirements
- **Main cabrillo log file**: Contest log in cabrillo format with QSO entries
- **Source dump directory**: Directory structure containing .not files (typically `src_dump/`)
- **Note file format**: DXLog-generated .dxn.not files

## .NOT File Structure
Each .not file contains entries in this format:
```
STATION QSO# DATE TIME BAND MODE CALLSIGN : NOTE_TEXT
```

**Example entries:**
```
80A           85 2026-01-11 07:07   80 SSB   LY2TS         : ly2ts sai 76 v6i 77
40B          115 2026-01-11 07:45   40 SSB   SA0IAT        : ly4q, lb1r, ly2k, sa0iat qsy 80
80A          325 2026-01-11 10:30   80 CW    ES5KC         : change time 10>29
```

## Required Analysis Tasks

### 1. Discover .NOT Files
- Search the source dump directory structure for all `.not` files
- Use recursive globbing: `src_dump/**/*.not`
- List all found files and their locations
- Count total number of .not files discovered

### 2. Extract All Notes
For each .not file found:
- Read the complete file content
- Skip comment lines (starting with #)
- Parse each note entry to extract:
  - Station identifier (e.g., "80A", "40B")
  - QSO sequence number
  - Date and time (YYYY-MM-DD HH:MM format)
  - Band and mode information
  - Callsign
  - Note text (everything after the colon)

### 3. Parse Main Cabrillo Log
- Read the main contest log file
- Identify QSO lines (starting with "QSO:")
- Extract from each QSO line:
  - Frequency
  - Mode (PH/CW)
  - Date and time (YYYY-MM-DD HHMM format)
  - Callsign
  - Line number in file

### 4. Matching Algorithm
For each note entry, find the corresponding QSO using these criteria:

**Primary matching:**
- **Time match**: Convert .not time (HH:MM) to QSO time (HHMM)
- **Callsign match**: Exact string match (case-insensitive)
- **Date match**: Same contest date

**Secondary validation:**
- Verify band/mode consistency where possible
- Check sequence number context if available

### 5. Merge Process
- Create new output file: `main_2_file_cabrillo.log`
- Copy all original cabrillo headers unchanged
- For each QSO line:
  - Copy original QSO line exactly
  - If notes exist for this QSO, add them immediately after as comments
  - Format notes as: `# NOTE: [note_text]`
  - Handle multiple notes for same QSO (add multiple comment lines)

### 6. Error Handling
Track and report:
- **Successfully matched notes**: Count and details
- **Unmatched notes**: Notes that couldn't be matched to any QSO
- **Multiple matches**: Notes that match multiple QSOs (ambiguous)

At the end of the merged file, add ugly comments for any unmatched notes:
```
# WOOPS COULD NOT MERGE: [original .not line]
```

## Expected Output Files

1. **`main_2_file_cabrillo.log`** - Main merged file with integrated notes
2. **Merge report** - Summary of matching success/failures

## Matching Statistics to Report

### Discovery Phase
- Total .not files found
- Total note entries extracted
- Breakdown by station/band (80A, 40A, 40B, etc.)

### Matching Phase
- Total notes processed
- Successfully matched notes
- Failed matches (with reasons)
- Match rate percentage

### Note Categories
Common note types include:
- **Correction notes**: "sai XX" (said different number)
- **QSY notifications**: "qsy to 80" (frequency change info)
- **Time corrections**: "change time XX>YY"
- **Operational notes**: General contest operation info

## Quality Assurance

### Validation Checks
1. **Total preservation**: Original QSO count must match in output
2. **Header integrity**: All cabrillo headers preserved exactly
3. **Note accountability**: Every .not entry either merged or listed as failed
4. **Time format consistency**: Proper time format conversions
5. **Callsign matching**: Case-insensitive but exact matching

### Success Criteria
- All .not files successfully discovered and processed
- 95%+ note matching rate (typical for clean contest logs)
- No QSO data corruption or loss
- Clear reporting of any unmatched entries

## Technical Requirements
- Handle multiple notes per QSO (same time/callsign)
- Preserve exact spacing and formatting in QSO lines
- Convert time formats correctly (HH:MM ↔ HHMM)
- Case-insensitive callsign matching
- Robust file path handling with spaces in directory names

## Usage Instructions

1. **Prepare environment**:
   - Ensure main cabrillo log file path is available
   - Verify src_dump directory structure exists
   - Confirm write permissions for output directory

2. **Execute discovery**:
   ```
   Find all .not files in src_dump directory recursively
   ```

3. **Process notes**:
   ```
   Extract and parse all note entries from discovered files
   ```

4. **Perform matching**:
   ```
   Match each note to corresponding QSO using time/callsign criteria
   ```

5. **Generate output**:
   ```
   Create main_2 file with integrated notes and error reports
   ```

6. **Validate results**:
   ```
   Verify match statistics and review any unmatched entries
   ```

---

**Example Usage:**
```
Please process the .not files in my src_dump directory and merge them with 
/path/to/main_file_cabrillo.log using this complete workflow. Generate 
main_2_file_cabrillo.log with all notes integrated and report matching statistics.
```

**Expected Results:**
- New merged cabrillo file with integrated operator notes
- Complete accountability of all .not entries
- Detailed matching statistics and any error reports
- Preservation of original contest log integrity