#!/bin/bash
# Azure Objects Dumper - Shell Script Version
# Dumps all Azure objects from CloudGuard Controller SQLite database

DB_PATH="/opt/CPvsec-R82/scripts/azure/cloudguard_controller"

echo "Azure Objects Database Dumper"
echo "=============================="
echo "Database path: $DB_PATH"
echo

# Check if database exists
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database not found!"
    echo "💡 Run Azure scanning first:"
    echo "   python3 /opt/CPvsec-R82/scripts/azure/vsec.py [options]"
    exit 1
fi

echo "✅ Database found"
echo

# Function to dump table structure and data
dump_table() {
    local table_name="$1"
    echo "================================================"
    echo "TABLE: $table_name"
    echo "================================================"
    
    # Get record count
    local count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $table_name;")
    echo "Records: $count"
    
    if [ "$count" -eq 0 ]; then
        echo "No data found."
        echo
        return
    fi
    
    # Get column names
    echo "Columns:"
    sqlite3 "$DB_PATH" "PRAGMA table_info($table_name);" | while IFS='|' read -r cid name type notnull dflt_value pk; do
        echo "  - $name ($type)"
    done
    echo
    
    # Show sample data (first 3 records)
    echo "Sample Data (first 3 records):"
    sqlite3 -header -column "$DB_PATH" "SELECT * FROM $table_name LIMIT 3;"
    
    if [ "$count" -gt 3 ]; then
        echo "... and $((count - 3)) more records"
    fi
    echo
}

# Get all tables
echo "Getting table list..."
tables=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table';")

if [ -z "$tables" ]; then
    echo "❌ No tables found in database"
    exit 1
fi

echo "📊 Found tables:"
echo "$tables" | while read table; do
    count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $table;")
    echo "  - $table: $count records"
done
echo

# Dump each table
echo "$tables" | while read table; do
    dump_table "$table"
done

# Summary
echo "================================================"
echo "SUMMARY"
echo "================================================"
total_tables=$(echo "$tables" | wc -l)
total_records=0

echo "Database: $DB_PATH"
echo "Total tables: $total_tables"
echo "Table breakdown:"

echo "$tables" | while read table; do
    count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM $table;")
    echo "  - $table: $count records"
    total_records=$((total_records + count))
done

echo
echo "✅ Dump completed"