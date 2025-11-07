# Azure Objects Dumper - Usage Guide

## Overview
This toolkit provides a two-phase approach to Azure object management:

### Phase 1: Data Collection (Requires Azure Credentials)
Azure scanning tools populate a SQLite database with objects from your specified subscription(s). Each scan **adds** data to the existing database, allowing you to build a comprehensive inventory across multiple subscriptions.

### Phase 2: Data Extraction (NO Azure Credentials Needed)
The dump tools read from the populated database and can export data in various formats. They work on **all collected data** regardless of which subscription(s) it came from. **These tools work completely offline** from the local database.

**Database Location**: 
```
/opt/CPvsec-R82/scripts/azure/cloudguard_controller
```

## Workflow Summary
```
1. Scan Subscription A → Database (needs Azure creds)
2. Scan Subscription B → Database (needs Azure creds) 
3. Scan Subscription C → Database (needs Azure creds)
4. Run dump tools → Extract ALL data from A+B+C (NO Azure creds needed)
```


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

**Common Usage Patterns**:
```bash
# Quick overview - dump all data from ALL subscriptions
python3 dump_azure_objects.py

# Export everything to JSON (includes all scanned subscriptions)
python3 dump_azure_objects.py --format json --output full_azure_dump.json

# Focus on specific resource type across all subscriptions
python3 dump_azure_objects.py --table virtualMachines
python3 dump_azure_objects.py --table networkSecurityGroups --format json

# Export VMs from ALL subscriptions for reporting
python3 dump_azure_objects.py --table virtualMachines --output vm_inventory.json --format json

# Get readable summary of security groups (all subscriptions)
python3 dump_azure_objects.py --table networkSecurityGroups --output nsg_summary.txt
```

**All Available Options**:
```bash
--format {table,json}     # Output format (default: table)
--table TABLE_NAME        # Dump specific table only
--output FILENAME         # Save to file instead of stdout
--help                    # Show all options
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

## Data Collection Setup (Optional)

> **Note**: This section is only needed if the database doesn't exist yet or you want to refresh the data with new Azure scans.

### Prerequisites for Data Collection
1. **Azure Credentials**: Set up authentication to your Azure environment:
   ```bash
   export AZURE_CREDENTIALS="your_credentials_here"
   # Optional: export AZURE_ENVIRONMENT="AzureCloud" (default)
   ```

2. **CloudGuard Controller Access**: Ensure you have access to the CloudGuard system for running scans.

### Step-by-Step Workflow

#### 1. Test Azure Connection
First, verify your Azure credentials work:
```bash
python3 /opt/CPvsec-R82/scripts/azure/vsec.py --test
```

#### 2. Discover Available Subscriptions
List all subscriptions you have access to:
```bash
# Replace <datacenter> with your datacenter name (e.g., "eastus", "westus2", etc.)
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -ls <datacenter>
```

**Example output:**
```
Available subscriptions in eastus:
- 12345678-1234-1234-1234-123456789abc (Production Environment)
- 87654321-4321-4321-4321-cba987654321 (Development Environment)
- abcdef12-5678-9012-3456-789012345678 (Testing Environment)
```

#### 3. Scan Specific Subscription(s)
**Yes, you MUST specify a subscription ID**. The tool scans one subscription at a time:

```bash
# Basic scan (core resources only)
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s <datacenter> <subscription_id>

# Extended scan with additional resources
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s <datacenter> <subscription_id> --appgateways --apimgmtservices
```

**Real example:**
```bash
# Scan production subscription in East US
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s eastus 12345678-1234-1234-1234-123456789abc

# Scan with Application Gateways and API Management
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s eastus 12345678-1234-1234-1234-123456789abc --appgateways --apimgmtservices
```

#### 4. Scan Multiple Subscriptions (Optional)
To populate the database with resources from multiple subscriptions, run the scan command for each subscription:

```bash
# Scan subscription 1
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s eastus 12345678-1234-1234-1234-123456789abc

# Scan subscription 2 (data will be added to existing database)
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s eastus 87654321-4321-4321-4321-cba987654321

# Scan subscription 3
python3 /opt/CPvsec-R82/scripts/azure/vsec.py -s eastus abcdef12-5678-9012-3456-789012345678
```

### Scanning Options

| Option | Description | Required |
|--------|-------------|----------|
| `<datacenter>` | Azure region (e.g., eastus, westus2) | ✅ Yes |
| `<subscription_id>` | Target Azure subscription UUID | ✅ Yes |
| `--appgateways` | Include Application Gateways | ❌ Optional |
| `--apimgmtservices` | Include API Management Services | ❌ Optional |

### Troubleshooting
- **"No subscriptions found"**: Check your Azure credentials and permissions
- **"Database creation failed"**: Verify write permissions to `/opt/CPvsec-R82/scripts/azure/`
- **"Scan timeout"**: Large subscriptions may take 10-30 minutes to scan completely

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

## Quick Start Guide

### Primary Use Case: Extract Data from Existing Database
- [ ] **Copy dump scripts** to CloudGuard system (`scp dump_azure_objects.* expert@1.2.3.4:/tmp/`)
- [ ] **Run dump tools** (`/tmp/dump_azure_objects.sh` or `python3 /tmp/dump_azure_objects.py`)
- [ ] **Export data** in your preferred format (table or JSON)

### Optional: If Database Doesn't Exist Yet
See the "Data Collection Setup" section below if you need to populate the database first.

## Current Status
- ✅ **Dump tools are ready** - can extract data from any existing database
- ❓ **Database status unknown** - check if `/opt/CPvsec-R82/scripts/azure/cloudguard_controller` exists
- 📋 **If database exists** - you can immediately use the dump tools
- � **If database missing** - see "Data Collection Setup" section below

## Important Notes

### Data Collection (vsec.py)
- **Subscription ID is mandatory** - the scanning tool cannot work without specifying a target subscription
- **One subscription per scan** - repeat the scan command for each subscription you want to include
- **Database is cumulative** - multiple scans will add data to the existing database
- **Scan time varies** - expect 5-30 minutes depending on subscription size

### Data Extraction (dump tools)
- **No subscription needed** - dump tools read from the existing database
- **Works on ALL data** - shows objects from every subscription that has been scanned
- **Multiple output formats** - table view for humans, JSON for automation
- **Selective extraction** - can focus on specific resource types if needed

### Database Behavior
- **Single database** holds objects from multiple subscriptions
- **Persistent storage** - data remains until manually deleted
- **Incremental updates** - rescanning a subscription will update its objects in the database