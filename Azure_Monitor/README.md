# Enhanced CloudGuard Monitoring System

## Overview
This monitoring system provides comprehensive real-time monitoring for Check Point CloudGuard environments, with specialized focus on Azure Data Center mapping performance and system resource tracking.

## Files
- **`enhanced_control.sh`** - Main control interface (recommended)
- **`enhanced_monitor.sh`** - Core monitoring daemon
- **`README.md`** - This documentation

## Quick Start
```bash
# Start monitoring with default settings
./enhanced_control.sh start

# View real-time logs
./enhanced_control.sh logs

# Check status
./enhanced_control.sh status

# View only system alerts
./enhanced_control.sh alerts

# Stop monitoring (creates archive)
./enhanced_control.sh stop
```

## What It Monitors

### 🖥️ **System Resources**
- **CPU Usage** - Percentage and top processes
- **Memory Usage** - Available, used, and percentage
- **Disk Space** - Usage percentage and available space
- **Load Average** - System load metrics
- **Process Monitoring** - Top CPU and memory consumers

### ☁️ **CloudGuard Events**
- **Azure Data Center Mapping** - Performance timing and frequency
- **CloudGuard Controller Events** - Startup, restart, autoupdate detection
- **Log Forwarding Status** - Failure detection and analysis
- **Environment Changes** - Scan differences and policy updates
- **API Errors** - Connection failures and timeouts

### 📊 **Performance Analysis**
- **Mapping Times** - Extracts and logs Data Center mapping duration
- **Alert Thresholds** - Configurable CPU, memory, and disk warnings
- **Real-time Monitoring** - Updates every 5 seconds (configurable)
- **Background Operation** - Survives SSH disconnections

## Key Features

### 🚀 **Easy Management**
- **Default Configuration** - Works out-of-the-box with `cme_monitor.txt`
- **Multiple Monitors** - Run multiple instances with different log files
- **Automatic Discovery** - Finds CloudProxy logs automatically
- **Clean Shutdown** - Creates comprehensive log archive on stop

### 📈 **Comprehensive Logging**
- **CloudGuard Events** - All `calc_desc` events captured
- **System Metrics** - CPU, memory, disk, load average
- **Performance Timing** - Azure mapping duration extraction
- **Alert Classification** - WARNING/CRITICAL threshold-based alerts

### 🔧 **Flexible Configuration**
- **Custom Log Files** - `./enhanced_control.sh start custom_name.txt`
- **Adjustable Intervals** - Monitoring frequency configuration
- **Multiple Data Centers** - Generic pattern matching for any DC name
- **Archive Creation** - Automatic backup with cpinfo on stop

## Sample Output

### CloudGuard Event Detection
```
CLOUDGUARD EVENT: 21/10/25 19:45:24,268 INFO monitoring.smartlog.LogsWsImpl [scanner-Azure-1593900764]: Log {"severity":"0","product":"CloudGuard IaaS","calc_desc":"Mapping of Data Center [azure-R&D] finished. Mapping took 7 seconds. Next mapping is in 30 seconds."} was send to domain SMC User
Data Center mapping time [azure-R&D]: 7 seconds
```

### System Status
```
[2025-10-21 19:47:56] System Status: CPU:15.5% | Memory:29.9%(4706MB/15744MB) | Load:1.04, 0.71, 0.76 | Disk:65%(13G/20G) | TopCPU:/opt/CPshrd-R82/jre_64/bin/java(19.3%) | TopMem:/opt/CPshrd-R82/jre_64/bin/java(10.3%)
```

### System Alerts
```
[2025-10-21 19:47:56] ALERTS: [WARNING] High CPU usage: 85% (threshold: 80%); [INFO] Memory usage normal: 30%
```

## Command Reference

### Control Commands
```bash
./enhanced_control.sh start [log_file]    # Start monitoring
./enhanced_control.sh stop [log_file]     # Stop monitoring + create archive
./enhanced_control.sh restart [log_file]  # Restart monitoring
./enhanced_control.sh status [log_file]   # Show current status
./enhanced_control.sh logs [log_file]     # Real-time log viewing
./enhanced_control.sh alerts [log_file]   # Show alerts only
./enhanced_control.sh stopall            # Stop all running monitors
./enhanced_control.sh findlogs           # Locate Check Point log files
./enhanced_control.sh help               # Show help
```

### Direct Monitor Usage
```bash
./enhanced_monitor.sh                     # Show usage help
./enhanced_monitor.sh logname.txt         # Start monitoring directly
```

## File Locations

### Default Paths
- **Monitor Log**: `cme_monitor.txt` (current directory)
- **PID File**: `cme_monitor.txt.pid`
- **CloudProxy Logs**: `/var/log/opt/CPsuite-R82/fw1/log/cloud_proxy.elg*`
- **Archives**: `cme_monitor_YYYYMMDD_HHMMSS.tar.gz`

### Log Search Locations
- `/var/log/opt/CPsuite-R82/fw1/log/` (default)
- `/opt/CPsuite-R82/fw1/log/`
- Auto-discovery in `/var/log`, `/opt`, `/home`

## Alert Thresholds

### Default Warning Levels
- **CPU**: 80% warning, 90% critical
- **Memory**: 85% warning, 95% critical  
- **Disk**: 85% warning, 95% critical
- **Azure Mapping**: >10 seconds warning, >15 seconds critical

## Archive Contents
When stopping monitoring, creates archive with:
- Monitor log file(s) from active processes
- CloudProxy log files (`cloud_proxy.elg`)
- System information (`cpinfo` output)
- Flattened file structure for easy analysis

## Troubleshooting

### Common Issues
1. **No CloudProxy logs found**: Run `./enhanced_control.sh findlogs`
2. **Permission denied**: Ensure scripts are executable (`chmod +x *.sh`)
3. **Multiple monitors**: Use specific log names or `stopall` command
4. **Missing calc_desc events**: Check if CloudGuard is active and generating events

### Debug Information
The scripts automatically provide informative output about:
- Log file locations and sizes
- Number of events detected
- Process status and PIDs
- Archive creation details

## Use Cases

### 🎯 **Perfect For:**
- **CloudGuard Performance Monitoring** - Track Azure mapping times and frequency
- **System Health Monitoring** - Continuous resource tracking
- **Troubleshooting** - Correlate CloudGuard events with system metrics
- **Performance Baseline** - Establish normal operating parameters
- **Incident Response** - Automated log collection and archival

### 📋 **Monitoring Scenarios:**
- Long-running CloudGuard deployments
- Azure environment change detection
- Performance regression analysis
- System resource trend analysis
- Automated log collection for support cases

---

**Created for Check Point CloudGuard monitoring and Azure Data Center mapping analysis.**