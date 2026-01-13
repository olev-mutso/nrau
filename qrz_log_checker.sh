#!/usr/bin/env bash

# QRZ.com Log Checker - macOS Compatible
# Validates callsigns in cabrillo log and adds ERROR comments for invalid ones

set -euo pipefail

QRZ_BASE_URL="https://xmldata.qrz.com/xml/current/"
SESSION_KEY=""
RATE_LIMIT=1
TEMP_DIR="/tmp/qrz_checker_$$"
DEBUG=0

# Colors for macOS terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TEMP_DIR"

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

parse_xml() {
    local xml_file="$1"
    local tag="$2"
    # macOS-compatible grep and sed
    /usr/bin/grep -o "<${tag}>[^<]*</${tag}>" "$xml_file" 2>/dev/null | /usr/bin/sed "s/<${tag}>//g; s/<\/${tag}>//g" | head -1 || echo ""
}

qrz_login() {
    local username="${QRZ_USERNAME:-}"
    local password="${QRZ_PASSWORD:-}"
    
    if [[ -z "$username" || -z "$password" ]]; then
        log_error "QRZ.com credentials required!"
        log_info "Set QRZ_USERNAME and QRZ_PASSWORD environment variables"
        return 1
    fi
    
    log_info "Logging into QRZ.com..."
    
    local response_file="$TEMP_DIR/login_response.xml"
    
    if ! /usr/bin/curl -s --max-time 30 \
        --data-urlencode "username=$username" \
        --data-urlencode "password=$password" \
        --data-urlencode "agent=nrau_log_checker_macos_v1.0" \
        "$QRZ_BASE_URL" > "$response_file"; then
        log_error "Failed to connect to QRZ.com"
        return 1
    fi
    
    SESSION_KEY=$(parse_xml "$response_file" "Key")
    
    if [[ -n "$SESSION_KEY" ]]; then
        log_success "Logged into QRZ.com successfully"
        return 0
    else
        local error_msg=$(parse_xml "$response_file" "Error")
        log_error "QRZ login failed: ${error_msg:-Unknown error}"
        return 1
    fi
}

check_callsign_exists() {
    local callsign="$1"
    local clean_call
    
    # Clean callsign - remove portable suffixes
    clean_call=$(echo "$callsign" | /usr/bin/tr '[:lower:]' '[:upper:]' | /usr/bin/sed 's|/[A-Z0-9]*$||')
    
    local response_file="$TEMP_DIR/lookup_${clean_call}.xml"
    
    if ! /usr/bin/curl -s --max-time 30 \
        --data-urlencode "s=$SESSION_KEY" \
        --data-urlencode "callsign=$clean_call" \
        "$QRZ_BASE_URL" > "$response_file"; then
        return 1  # Network error = assume invalid
    fi
    
    local found_call=$(parse_xml "$response_file" "call")
    
    if [[ -n "$found_call" ]]; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}

process_log_file() {
    local input_file="$1"
    local output_file="${input_file%.*}_verified.log"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    log_info "Processing log file: $input_file"
    log_info "Output will be saved to: $output_file"
    
    # Login first
    if ! qrz_login; then
        return 1
    fi
    
    local total_qsos=0
    local invalid_callsigns=0
    local processed_qsos=0
    
    # Count total QSOs for progress (macOS wc)
    total_qsos=$(/usr/bin/grep -c '^QSO:' "$input_file" 2>/dev/null || echo "0")
    log_info "Found $total_qsos QSO lines to process"
    
    # Process file line by line - create temporary file with Unix line endings
    local temp_input="$TEMP_DIR/input_clean.log"
    /usr/bin/tr -d '\r' < "$input_file" > "$temp_input"
    
    # Clear output file
    > "$output_file"
    
    while IFS= read -r line || [[ -n "$line" ]]; do        
        # Copy the original line
        echo "$line" >> "$output_file"
        
        # Process QSO lines
        if [[ "$line" =~ ^QSO: ]]; then
            ((processed_qsos++))
            
            # Extract callsign (field 10, 0-indexed) - use awk
            local callsign=$(echo "$line" | /usr/bin/awk '{print $10}')
            
            if [[ -n "$callsign" ]]; then
                printf "\r🔍 Checking %d/%d: %-12s" "$processed_qsos" "$total_qsos" "$callsign"
                
                # Check if callsign exists
                if ! check_callsign_exists "$callsign"; then
                    echo "# ERROR: $callsign can't be found on qrz" >> "$output_file"
                    ((invalid_callsigns++))
                fi
                
                # Rate limiting
                /bin/sleep "$RATE_LIMIT"
            fi
        fi
        
    done < "$temp_input"
    
    echo  # New line after progress
    
    log_success "Processing complete!"
    log_info "📊 Results:"
    log_info "   Total QSOs: $total_qsos"
    if [[ $invalid_callsigns -gt 0 ]]; then
        log_error "   Invalid callsigns: $invalid_callsigns"
    else
        log_success "   Invalid callsigns: $invalid_callsigns"
    fi
    log_success "   Valid callsigns: $((total_qsos - invalid_callsigns))"
    log_info "   Output saved to: $output_file"
    
    if [[ $invalid_callsigns -gt 0 ]]; then
        log_error "⚠️  Found $invalid_callsigns invalid callsigns"
        echo
        log_info "Invalid callsigns found:"
        /usr/bin/grep "# ERROR:" "$output_file" | /usr/bin/sed 's/^# ERROR: /   /'
    else
        log_success "🎉 All callsigns are valid!"
    fi
}

show_help() {
    cat << 'HELP_EOF'
QRZ.com Log Checker - macOS Version

USAGE:
    ./qrz_log_checker.sh LOG_FILE [OPTIONS]

OPTIONS:
    --delay SECONDS     Delay between requests (default: 1)
    --debug             Enable debug output  
    --help              Show this help

EXAMPLES:
    # Set credentials
    export QRZ_USERNAME="your_username"
    export QRZ_PASSWORD="your_password"
    
    # Check log file
    ./qrz_log_checker.sh main_2_file_cabrillo.log
    
    # Faster checking (be careful with rate limits)
    ./qrz_log_checker.sh contest.log --delay 0.5

OUTPUT:
    Creates LOG_FILE_verified.log with:
    - All original content
    - "# ERROR: CALLSIGN can't be found on qrz" comments after invalid QSOs

HELP_EOF
}

main() {
    local log_file=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
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
            -*)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                log_file="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$log_file" ]]; then
        echo "Please specify a log file to process"
        echo ""
        echo "Available log files:"
        echo "  - main_file_cabrillo.log (original)" 
        echo "  - main_2_file_cabrillo.log (with notes)"
        echo ""
        show_help
        exit 1
    fi
    
    process_log_file "$log_file"
}

main "$@"
