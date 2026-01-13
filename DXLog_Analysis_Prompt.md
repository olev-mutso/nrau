# DXLog Ham Radio Contest Log Analysis - Complete Workflow

## Overview
This prompt guides the analysis of a DXLog contest log file to extract comprehensive statistics, identify logging errors, and generate activity graphs for all bands and modes.

## Input File
- **Format**: DXLog contest log (.log file)
- **Structure**: ADIF-like format with QSO lines
- **Example QSO line**: `QSO:  3626 PH 2026-01-11 0600 ES5G          59  0001 JG     LY2AX         59   001 KN`

## Required Analysis Tasks

### 1. Initial File Analysis
- Read the source log file
- Identify contest details (callsign, contest name, date)
- Count total QSOs by mode (SSB/PH and CW)
- Identify all frequencies used
- Determine band classifications (80m, 40m, etc.)

### 2. Mode and Band Separation
Create separate files for each mode:
- **SSB contacts file**: Extract all PH mode QSOs
- **CW contacts file**: Extract all CW mode QSOs

### 3. Contact Statistics
For each mode, provide:
- Total contact count
- Band breakdown (80m vs 40m vs other bands)
- Frequency usage analysis
- Time period analysis

### 4. Sequence Number Error Analysis
For both SSB and CW modes:
- **Duplicate Numbers**: Find sequence numbers used multiple times
- **Missing Numbers**: Identify gaps in sequence (e.g., 005, 007 - missing 006)
- **Out-of-sequence**: Numbers appearing chronologically out of order
- Calculate error rates and generate error summary files

### 5. Activity Graphs Generation
Create time-based activity analysis for:

#### A. 80m SSB Activity Graph
- Extract QSOs on 80m frequencies (typically 3.5-3.8 MHz)
- Group by 10-minute time intervals
- Show contact count per interval
- Include ASCII bar graph visualization
- Calculate peak periods and rates

#### B. 40m SSB Activity Graph  
- Extract QSOs on 40m frequencies (typically 7.0-7.3 MHz)
- Group by 10-minute time intervals
- Show contact count per interval
- Include ASCII bar graph visualization
- Analyze band coordination with 80m

#### C. 80m CW Activity Graph
- Extract CW QSOs on 80m frequencies
- Group by 10-minute time intervals
- Show contact count per interval
- Include ASCII bar graph visualization
- Identify frequency usage patterns

#### D. 40m CW Activity Graph
- Extract CW QSOs on 40m frequencies  
- Group by 10-minute time intervals
- Show contact count per interval
- Include ASCII bar graph visualization
- Analyze coordination with 80m CW

#### E. Combined Activity Graph
- Show complete contest timeline
- Separate SSB and CW periods
- Identify break periods
- Compare mode efficiency
- Overall contest strategy analysis

### 6. Error Summary Reports
Generate detailed error analysis files:
- **SSB Error Summary**: List all duplicates, gaps, error rates
- **CW Error Summary**: List all duplicates, gaps, error rates
- Include recommendations for logging improvements

### 7. Statistical Analysis
Provide comprehensive statistics:
- Contact rates per hour for each mode/band combination
- Peak activity periods
- Band coordination effectiveness
- Mode efficiency comparison
- Contest strategy assessment

## Expected Output Files

1. `{CALLSIGN}_SSB_contacts.log` - All SSB QSOs
2. `{CALLSIGN}_CW_contacts.log` - All CW QSOs  
3. `{CALLSIGN}_SSB_error_summary.txt` - SSB logging errors
4. `{CALLSIGN}_CW_error_summary.txt` - CW logging errors
5. `{CALLSIGN}_80m_SSB_activity_graph.txt` - 80m SSB timeline
6. `{CALLSIGN}_40m_SSB_activity_graph.txt` - 40m SSB timeline
7. `{CALLSIGN}_80m_CW_activity_graph.txt` - 80m CW timeline
8. `{CALLSIGN}_40m_CW_activity_graph.txt` - 40m CW timeline
9. `{CALLSIGN}_MIXED_activity_graph.txt` - Complete contest overview

## Analysis Questions to Answer

### Basic Counts
- How many SSB contacts total?
- How many CW contacts total?
- What bands were used?
- What was the operating time period?

### Error Analysis  
- How many duplicate sequence numbers in each mode?
- What sequence numbers are missing?
- What is the error rate for each mode?
- Which mode had better logging discipline?

### Activity Patterns
- When were the peak activity periods?
- How effective was band coordination?
- What was the contact rate for each mode?
- How long were break periods between modes?

### Strategic Assessment
- Was the contest strategy effective?
- How did mode efficiency compare?
- What improvements could be made?

## Technical Requirements
- Use grep, awk, and text processing tools for efficiency
- Generate ASCII bar graphs for visual representation
- Calculate precise time intervals (10-minute periods)
- Identify frequency ranges automatically
- Handle multiple frequencies per band
- Process ADIF-style log format correctly

## Success Criteria
The analysis is complete when:
1. All files are separated correctly by mode
2. Error analysis identifies all logging issues
3. Activity graphs show clear time-based patterns
4. Statistics provide actionable insights
5. Contest strategy assessment is comprehensive
6. All output files are properly formatted and documented

## Usage Instructions
1. Provide the path to the source DXLog file
2. Specify any contest-specific requirements
3. The analysis will automatically process all aspects
4. Review generated files for insights and recommendations

---

**Example Usage:**
```
Please analyze my DXLog contest file at `/path/to/ES5G_2026_NRAU_BALTIC_M2_CW_80A.log` 
using this complete workflow to generate all separation files, error reports, and activity graphs.
```