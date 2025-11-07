# Azure Objects Dumper - Usage Guide

## Tools Created

> **Important**: These dump tools work on the **existing database** - no subscription specification needed!

### 1. Shell Script (Simple)
**Location**: `/tmp/dump_azure_objects.sh`
**Usage**:
```bash
# Simply run the script - it reads from the populated database
/tmp/dump_azure_objects.sh
```

**Features**:
- Shows all tables and record counts from ALL scanned subscriptions
- Displays table structure (columns and types)
- Shows sample data (first 3 records per table)
- Provides summary statistics across all collected data
- **No parameters required** - automatically finds the database

### 2. Python Script (Advanced)
**Location**: `dump_azure_objects.py`
**Usage**:
```bash
# Copy to CloudGuard system first
scp dump_azure_objects.py expert@1.2.3.4:/tmp/

# Then run on CloudGuard system - NO subscription needed!
python3 /tmp/dump_azure_objects.py [options]
```

**Key Point**: The Python script reads from the **existing database** containing data from all previously scanned subscriptions.

**Examples:**
```bash
# Dump all tables in readable format
python3 dump_azure_objects.py

# Dump as JSON
python3 dump_azure_objects.py --format json

# Dump specific table only
python3 dump_azure_objects.py --table virtualMachines

# Save to file (JSON)
python3 dump_azure_objects.py --output azure_dump.json --format json

# Show help
python3 dump_azure_objects.py --help
```

**All Available Options**:
```bash
--format {json,table}     # Output format (default: table)
--table TABLE_NAME        # Dump specific table only
--output FILENAME         # Save to file instead of stdout
--help                    # Show all options
--search SEARCH_TERM       # Search for a name or IP across all tables
```

> **Note**: The database is **cumulative** - it contains objects from all subscriptions that have been scanned. The dump tools give you a unified view across your entire Azure environment.

## How to Use the Dump Tools

### Prerequisites
- **Database file exists**: `/opt/CPvsec-R82/scripts/azure/cloudguard_controller`
- **SQLite access**: Ability to read SQLite files on the CloudGuard system
- **No Azure credentials needed**: Dump tools work completely offline from the database

### Running the Dump Tools
```bash
# Copy scripts to CloudGuard system
scp dump_azure_objects.sh expert@1.2.3.4:/tmp/
scp dump_azure_objects.py expert@1.2.3.4:/tmp/

# Run simple dump
/tmp/dump_azure_objects.sh

# Or run advanced dump
python3 /tmp/dump_azure_objects.py --format json --output azure_data.json
```

---


Once populated, the database will contain tables for:

| Table Name | Description |
|------------|-------------|
| `virtualMachines` | Azure Virtual Machines |
| `networkSecurityGroups` | Network Security Groups |
| `loadBalancers` | Load Balancers |
| `publicIpAddresses` | Public IP Addresses |
| `networkInterfaces` | Network Interfaces |
| `virtualNetworks` | Virtual Networks |
| `virtualNetworkGateways` | VPN/ExpressRoute Gateways |
| `vpnGateways` | VPN Gateways |
| `applicationGateways` | Application Gateways (if enabled) |
| `apiManagementServices` | API Management Services (if enabled) |

## Data Format

Each table contains:
- **Individual columns**: Specific Azure object properties
- **json_data column**: Complete Azure object as JSON

## Example Output

### Shell Script Output:
```
Azure Objects Database Dumper
==============================
Database path: /opt/CPvsec-R82/scripts/azure/cloudguard_controller

✅ Database found

📊 Found tables:
  - virtualMachines: 15 records
  - networkSecurityGroups: 8 records
  - loadBalancers: 3 records

================================================
TABLE: virtualMachines
================================================
Records: 15
Columns:
  - id (TEXT)
  - name (TEXT)
  - location (TEXT)
  - json_data (TEXT)

Sample Data (first 3 records):
id                                          name        location
/subscriptions/abc123/...                   vm-web-01   eastus
/subscriptions/abc123/...                   vm-db-01    eastus
/subscriptions/abc123/...                   vm-app-01   westus
```

### JSON Output:
```json
{
  "virtualMachines": {
    "info": {
      "name": "virtualMachines",
      "row_count": 15,
      "columns": [...]
    },
    "data": [
      {
        "id": "/subscriptions/abc123/...",
        "name": "vm-web-01",
        "location": "eastus",
        "json_data": {
          "id": "/subscriptions/abc123/...",
          "name": "vm-web-01",
          "properties": {...}
        }
      }
    ]
  }
}
```

# Search for a name or IP (shell script)
./dump_azure_objects.sh web-01
./dump_azure_objects.sh 10.0.0.4
