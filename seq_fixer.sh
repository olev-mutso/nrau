#!/usr/bin/env bash

# Sequence Number Fixer - Corrects decrements in contest log
# Duplicates are OK, only decrements are errors

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

fix_sequence_numbers() {
    local input_file="$1"
    local output_file="${input_file%.*}_seq_fixed.log"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    log_info "Processing: $input_file"
    log_info "Output: $output_file"
    
    # Track last valid sequence for each mode
    local last_ph_seq=0
    local last_cw_seq=0
    local ph_errors=0
    local cw_errors=0
    local total_qsos=0
    
    # Clear output file
    > "$output_file"
    
    log_info "Analyzing sequence numbers..."
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Copy original line
        echo "$line" >> "$output_file"
        
        # Process QSO lines only
        if [[ "$line" =~ ^QSO: ]]; then
            ((total_qsos++))
            
            # Parse QSO line using awk for proper field extraction
            # QSO:  3626 PH 2026-01-11 0600 ES5G          59  0001 JG     LY2AX         59   001 KN
            local mode=$(echo "$line" | awk '{print $3}')
            local my_seq=$(echo "$line" | awk '{print $8}')
            local callsign=$(echo "$line" | awk '{print $10}')
            
            # Debug first few
            if [[ $total_qsos -le 5 ]]; then
                log_info "DEBUG QSO $total_qsos: mode=$mode, seq=$my_seq, call=$callsign"
            fi
            
            # Remove leading zeros for comparison
            local seq_num=$((10#$my_seq))
            
            # Check sequence by mode
            if [[ "$mode" == "PH" ]]; then
                if [[ $seq_num -lt $last_ph_seq ]]; then
                    # Decrement detected - fix it
                    ((last_ph_seq++))
                    local new_seq=$(printf "%04d" $last_ph_seq)
                    echo "# SEQ $callsign change $my_seq -> $new_seq" >> "$output_file"
                    ((ph_errors++))
                    log_warning "PH: $callsign sequence $my_seq → $new_seq (decrement from $((last_ph_seq-1)))"
                else
                    # Update last valid (if higher)
                    if [[ $seq_num -gt $last_ph_seq ]]; then
                        last_ph_seq=$seq_num
                    fi
                fi
                
            elif [[ "$mode" == "CW" ]]; then
                if [[ $seq_num -lt $last_cw_seq ]]; then
                    # Decrement detected - fix it  
                    ((last_cw_seq++))
                    local new_seq=$(printf "%04d" $last_cw_seq)
                    echo "# SEQ $callsign change $my_seq -> $new_seq" >> "$output_file"
                    ((cw_errors++))
                    log_warning "CW: $callsign sequence $my_seq → $new_seq (decrement from $((last_cw_seq-1)))"
                else
                    # Update last valid (if higher)
                    if [[ $seq_num -gt $last_cw_seq ]]; then
                        last_cw_seq=$seq_num
                    fi
                fi
            fi
            
            # Progress indicator
            if (( total_qsos % 50 == 0 )); then
                printf "\r📊 Processed: %d QSOs (PH: %d, CW: %d)" "$total_qsos" "$last_ph_seq" "$last_cw_seq"
            fi
        fi
        
    done < "$input_file"
    
    echo  # New line after progress
    
    # Summary
    log_success "Processing complete!"
    log_info "📊 Results:"
    log_info "   Total QSOs processed: $total_qsos"
    log_info "   PH sequence errors: $ph_errors"
    log_info "   CW sequence errors: $cw_errors"
    log_info "   Total errors fixed: $((ph_errors + cw_errors))"
    log_info "   Final PH sequence: $last_ph_seq"
    log_info "   Final CW sequence: $last_cw_seq"
    log_info "   Output saved to: $output_file"
    
    if [[ $((ph_errors + cw_errors)) -gt 0 ]]; then
        echo
        log_warning "Sequence corrections made:"
        grep "# SEQ" "$output_file" | head -10
        if [[ $((ph_errors + cw_errors)) -gt 10 ]]; then
            log_info "   ... and $((ph_errors + cw_errors - 10)) more"
        fi
    else
        log_success "🎉 No sequence errors found - all sequences are correct!"
    fi
}

main() {
    local log_file="$1"
    
    if [[ -z "$log_file" ]]; then
        log_error "Please specify a log file to process"
        echo "Usage: $0 LOG_FILE"
        exit 1
    fi
    
    fix_sequence_numbers "$log_file"
}

main "$@"