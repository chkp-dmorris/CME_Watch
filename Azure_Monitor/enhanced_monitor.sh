#!/bin/bash

# Enhanced System and Log Monitor Script
# Monitors CPU, Memory, and Check Point CPM logs for errors and issues
# Usage: ./enhanced_monitor.sh <log_file> [interval_seconds] [cpm_log_directory]

# Check if log file is provided
if [[ -z "$1" ]]; then
    echo "Usage: $0 <log_file> [interval_seconds] [cpm_log_directory]"
    echo "Example: $0 cme_monitor.txt 5 /var/log/opt/CPsuite-R82/fw1/log"
    echo ""
    echo "For easier management, use the control script instead:"
    echo "  ./enhanced_control.sh start     # Start with default settings"
    echo "  ./enhanced_control.sh status    # Check status"
    echo "  ./enhanced_control.sh stop      # Stop monitoring"
    echo "  ./enhanced_control.sh logs      # View log output" 
    echo "  ./enhanced_control.sh alerts    # Show alerts only"
    exit 1
fi

LOG_FILE="$1"
INTERVAL=${2:-5}
CPM_LOG_DIR=${3:-"/var/log/opt/CPsuite-R82/fw1/log"}

# Cloud Proxy log patterns to monitor for issues
declare -A LOG_PATTERNS=(
    ["ERROR"]="ERROR"
    ["FATAL"]="FATAL"
    ["EXCEPTION"]="Exception|exception"
    ["OUT_OF_MEMORY"]="OutOfMemory|Out of memory|OOM"
    ["FAILED_TO_SEND_LOG"]="FailedToSendLogException|Failed to send logs|SendLog failed"
    ["TIMEOUT"]="timeout|Timeout|TIMEOUT"
    ["CONNECTION_FAIL"]="connection.*fail|Connection.*fail|failed.*connect|Connection refused|Network unreachable"
    ["SESSION_ISSUES"]="session.*expired|Session.*expired|login.*failed|Authentication failed"
    ["CLOUD_API_ERRORS"]="API.*error|HTTP.*[45][0-9]{2}|Request.*failed|Response.*error"
    ["SCAN_NOT_IDENTICAL"]="scan is not identical to previous scan"
    ["AUTOUPDATE_RESTART"]="starting up after autoupdate installation"
    ["SYSTEM_RESTART"]="=== starting up ==="
)

# Memory thresholds (percentages)
CPU_WARNING_THRESHOLD=80
CPU_CRITICAL_THRESHOLD=90
MEMORY_WARNING_THRESHOLD=85
MEMORY_CRITICAL_THRESHOLD=95
DISK_WARNING_THRESHOLD=85
DISK_CRITICAL_THRESHOLD=95

# Function to get CPU usage
get_cpu_usage() {
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    if [[ -z "$cpu_usage" ]]; then
        cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f", usage}')
    fi
    echo "$cpu_usage"
}

# Function to get memory usage
get_memory_usage() {
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_used=$((mem_total - mem_available))
    mem_usage_percent=$(awk "BEGIN {printf \"%.1f\", ($mem_used/$mem_total)*100}")
    
    mem_total_mb=$((mem_total / 1024))
    mem_used_mb=$((mem_used / 1024))
    mem_available_mb=$((mem_available / 1024))
    
    echo "$mem_usage_percent $mem_used_mb $mem_total_mb $mem_available_mb"
}

# Function to get system load average
get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//'
}

# Function to check system resource alerts
check_system_alerts() {
    local cpu_usage="$1"
    local mem_usage="$2"
    local disk_usage="$3"
    local alerts=""
    
    # CPU alerts
    if (( $(echo "$cpu_usage > $CPU_CRITICAL_THRESHOLD" | bc -l) )); then
        alerts+="[CRITICAL] CPU usage at ${cpu_usage}% (>${CPU_CRITICAL_THRESHOLD}%); "
    elif (( $(echo "$cpu_usage > $CPU_WARNING_THRESHOLD" | bc -l) )); then
        alerts+="[WARNING] CPU usage at ${cpu_usage}% (>${CPU_WARNING_THRESHOLD}%); "
    fi
    
    # Memory alerts
    if (( $(echo "$mem_usage > $MEMORY_CRITICAL_THRESHOLD" | bc -l) )); then
        alerts+="[CRITICAL] Memory usage at ${mem_usage}% (>${MEMORY_CRITICAL_THRESHOLD}%); "
    elif (( $(echo "$mem_usage > $MEMORY_WARNING_THRESHOLD" | bc -l) )); then
        alerts+="[WARNING] Memory usage at ${mem_usage}% (>${MEMORY_WARNING_THRESHOLD}%); "
    fi
    
    # Disk alerts
    if (( $(echo "$disk_usage > $DISK_CRITICAL_THRESHOLD" | bc -l) )); then
        alerts+="[CRITICAL] Disk usage at ${disk_usage}% (>${DISK_CRITICAL_THRESHOLD}%); "
    elif (( $(echo "$disk_usage > $DISK_WARNING_THRESHOLD" | bc -l) )); then
        alerts+="[WARNING] Disk usage at ${disk_usage}% (>${DISK_WARNING_THRESHOLD}%); "
    fi
    
    echo "$alerts"
}

# Function to check Cloud Proxy logs for issues
check_cpm_logs() {
    local log_issues=""
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if Cloud Proxy log directory exists
    if [[ ! -d "$CPM_LOG_DIR" ]]; then
        echo "[WARNING] Cloud Proxy log directory not found: $CPM_LOG_DIR"
        return
    fi
    
    # Find the most recent Cloud Proxy log file - try multiple patterns
    local cpm_log=""
    
    # Try different log file patterns
    for pattern in "cloud_proxy.elg*" "cpm.elg*" "*.elg" "*.log"; do
        cpm_log=$(find "$CPM_LOG_DIR" -name "$pattern" -type f 2>/dev/null | head -1)
        if [[ -n "$cpm_log" && -f "$cpm_log" ]]; then
            break
        fi
    done
    
    if [[ -z "$cpm_log" || ! -f "$cpm_log" ]]; then
        echo "[WARNING] No log files found in $CPM_LOG_DIR"
        echo "[INFO] Searched for patterns: cloud_proxy.elg*, cpm.elg*, *.elg, *.log"
        echo "[INFO] Available files in $CPM_LOG_DIR:"
        ls -la "$CPM_LOG_DIR" 2>/dev/null | head -10
        echo "[INFO] Looking for .elg files in common locations..."
        find /opt -name "*.elg" -type f 2>/dev/null | head -5
        find /var/log -name "*.elg" -type f 2>/dev/null | head -5
        return
    fi
    
    echo "[INFO] Using log file: $cpm_log"
    
    # Check for recent entries (last 200 lines to ensure we catch recent events)
    local recent_logs=$(tail -n 200 "$cpm_log")
    
    # Check each pattern
    for pattern_name in "${!LOG_PATTERNS[@]}"; do
        local pattern="${LOG_PATTERNS[$pattern_name]}"
        local matches=$(echo "$recent_logs" | grep -E "$pattern" 2>/dev/null | wc -l)
        
        if [[ $matches -gt 0 ]]; then
            case "$pattern_name" in
                "ERROR"|"FATAL"|"EXCEPTION"|"OUT_OF_MEMORY"|"FAILED_TO_SEND_LOG")
                    log_issues+="[CRITICAL] CloudProxy $pattern_name detected ($matches occurrences); "
                    ;;
                "CONNECTION_FAIL"|"CLOUD_API_ERRORS"|"TIMEOUT")
                    log_issues+="[WARNING] CloudProxy $pattern_name detected ($matches occurrences); "
                    ;;
                "AUTOUPDATE_RESTART"|"SYSTEM_RESTART")
                    log_issues+="[INFO] CloudProxy $pattern_name detected ($matches occurrences); "
                    ;;
                *)
                    log_issues+="[INFO] CloudProxy $pattern_name detected ($matches occurrences); "
                    ;;
            esac
        fi
    done
    
    # Check Azure mapping performance (extract mapping time from logs)
    local mapping_times=$(echo "$recent_logs" | grep -E "Mapping.*finished.*took [0-9]+ seconds" | grep -oE "took [0-9]+ seconds" | grep -oE "[0-9]+")
    if [[ -n "$mapping_times" ]]; then
        local max_time=0
        for time in $mapping_times; do
            if [[ $time -gt $max_time ]]; then
                max_time=$time
            fi
        done
        if [[ $max_time -gt 30 ]]; then
            log_issues+="[WARNING] Slow Azure mapping detected: ${max_time}s (normal: 6-10s); "
        elif [[ $max_time -gt 15 ]]; then
            log_issues+="[INFO] Elevated Azure mapping time: ${max_time}s; "
        fi
    fi
    
    # Check for scan changes (indicates Azure environment changes)
    local scan_changes=$(echo "$recent_logs" | grep -E "scan is not identical to previous scan" | wc -l)
    if [[ $scan_changes -gt 0 ]]; then
        log_issues+="[INFO] Azure environment changes detected: ${scan_changes} scan differences; "
    fi
    
    # Check CPU time deltas for performance issues  
    local high_cpu_deltas=$(echo "$recent_logs" | grep -E "CPU time delta=[0-9]+" | grep -oE "delta=[0-9]+" | grep -oE "[0-9]+" | awk '$1 > 100')
    if [[ -n "$high_cpu_deltas" ]]; then
        local max_delta=$(echo "$high_cpu_deltas" | sort -n | tail -1)
        log_issues+="[WARNING] High CPU processing time: ${max_delta}ms; "
    fi
    
    # Check for repeated failed log sends
    local failed_logs=$(echo "$recent_logs" | grep -E "FailedToSendLogException|Failed to send logs" | wc -l)
    if [[ $failed_logs -gt 3 ]]; then
        log_issues+="[CRITICAL] Multiple log send failures: ${failed_logs} failures; "
    elif [[ $failed_logs -gt 0 ]]; then
        log_issues+="[WARNING] Log send issues: ${failed_logs} failures; "
    fi
    
    # Check for CloudGuard calc_desc events and log them (handle JSON formatting)
    local calc_desc_events=$(echo "$recent_logs" | grep -E "(calc_desc|\"calc_desc\"|'calc_desc')")
    
    if [[ -n "$calc_desc_events" ]]; then
        while IFS= read -r event_line; do
            if [[ -n "$event_line" ]]; then
                log_message "CLOUDGUARD EVENT: $event_line"
                # Extract and analyze specific event types
                if echo "$event_line" | grep -qE "(Mapping took [0-9]+ (seconds?|mins?|minutes?))|(took [0-9]+ (seconds?|mins?|minutes?))"; then
                    # Extract mapping time - handle seconds, minutes, or other units
                    local map_time=$(echo "$event_line" | grep -oE "(Mapping took [0-9]+ [a-z]+)|(took [0-9]+ [a-z]+)" | grep -oE "[0-9]+ [a-z]+")
                    # Extract data center name - handle various bracket types and formats
                    local dc_name=$(echo "$event_line" | grep -oE "(Data Center|datacenter|DC) [\[\(][^]\)]+[\]\)]" | grep -oE "[\[\(][^]\)]+[\]\)]" | tr -d '[]()' | head -1)
                    if [[ -n "$map_time" ]]; then
                        if [[ -n "$dc_name" ]]; then
                            log_message "Data Center mapping time [$dc_name]: ${map_time}"
                        else
                            log_message "Data Center mapping time: ${map_time}"
                        fi
                    fi
                fi
            fi
        done <<< "$calc_desc_events"
    fi
    
    echo "$log_issues"
}

# Function to log message to file only
log_message() {
    echo "$1" >> "$LOG_FILE"
}

# Create log directory if it doesn't exist
LOG_DIR=$(dirname "$LOG_FILE")
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR"
fi

# Initialize log file with header
echo "========================================" > "$LOG_FILE"
echo "Enhanced System & Cloud Proxy Monitor Started: $(date)" >> "$LOG_FILE"
echo "PID: $$" >> "$LOG_FILE"
echo "Log File: $LOG_FILE" >> "$LOG_FILE"
echo "Cloud Proxy Log Directory: $CPM_LOG_DIR" >> "$LOG_FILE"
echo "Update Interval: ${INTERVAL}s" >> "$LOG_FILE"
echo "Thresholds - CPU: W:${CPU_WARNING_THRESHOLD}% C:${CPU_CRITICAL_THRESHOLD}% | Memory: W:${MEMORY_WARNING_THRESHOLD}% C:${MEMORY_CRITICAL_THRESHOLD}% | Disk: W:${DISK_WARNING_THRESHOLD}% C:${DISK_CRITICAL_THRESHOLD}%" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Function to cleanup on exit
cleanup_and_exit() {
    log_message ""
    log_message "========================================="
    log_message "Enhanced monitoring stopped: $(date)"
    log_message "========================================="
    
    # Clean up PID file if it exists
    PID_FILE="${LOG_FILE}.pid"
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
    exit 0
}

# Trap Ctrl+C to exit gracefully
trap cleanup_and_exit INT TERM

# Check if bc is available (needed for calculations)
if ! command -v bc &> /dev/null; then
    log_message "Warning: 'bc' command not found. Some calculations may not work properly."
fi

# Check if we're being called to start in background
if [[ "$1" != "--already-background" ]]; then
    echo "Starting enhanced system and Cloud Proxy log monitor in background..."
    echo "This process will continue running even if SSH session closes."
    
    # Create PID file for process management
    PID_FILE="${LOG_FILE}.pid"
    
    # Start the script in background with nohup to survive session closure
    nohup "$0" --already-background "$LOG_FILE" "$INTERVAL" "$CPM_LOG_DIR" </dev/null >/dev/null 2>&1 &
    BACKGROUND_PID=$!
    
    echo "Background PID: $BACKGROUND_PID"
    echo "$BACKGROUND_PID" > "$PID_FILE"
    echo "PID file: $PID_FILE"
    echo "Log file: $LOG_FILE"
    echo "Cloud Proxy logs: $CPM_LOG_DIR"
    echo ""
    echo "Commands to manage the monitor:"
    echo "  View logs: tail -f $LOG_FILE"
    echo "  Stop monitor: kill $BACKGROUND_PID"
    echo "  Or use: kill \$(cat $PID_FILE)"
    
    exit 0
else
    # We are the background process - shift arguments
    shift  # Remove --already-background flag
    LOG_FILE="$1"
    INTERVAL="$2"
    CPM_LOG_DIR="$3"
    
    # Create PID file
    PID_FILE="${LOG_FILE}.pid"
    echo "$$" > "$PID_FILE"
    
    # Redirect stdout and stderr to prevent any terminal output
    exec 1>/dev/null 2>/dev/null
    
    # Ignore HUP signal (when terminal closes)
    trap '' HUP
fi

# Main monitoring loop
while true; do
    # Get current timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get system metrics
    cpu_usage=$(get_cpu_usage)
    mem_info=($(get_memory_usage))
    mem_usage_percent=${mem_info[0]}
    mem_used_mb=${mem_info[1]}
    mem_total_mb=${mem_info[2]}
    mem_available_mb=${mem_info[3]}
    load_avg=$(get_load_average)
    
    # Get disk usage for root partition
    disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    disk_info=$(df -h / | tail -1 | awk '{printf "%s/%s", $3, $2}')
    
    # Get top processes
    top_cpu=$(ps aux --sort=-%cpu | head -2 | tail -1 | awk '{printf "%s(%.1f%%)", $11, $3}')
    top_mem=$(ps aux --sort=-%mem | head -2 | tail -1 | awk '{printf "%s(%.1f%%)", $11, $4}')
    
    # Check for system alerts
    system_alerts=$(check_system_alerts "$cpu_usage" "$mem_usage_percent" "$disk_usage")
    
    # Check Cloud Proxy logs for issues
    cpm_alerts=$(check_cpm_logs)
    
    # Build output string
    output="[$timestamp] System Status: CPU:${cpu_usage}% | Memory:${mem_usage_percent}%(${mem_used_mb}MB/${mem_total_mb}MB) | Load:$load_avg | Disk:${disk_usage}%($disk_info) | TopCPU:$top_cpu | TopMem:$top_mem"
    
    # Add alerts if any
    if [[ -n "$system_alerts" || -n "$cpm_alerts" ]]; then
        output+="\n[$timestamp] ALERTS: ${system_alerts}${cpm_alerts}"
    fi
    
    # Log the monitoring data
    log_message "$output"
    
    # Wait for the specified interval
    sleep "$INTERVAL"
done