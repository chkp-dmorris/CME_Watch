# Azure Objects Dumper - Usage Guide

## Overview
I've created tools to dump all Azure objects stored in the CloudGuard Controller database. The objects are stored in a SQLite database at:
```
/opt/CPvsec-R82/scripts/azure/cloudguard_controller
```

## Tools Created

### 1. Shell Script (Simple)
**Location**: `/tmp/dump_azure_objects.sh`
**Usage**:
```bash
/tmp/dump_azure_objects.sh
```

**Features**:
- Shows all tables and record counts
- Displays table structure (columns and types)
- Shows sample data (first 3 records per table)
- Provides summary statistics

### 2. Python Script (Advanced)
**Location**: `dump_azure_objects.py`
**Usage**:
```bash
# Copy to CloudGuard system first
scp dump_azure_objects.py expert@135.237.14.172:/tmp/

# Then run on CloudGuard system
python3 /tmp/dump_azure_objects.py [options]
```

**Options**:
```bash
# Dump all tables in readable format
python3 dump_azure_objects.py

# Dump as JSON
python3 dump_azure_objects.py --format json

# Dump specific table only
python3 dump_azure_objects.py --table virtualMachines

# Save to file
python3 dump_azure_objects.py --output azure_dump.json --format json
```

## How to Populate the Database

### Prerequisites
1. Set Azure credentials:
   ```bash
   export AZURE_CREDENTIALS="your_credentials_here"
   # Optional: export AZURE_ENVIRONMENT="..."
   ```

### Run Azure Scanning
```bash
# Test credentials first
python3 /opt/CPvsec-R82/scripts/azure/vsec.py --test

# List subscriptions
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -ls <datacenter>

# Scan specific subscription
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s <datacenter> <subscription_id>

# Scan with additional resources
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s <datacenter> <subscription_id> --appgateways --apimgmtservices
```

## Database Structure

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

## Current Status
- ❌ Database doesn't exist yet
- ✅ Dump tools are ready
- 💡 Need to run Azure scanning first to populate database

## Next Steps
1. Configure Azure credentials
2. Run Azure scanning process
3. Use dump tools to extract all stored objects