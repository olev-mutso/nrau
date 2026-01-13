#!/usr/bin/env bash
#
# QRZ.com Callsign Checker - Bash/Curl Version
# ============================================
#
# Pure bash script using curl to check callsigns via QRZ.com XML API
# Requires QRZ.com XML subscription
#
# Usage:
#   ./qrz_checker.sh --callsign LB4UH
#   ./qrz_checker.sh --file callsigns.txt
#   ./qrz_checker.sh --cabrillo main_2_file_cabrillo.log
#
# Environment variables:
#   QRZ_USERNAME - Your QRZ.com username
#   QRZ_PASSWORD - Your QRZ.com password
#

# Auto-fix permissions and line endings on first run
if [[ ! -x "$0" ]]; then
    chmod +x "$0"
    echo "🔧 Made script executable"
fi

set -euo pipefail

# Configuration
QRZ_BASE_URL="https://xmldata.qrz.com/xml/current/"
SESSION_KEY=""
RATE_LIMIT=1
OUTPUT_FILE="qrz_results.csv"
TEMP_DIR="/tmp/qrz_checker_$$"
DEBUG=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_debug() {
    [[ $DEBUG -eq 1 ]] && echo -e "${YELLOW}🐛 DEBUG: $1${NC}" >&2
}

# Help function
show_help() {
    cat << 'EOF'
QRZ.com Callsign Checker - Bash/Curl Version

USAGE:
    ./qrz_checker.sh [OPTIONS]

OPTIONS:
    --callsign CALL     Check single callsign
    --file FILE         Check callsigns from file (one per line)
    --cabrillo FILE     Extract and check callsigns from cabrillo log
    --username USER     QRZ.com username (or set QRZ_USERNAME)
    --password PASS     QRZ.com password (or set QRZ_PASSWORD)
    --output FILE       Output CSV file (default: qrz_results.csv)
    --delay SECONDS     Delay between requests (default: 1)
    --debug             Enable debug output
    --help              Show this help

EXAMPLES:
    # Set credentials
    export QRZ_USERNAME="your_username"
    export QRZ_PASSWORD="your_password"
    
    # Check single callsign
    ./qrz_checker.sh --callsign LB4UH
    
    # Check callsigns from file
    ./qrz_checker.sh --file callsigns.txt
    
    # Check all callsigns from cabrillo log
    ./qrz_checker.sh --cabrillo main_2_file_cabrillo.log
    
    # Custom output and rate limiting
    ./qrz_checker.sh --cabrillo contest.log --output results.csv --delay 0.5

REQUIREMENTS:
    - bash 4.0+
    - curl
    - QRZ.com XML subscription
    - xmllint (usually part of libxml2-utils)

EOF
}

# XML parsing helper
parse_xml() {
    local xml_file="$1"
    local xpath="$2"
    
    if command -v xmllint >/dev/null 2>&1; then
        xmllint --xpath "$xpath" "$xml_file" 2>/dev/null | sed 's/<[^>]*>//g' || echo ""
    else
        # Fallback to grep/sed for basic parsing
        grep -o "<${xpath#//}>[^<]*</${xpath#//}>" "$xml_file" 2>/dev/null | sed 's/<[^>]*>//g' || echo ""
    fi
}

# Login to QRZ and get session key
qrz_login() {
    local username="${QRZ_USERNAME:-}"
    local password="${QRZ_PASSWORD:-}"
    
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "QRZ.com credentials required!"
        log_info "Set QRZ_USERNAME and QRZ_PASSWORD environment variables"
        log_info "Example: export QRZ_USERNAME=your_username"
        log_info "         export QRZ_PASSWORD=your_password"
        return 1
    fi
    
    log_info "Logging into QRZ.com..."
    
    local response_file="$TEMP_DIR/login_response.xml"
    
    if ! curl -s --max-time 30 \
        --data-urlencode "username=$username" \
        --data-urlencode "password=$password" \
        --data-urlencode "agent=nrau_contest_checker_bash_v1.0" \
        "$QRZ_BASE_URL" > "$response_file"; then
        log_error "Failed to connect to QRZ.com"
        return 1
    fi
    
    log_debug "Login response saved to $response_file"
    
    # Parse session key
    SESSION_KEY=$(parse_xml "$response_file" "//Key")
    
    if [[ -n "$SESSION_KEY" ]]; then
        log_success "Logged into QRZ.com successfully"
        log_debug "Session key: $SESSION_KEY"
        return 0
    else
        local error_msg=$(parse_xml "$response_file" "//Error")
        log_error "QRZ login failed: ${error_msg:-Unknown error}"
        return 1
    fi
}

# Lookup a single callsign
lookup_callsign() {
    local callsign="$1"
    local clean_call
    
    # Clean callsign (remove /P, /M, etc.)
    clean_call=$(echo "$callsign" | tr '[:lower:]' '[:upper:]' | sed 's|/[A-Z0-9]*$||')
    
    log_debug "Looking up callsign: $clean_call"
    
    if [[ -z "$SESSION_KEY" ]]; then
        if ! qrz_login; then
            return 1
        fi
    fi
    
    local response_file="$TEMP_DIR/lookup_${clean_call}.xml"
    
    if ! curl -s --max-time 30 \
        --data-urlencode "s=$SESSION_KEY" \
        --data-urlencode "callsign=$clean_call" \
        "$QRZ_BASE_URL" > "$response_file"; then
        log_error "Failed to lookup $clean_call"
        return 1
    fi
    
    log_debug "Lookup response for $clean_call saved to $response_file"
    
    # Check for session timeout
    local session_error=$(parse_xml "$response_file" "//Error")
    if [[ "$session_error" == *"Session Timeout"* ]]; then
        log_warning "Session expired, re-authenticating..."
        SESSION_KEY=""
        if qrz_login; then
            lookup_callsign "$callsign"  # Retry
            return $?
        else
            return 1
        fi
    fi
    
    # Parse results
    local found_call=$(parse_xml "$response_file" "//call")
    
    if [[ -n "$found_call" ]]; then
        local name=$(parse_xml "$response_file" "//fname")
        local country=$(parse_xml "$response_file" "//country")
        local dxcc=$(parse_xml "$response_file" "//dxcc")
        local state=$(parse_xml "$response_file" "//state")
        local grid=$(parse_xml "$response_file" "//grid")
        local addr2=$(parse_xml "$response_file" "//addr2")
        local expires=$(parse_xml "$response_file" "//expdate")
        local license_class=$(parse_xml "$response_file" "//class")
        
        # Output CSV line
        echo "$clean_call,true,$name,$country,$dxcc,$state,$grid,$addr2,$expires,$license_class," >> "$OUTPUT_FILE"
        
        log_success "$clean_call: $name in $country"
        return 0
    else
        local error_msg="${session_error:-Not found}"
        echo "$clean_call,false,,,,,,,,$error_msg" >> "$OUTPUT_FILE"
        log_error "$clean_call: $error_msg"
        return 1
    fi
}

# Extract callsigns from cabrillo log
extract_from_cabrillo() {
    local cabrillo_file="$1"
    local callsigns_file="$TEMP_DIR/callsigns.txt"
    
    if [[ ! -f "$cabrillo_file" ]]; then
        log_error "Cabrillo file not found: $cabrillo_file"
        return 1
    fi
    
    log_info "Extracting callsigns from $cabrillo_file..."
    
    # Extract callsigns from QSO lines (field 9, 0-indexed)
    grep '^QSO:' "$cabrillo_file" | \
        awk '{print $10}' | \
        sort -u > "$callsigns_file"
    
    local count=$(wc -l < "$callsigns_file")
    log_info "Found $count unique callsigns"
    
    echo "$callsigns_file"
}

# Initialize CSV output
init_csv() {
    echo "callsign,found,name,country,dxcc,state,grid,addr2,expires,class,error" > "$OUTPUT_FILE"
}

# Process callsign list
process_callsigns() {
    local callsigns_file="$1"
    local total_count=0
    local found_count=0
    local not_found_count=0
    
    if [[ ! -f "$callsigns_file" ]]; then
        log_error "Callsigns file not found: $callsigns_file"
        return 1
    fi
    
    total_count=$(wc -l < "$callsigns_file")
    log_info "Processing $total_count callsigns..."
    
    local counter=1
    while IFS= read -r callsign || [[ -n "$callsign" ]]; do
        [[ -z "$callsign" ]] && continue
        
        echo -n "🔍 Checking $counter/$total_count: $callsign"
        
        if lookup_callsign "$callsign"; then
            ((found_count++))
        else
            ((not_found_count++))
        fi
        
        # Rate limiting
        if [[ $counter -lt $total_count ]]; then
            sleep "$RATE_LIMIT"
        fi
        
        ((counter++))
    done < "$callsigns_file"
    
    # Summary
    local found_pct=$(( found_count * 100 / total_count ))
    local not_found_pct=$(( not_found_count * 100 / total_count ))
    
    echo
    log_info "📈 SUMMARY:"
    log_info "   Total checked: $total_count"
    log_success "   Found: $found_count ($found_pct%)"
    log_error "   Not found: $not_found_count ($not_found_pct%)"
    log_info "   Results saved to: $OUTPUT_FILE"
    
    # Show not found callsigns
    if [[ $not_found_count -gt 0 ]]; then
        echo
        log_warning "❌ NOT FOUND CALLSIGNS:"
        awk -F, '$2=="false" {printf "   %s: %s\n", $1, $11}' "$OUTPUT_FILE"
    fi
}

# Main function
main() {
    local callsign=""
    local file=""
    local cabrillo=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --callsign)
                callsign="$2"
                shift 2
                ;;
            --file)
                file="$2"
                shift 2
                ;;
            --cabrillo)
                cabrillo="$2"
                shift 2
                ;;
            --username)
                QRZ_USERNAME="$2"
                shift 2
                ;;
            --password)
                QRZ_PASSWORD="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --delay)
                RATE_LIMIT="$2"
                shift 2
                ;;
            --debug)
                DEBUG=1
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    # Initialize CSV
    init_csv
    
    # Process based on input type
    if [[ -n "$callsign" ]]; then
        log_info "Checking single callsign: $callsign"
        if ! qrz_login; then
            exit 1
        fi
        lookup_callsign "$callsign"
        
    elif [[ -n "$file" ]]; then
        log_info "Processing callsigns from file: $file"
        if ! qrz_login; then
            exit 1
        fi
        process_callsigns "$file"
        
    elif [[ -n "$cabrillo" ]]; then
        log_info "Processing cabrillo log: $cabrillo"
        if ! qrz_login; then
            exit 1
        fi
        callsigns_file=$(extract_from_cabrillo "$cabrillo")
        process_callsigns "$callsigns_file"
        
    else
        log_error "Please specify --callsign, --file, or --cabrillo"
        show_help
        exit 1
    fi
}

# Run main function with all arguments
main "$@"