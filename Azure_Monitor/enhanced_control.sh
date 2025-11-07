#!/bin/bash

# Enhanced System and CPM Log Monitor Management Script
# Helper script to start, stop, and check status of the enhanced monitoring

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
MONITOR_SCRIPT="$SCRIPT_DIR/enhanced_monitor.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    cat << 'EOF'
Enhanced Monitoring Control Script

USAGE:
    enhanced_control.sh <command> [log_file]

COMMANDS:
    start [log_file]    - Start monitoring daemon
    stop [log_file]     - Stop monitoring daemon  
    restart [log_file]  - Restart monitoring daemon
    status [log_file]   - Show daemon status
    logs [log_file]     - Show recent log entries
    alerts [log_file]   - Show recent alerts/issues only
    help                - Show this help message

PARAMETERS:
    log_file           - Monitor log file name
                        Default: cme_monitor.txt (if not specified)
                        Use custom names for multiple monitors

EXAMPLES:
    ./enhanced_control.sh start                    # Uses cme_monitor.txt
    ./enhanced_control.sh start custom_log.txt     # Uses custom_log.txt
    ./enhanced_control.sh status                   # Status of cme_monitor.txt
    ./enhanced_control.sh stop L5.txt              # Stop specific monitor
EOF
}



get_pid_from_file() {
    local log_file="$1"
    local pid_file="${log_file}.pid"
    
    if [[ -f "$pid_file" ]]; then
        cat "$pid_file"
    else
        echo ""
    fi
}

is_process_running() {
    local pid="$1"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

start_monitor() {
    local log_file="$2"
    local interval="${3:-5}"
    local cpm_log_dir="${4:-/var/log/opt/CPsuite-R82/fw1/log}"
    
    # Use default filename if none specified
    if [[ -z "$log_file" ]]; then
        log_file="cme_monitor.txt"
        echo -e "${BLUE}No log file specified, using default: $log_file${NC}"
    fi
    
    local pid_file="${log_file}.pid"
    
    # Check if already running
    local existing_pid=$(get_pid_from_file "$log_file")
    if is_process_running "$existing_pid"; then
        echo -e "${YELLOW}Enhanced monitor is already running with PID: $existing_pid${NC}"
        echo -e "Log file: $log_file"
        echo -e "Use '$0 stop $log_file' to stop it first"
        exit 1
    fi
    
    # Clean up stale PID file
    if [[ -f "$pid_file" ]]; then
        rm -f "$pid_file"
    fi
    
    echo -e "${BLUE}Starting enhanced system & Cloud Proxy log monitor...${NC}"
    "$MONITOR_SCRIPT" "$log_file" "$interval" "$cpm_log_dir"
    
    sleep 2  # Give it time to start
    
    local new_pid=$(get_pid_from_file "$log_file")
    if is_process_running "$new_pid"; then
        echo -e "${GREEN}✓ Enhanced monitor started successfully${NC}"
        echo -e "PID: $new_pid"
        echo -e "Log file: $log_file"
        echo -e "Interval: ${interval}s"
        echo -e "Cloud Proxy logs: $cpm_log_dir"
        echo -e ""
        echo -e "${YELLOW}Monitor Features:${NC}"
        echo -e "• System resources (CPU, Memory, Disk, Load)"
        echo -e "• Cloud Proxy log analysis for errors and performance issues"
        echo -e "• Azure mapping performance monitoring (mapping times)"
        echo -e "• CloudGuard log forwarding failure detection"
        echo -e "• Azure environment change detection (scan differences)"
        echo -e "• CPU processing time analysis"
        echo -e "• System restart and autoupdate detection"
        echo -e "• Monitors: cloud_proxy.elg* files"
        echo -e "• Configurable alert thresholds"
    else
        echo -e "${RED}✗ Failed to start enhanced monitor${NC}"
        exit 1
    fi
}

# Function to create archive with all relevant logs
create_log_archive() {
    local monitor_log="$1"
    shift  # Remove first argument, rest are additional monitor logs
    local additional_logs=("$@")
    
    local date_stamp=$(date +"%Y%m%d_%H%M%S")
    local archive_name="cme_monitor_${date_stamp}.tar.gz"
    
    echo -e "${BLUE}Creating log archive: $archive_name${NC}"
    
    # Create temporary directory for collecting files
    local temp_dir="/tmp/cme_archive_$$"
    mkdir -p "$temp_dir"
    
    # Copy primary monitor log file if it exists
    if [[ -f "$monitor_log" ]]; then
        echo -e "${GREEN}Adding monitor log: $monitor_log${NC}"
        cp "$monitor_log" "$temp_dir/"
    fi
    
    # Copy any additional monitor log files
    for extra_log in "${additional_logs[@]}"; do
        if [[ -f "$extra_log" && "$extra_log" != "$monitor_log" ]]; then
            echo -e "${GREEN}Adding additional monitor log: $extra_log${NC}"
            cp "$extra_log" "$temp_dir/"
        fi
    done
    
    # Find and copy ONLY cloud_proxy.elg files (flatten structure)
    local cp_logs=($(find /var/log -name "cloud_proxy.elg" -type f 2>/dev/null))
    cp_logs+=($(find /opt -name "cloud_proxy.elg" -type f 2>/dev/null))
    cp_logs+=($(find /home -name "cloud_proxy.elg" -type f 2>/dev/null))
    
    local cp_count=0
    for cp_log in "${cp_logs[@]}"; do
        if [[ -f "$cp_log" ]]; then
            echo -e "${GREEN}Adding Cloud Proxy log: $cp_log${NC}"
            # Copy directly to temp_dir without directory structure
            if [[ $cp_count -eq 0 ]]; then
                cp "$cp_log" "$temp_dir/cloud_proxy.elg"
            else
                # If multiple files, add a number suffix
                cp "$cp_log" "$temp_dir/cloud_proxy_${cp_count}.elg"
            fi
            ((cp_count++))
        fi
    done
    
    # Generate cpinfo output
    echo -e "${GREEN}Generating cpinfo output...${NC}"
    if command -v cpinfo >/dev/null 2>&1; then
        cpinfo -y all > "$temp_dir/cpinfo_output.txt" 2>&1
        echo -e "${GREEN}Added cpinfo output: cpinfo_output.txt${NC}"
    else
        echo -e "${YELLOW}cpinfo command not found, skipping...${NC}"
        echo "cpinfo command not available on this system" > "$temp_dir/cpinfo_not_available.txt"
    fi
    
    # Create the tar archive
    if [[ -d "$temp_dir" ]]; then
        cd "$temp_dir"
        tar -czf "../$archive_name" .
        cd - > /dev/null
        
        # Move archive to current directory
        if [[ -f "/tmp/$archive_name" ]]; then
            mv "/tmp/$archive_name" "./"
            echo -e "${GREEN}✓ Archive created: ./$archive_name${NC}"
            
            # Show archive contents
            echo -e "${BLUE}Archive contents:${NC}"
            tar -tzf "$archive_name" | head -20
            
            local file_count=$(tar -tzf "$archive_name" | wc -l)
            echo -e "${YELLOW}Total files: $file_count${NC}"
        else
            echo -e "${RED}✗ Failed to create archive${NC}"
        fi
    fi
    
    # Clean up temporary directory
    rm -rf "$temp_dir"
}

stop_monitor() {
    local log_file="$2"
    
    # Use default filename if none specified
    if [[ -z "$log_file" ]]; then
        log_file="cme_monitor.txt"
        echo -e "${BLUE}No log file specified, trying to stop default: $log_file${NC}"
        
        # Check if default monitor is running
        local pid=$(get_pid_from_file "$log_file")
        if [[ -n "$pid" ]] && is_process_running "$pid"; then
            # Default monitor is running, stop it
            echo -e "${BLUE}Stopping enhanced monitor (PID: $pid)...${NC}"
            kill "$pid"
            
            # Wait for process to stop
            local count=0
            while is_process_running "$pid" && [[ $count -lt 10 ]]; do
                sleep 1
                ((count++))
            done
            
            if is_process_running "$pid"; then
                echo -e "${YELLOW}Process didn't stop gracefully, forcing termination...${NC}"
                kill -9 "$pid"
                sleep 1
            fi
            
            if ! is_process_running "$pid"; then
                echo -e "${GREEN}✓ Enhanced monitor stopped successfully${NC}"
                rm -f "${log_file}.pid"
                
                # Create archive with logs
                create_log_archive "$log_file"
            else
                echo -e "${RED}✗ Failed to stop enhanced monitor${NC}"
                exit 1
            fi
            return 0
        else
            echo -e "${YELLOW}Default monitor ($log_file) is not running${NC}"
            echo -e "${BLUE}Checking for other running monitors...${NC}"
        fi
    fi
    
    # If we get here, either specific file given or default not running
    # Try to find and stop all running monitors if no specific file
    if [[ -z "$2" ]]; then
        echo -e "${BLUE}No log file specified, searching for running enhanced monitors...${NC}"
        
        # Find all enhanced monitor processes
        local pids=$(ps aux | grep "[e]nhanced_monitor.sh" | awk '{print $2}')
        
        if [[ -z "$pids" ]]; then
            echo -e "${YELLOW}No running enhanced monitor processes found${NC}"
            exit 1
        fi
        
        echo -e "${BLUE}Found enhanced monitor processes with PIDs: $pids${NC}"
        
        for pid in $pids; do
            echo -e "${BLUE}Stopping monitor (PID: $pid)...${NC}"
            kill "$pid"
            
            # Wait for process to stop
            local count=0
            while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
                sleep 1
                ((count++))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${YELLOW}Process $pid didn't stop gracefully, forcing termination...${NC}"
                kill -9 "$pid"
            fi
            
            if ! kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}✓ Monitor (PID: $pid) stopped successfully${NC}"
            else
                echo -e "${RED}✗ Failed to stop monitor (PID: $pid)${NC}"
            fi
        done
        
        # Clean up any orphaned PID files
        echo -e "${BLUE}Cleaning up PID files...${NC}"
        find /var/log /tmp /home -name "*.pid" -exec grep -l "enhanced_monitor\|cloudproxy_monitor" {} \; 2>/dev/null | while read pidfile; do
            local pid_in_file=$(cat "$pidfile" 2>/dev/null)
            if [[ -n "$pid_in_file" ]] && ! kill -0 "$pid_in_file" 2>/dev/null; then
                echo -e "${YELLOW}Removing stale PID file: $pidfile${NC}"
                rm -f "$pidfile"
            fi
        done
        
        # Find and archive only the monitor log files that were actually running
        echo -e "${BLUE}Creating log archive for stopped monitors...${NC}"
        
        # Find ONLY the log files that were associated with the stopped PIDs
        local running_monitor_logs=()
        for stopped_pid in $pids; do
            # Look for the PID file that matches this process
            for pidfile in $(find /var/log /tmp /home . -name "*.pid" 2>/dev/null); do
                if [[ -f "$pidfile" ]]; then
                    local pid_in_file=$(cat "$pidfile" 2>/dev/null)
                    if [[ "$pid_in_file" == "$stopped_pid" ]]; then
                        local associated_log="${pidfile%.pid}"
                        if [[ -f "$associated_log" ]]; then
                            running_monitor_logs+=("$associated_log")
                            echo -e "${GREEN}Found log file for PID $stopped_pid: $associated_log${NC}"
                        fi
                        break
                    fi
                fi
            done
        done
        
        # Create archive with only the logs from running monitors
        if [[ ${#running_monitor_logs[@]} -gt 0 ]]; then
            echo -e "${GREEN}Archiving ${#running_monitor_logs[@]} active monitor log file(s)${NC}"
            create_log_archive "${running_monitor_logs[0]}" "${running_monitor_logs[@]}"
        else
            echo -e "${YELLOW}No active monitor log files found to archive${NC}"
            create_log_archive ""
        fi
        
        return 0
    fi
    
    local pid_file="${log_file}.pid"
    
    local pid=$(get_pid_from_file "$log_file")
    
    if [[ -z "$pid" ]]; then
        echo -e "${YELLOW}No PID file found for $log_file${NC}"
        exit 1
    fi
    
    if is_process_running "$pid"; then
        echo -e "${BLUE}Stopping enhanced monitor (PID: $pid)...${NC}"
        kill "$pid"
        
        # Wait for process to stop
        local count=0
        while is_process_running "$pid" && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        if is_process_running "$pid"; then
            echo -e "${YELLOW}Process didn't stop gracefully, forcing termination...${NC}"
            kill -9 "$pid"
            sleep 1
        fi
        
        if ! is_process_running "$pid"; then
            echo -e "${GREEN}✓ Enhanced monitor stopped successfully${NC}"
            rm -f "$pid_file"
            
            # Create archive with logs
            create_log_archive "$log_file"
        else
            echo -e "${RED}✗ Failed to stop enhanced monitor${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Enhanced monitor is not running${NC}"
        rm -f "$pid_file"  # Clean up stale PID file
        
        # Still create archive if monitor log exists
        if [[ -n "$log_file" && -f "$log_file" ]]; then
            create_log_archive "$log_file"
        fi
    fi
}

check_status() {
    local log_file="$2"
    
    # Use default filename if none specified
    if [[ -z "$log_file" ]]; then
        log_file="cme_monitor.txt"
        echo -e "${BLUE}No log file specified, checking default: $log_file${NC}"
        echo ""
        
        # Check if default monitor is running first
        local pid=$(get_pid_from_file "$log_file")
        if [[ -n "$pid" ]] && is_process_running "$pid"; then
            # Default monitor is running, show its status
            echo -e "${GREEN}✓ Enhanced monitor is running${NC}"
            echo -e "PID: $pid"
            echo -e "Log file: $log_file"
            
            # Show process info
            echo -e "\nProcess info:"
            ps -p "$pid" -o pid,ppid,etime,cmd 2>/dev/null || echo "Unable to get process info"
            
            # Show recent log entries
            if [[ -f "$log_file" ]]; then
                echo -e "\nLast 3 system entries:"
                grep -E "System Status:" "$log_file" | tail -n 3
                
                echo -e "\nRecent alerts (if any):"
                local recent_alerts=$(grep -E "ALERTS:" "$log_file" | tail -n 5)
                if [[ -n "$recent_alerts" ]]; then
                    echo "$recent_alerts"
                else
                    echo "No recent alerts"
                fi
            fi
            return 0
        else
            # Default monitor not running, check if there are other running monitors
            echo -e "${YELLOW}Default monitor ($log_file) is not running${NC}"
            echo ""
        fi
    fi
    
    # If we get here, either no default file specified or default not running
    # Check for other running monitors
    if [[ -z "$2" ]]; then
        echo -e "${BLUE}No log file specified, checking all running enhanced monitors...${NC}"
        
        # Find all enhanced monitor processes
        local pids=$(ps aux | grep "[e]nhanced_monitor.sh" | awk '{print $2}')
        
        if [[ -z "$pids" ]]; then
            echo -e "${RED}✗ No running enhanced monitor processes found${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✓ Found ${#pids[@]} enhanced monitor process(es)${NC}"
        echo ""
        
        for pid in $pids; do
            echo -e "${BLUE}=== Monitor Process (PID: $pid) ===${NC}"
            
            # Get process info
            ps -p "$pid" -o pid,ppid,etime,cmd 2>/dev/null || echo "Unable to get process info for PID $pid"
            
            # Try to find associated log files by looking for .pid files
            local found_logs=false
            for pidfile in $(find /var/log /tmp /home -name "*.pid" 2>/dev/null); do
                if [[ -f "$pidfile" ]]; then
                    local pid_in_file=$(cat "$pidfile" 2>/dev/null)
                    if [[ "$pid_in_file" == "$pid" ]]; then
                        local associated_log="${pidfile%.pid}"
                        echo -e "Associated log file: ${YELLOW}$associated_log${NC}"
                        
                        if [[ -f "$associated_log" ]]; then
                            echo -e "Recent system entries:"
                            grep -E "System Status:" "$associated_log" | tail -n 3
                            echo ""
                            echo -e "Recent alerts (if any):"
                            local recent_alerts=$(grep -E "ALERTS:" "$associated_log" | tail -n 3)
                            if [[ -n "$recent_alerts" ]]; then
                                echo "$recent_alerts"
                            else
                                echo "No recent alerts"
                            fi
                        fi
                        found_logs=true
                        break
                    fi
                fi
            done
            
            if [[ "$found_logs" != true ]]; then
                echo -e "${YELLOW}No associated log file found for this process${NC}"
            fi
            echo ""
        done
        
        return 0
    fi
    
    local pid=$(get_pid_from_file "$log_file")
    
    if [[ -z "$pid" ]]; then
        echo -e "${RED}✗ Enhanced monitor is not running (no PID file)${NC}"
        exit 1
    fi
    
    if is_process_running "$pid"; then
        echo -e "${GREEN}✓ Enhanced monitor is running${NC}"
        echo -e "PID: $pid"
        echo -e "Log file: $log_file"
        
        # Show process info
        echo -e "\nProcess info:"
        ps -p "$pid" -o pid,ppid,etime,cmd 2>/dev/null || echo "Unable to get process info"
        
        # Show recent log entries
        if [[ -f "$log_file" ]]; then
            echo -e "\nLast 3 system entries:"
            grep -E "System Status:" "$log_file" | tail -n 3
            
            echo -e "\nRecent alerts (if any):"
            local recent_alerts=$(grep -E "ALERTS:" "$log_file" | tail -n 5)
            if [[ -n "$recent_alerts" ]]; then
                echo "$recent_alerts"
            else
                echo "No recent alerts"
            fi
        fi
    else
        echo -e "${RED}✗ Enhanced monitor is not running (PID $pid not found)${NC}"
        rm -f "${log_file}.pid"  # Clean up stale PID file
        exit 1
    fi
}

show_logs() {
    local log_file="$2"
    
    # Use default filename if none specified
    if [[ -z "$log_file" ]]; then
        log_file="cme_monitor.txt"
        echo -e "${BLUE}No log file specified, using default: $log_file${NC}"
        
        # Check if default log file exists
        if [[ -f "$log_file" ]]; then
            echo -e "${GREEN}Found default log file: $log_file${NC}"
        else
            echo -e "${YELLOW}Default log file not found, searching for other monitor logs...${NC}"
        
            # Find log files from running monitors
            local found_logs=($(find /home -name "*.txt" -type f 2>/dev/null | grep -E "(log|monitor)"))
            found_logs+=($(find /var/log -name "*enhanced_monitor*.log" -type f 2>/dev/null))
            found_logs+=($(find /tmp -name "*enhanced_monitor*.log" -type f 2>/dev/null))
            found_logs+=($(find . -maxdepth 1 -name "*.txt" -type f 2>/dev/null))
            
            if [[ ${#found_logs[@]} -eq 0 ]]; then
                echo -e "${RED}No monitor log files found${NC}"
                echo -e "${YELLOW}Try: $0 logs /path/to/logfile${NC}"
                return 1
            fi
            
            log_file="${found_logs[0]}"
            echo -e "${GREEN}Using log file: $log_file${NC}"
        fi
    fi
    
    if [[ ! -f "$log_file" ]]; then
        echo -e "${RED}Log file not found: $log_file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Showing real-time logs from: $log_file${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo ""
    tail -f "$log_file"
}

show_alerts() {
    local log_file="$2"
    
    # Use default filename if none specified
    if [[ -z "$log_file" ]]; then
        log_file="cme_monitor.txt"
        echo -e "${BLUE}No log file specified, checking default: $log_file${NC}"
        
        # Check if default log file exists
        if [[ -f "$log_file" ]]; then
            echo -e "${GREEN}Found default log file: $log_file${NC}"
        else
            echo -e "${YELLOW}Default log file not found, searching for all enhanced monitor log files...${NC}"
        
            # Find all enhanced monitor processes and their log files
            local pids=$(ps aux | grep "[e]nhanced_monitor.sh" | awk '{print $2}')
            local log_files=()
            
            # Collect log files from PID files
            for pidfile in $(find /var/log /tmp /home -name "*.pid" 2>/dev/null); do
                if [[ -f "$pidfile" ]]; then
                    local pid_in_file=$(cat "$pidfile" 2>/dev/null)
                    if [[ -n "$pid_in_file" ]] && echo "$pids" | grep -q "$pid_in_file"; then
                        local associated_log="${pidfile%.pid}"
                        if [[ -f "$associated_log" ]]; then
                            log_files+=("$associated_log")
                        fi
                    fi
                fi
            done
            
            # Also look for common log file patterns
            for pattern in "/var/log/*monitor*.log" "/tmp/*monitor*.log" "/home/*/monitor*.log"; do
                for file in $pattern; do
                    if [[ -f "$file" ]] && ! [[ " ${log_files[@]} " =~ " $file " ]]; then
                        # Check if this looks like an enhanced monitor log
                        if grep -q "Enhanced System.*Monitor Started\|System Status:" "$file" 2>/dev/null; then
                            log_files+=("$file")
                        fi
                    fi
                done
            done
            
            if [[ ${#log_files[@]} -eq 0 ]]; then
                echo -e "${YELLOW}No enhanced monitor log files found${NC}"
                echo -e "Try specifying a log file directly: $0 alerts /path/to/logfile.log"
                exit 1
            fi
            
            echo -e "${GREEN}Found ${#log_files[@]} enhanced monitor log file(s)${NC}"
            echo -e "${YELLOW}Monitoring for alerts from all files - Press Ctrl+C to exit${NC}"
            echo ""
            
            # Show existing alerts from all files first
            local has_alerts=false
            for logfile in "${log_files[@]}"; do
                local existing_alerts=$(grep -E "ALERTS:" "$logfile" 2>/dev/null | tail -n 5)
                if [[ -n "$existing_alerts" ]]; then
                    echo -e "${YELLOW}Recent alerts from $logfile:${NC}"
                    echo "$existing_alerts"
                    echo ""
                    has_alerts=true
                fi
            done
            
            if [[ "$has_alerts" != true ]]; then
                echo -e "${GREEN}No existing alerts in any log files${NC}"
                echo ""
            fi
            
            echo -e "${YELLOW}Monitoring for new alerts...${NC}"
            
            # Monitor all log files for new alerts
            if command -v tail >/dev/null 2>&1; then
                tail -f "${log_files[@]}" 2>/dev/null | grep --line-buffered -E "ALERTS:|WARNING|CRITICAL" --color=auto
            else
                # Fallback if tail -f doesn't work with multiple files
                for logfile in "${log_files[@]}"; do
                    tail -f "$logfile" &
                done
                wait
            fi
            
            return 0
        fi
    fi
    
    if [[ ! -f "$log_file" ]]; then
        echo -e "${RED}Log file not found: $log_file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Showing alerts from: $log_file${NC}"
    echo -e "${YELLOW}Real-time alert monitoring - Press Ctrl+C to exit${NC}"
    echo ""
    
    # Show existing alerts first
    local existing_alerts=$(grep -E "ALERTS:" "$log_file")
    if [[ -n "$existing_alerts" ]]; then
        echo -e "${YELLOW}Existing alerts:${NC}"
        echo "$existing_alerts"
        echo ""
    fi
    
    echo -e "${YELLOW}Monitoring for new alerts...${NC}"
    tail -f "$log_file" | grep --line-buffered -E "ALERTS:|WARNING|CRITICAL"
}

restart_monitor() {
    local log_file="$2"
    local interval="${3:-5}"
    local cpm_log_dir="${4:-/var/log/opt/CPsuite-R82/fw1/log}"
    
    # Use default filename if none specified
    if [[ -z "$log_file" ]]; then
        log_file="cme_monitor.txt"
        echo -e "${BLUE}No log file specified, restarting default: $log_file${NC}"
    fi
    
    echo -e "${BLUE}Restarting enhanced monitor...${NC}"
    stop_monitor "stop" "$log_file"
    sleep 2
    start_monitor "start" "$log_file" "$interval" "$cpm_log_dir"
}

# Function to stop all monitors (alias for stop with no args)
stopall_monitors() {
    echo -e "${BLUE}Stopping all enhanced monitors...${NC}"
    stop_monitor "stop" ""
}

# Function to find Check Point log files
find_cp_logs() {
    echo -e "${BLUE}Searching for Check Point log files...${NC}"
    echo ""
    
    # Check default location
    echo -e "${YELLOW}Checking default location: /opt/CPsuite-R82/fw1/log${NC}"
    if [[ -d "/opt/CPsuite-R82/fw1/log" ]]; then
        ls -la /opt/CPsuite-R82/fw1/log/ | grep -E "\\.elg|\\.log"
    else
        echo "Directory not found"
    fi
    echo ""
    
    # Search for .elg files system-wide
    echo -e "${YELLOW}Searching for .elg files in /opt...${NC}"
    find /opt -name "*.elg" -type f 2>/dev/null | head -10
    echo ""
    
    echo -e "${YELLOW}Searching for .elg files in /var/log...${NC}"
    find /var/log -name "*.elg" -type f 2>/dev/null | head -10
    echo ""
    
    # Look for Check Point directories
    echo -e "${YELLOW}Looking for Check Point directories...${NC}"
    find /opt -name "*CP*" -type d 2>/dev/null | head -10
    find /opt -name "*checkpoint*" -type d 2>/dev/null | head -10
    echo ""
    
    # Check if this is the right system
    echo -e "${YELLOW}System information:${NC}"
    uname -a
    echo ""
    echo -e "${YELLOW}Check Point processes:${NC}"
    ps aux | grep -i checkpoint | grep -v grep
    ps aux | grep -i cloud | grep -v grep
}

# Main script logic
case "$1" in
    start)
        start_monitor "$@"
        ;;
    stop)
        stop_monitor "$@"
        ;;
    stopall)
        stopall_monitors
        ;;
    status)
        check_status "$@"
        ;;
    logs)
        show_logs "$@"
        ;;
    alerts)
        show_alerts "$@"
        ;;
    restart)
        restart_monitor "$@"
        ;;
    findlogs)
        find_cp_logs
        ;;
    help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac