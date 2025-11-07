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

# Function to search by name or IP in a table
search_table() {
    local table_name="$1"
    local search_term="$2"
    # Find columns named 'name' or containing 'ip' (case-insensitive)
    local columns=$(sqlite3 "$DB_PATH" "PRAGMA table_info($table_name);" | awk -F'|' '{print $2}' | grep -i -E 'name|ip')
    if [ -z "$columns" ]; then
        return
    fi
    local where_clauses=""
    for col in $columns; do
        if [ -n "$where_clauses" ]; then
            where_clauses+=" OR "
        fi
        where_clauses+="$col LIKE '%$search_term%'"
    done
    local query="SELECT * FROM $table_name WHERE $where_clauses;"
    local results=$(sqlite3 -header -column "$DB_PATH" "$query")
    if [ -n "$results" ]; then
        echo "================================================"
        echo "TABLE: $table_name (search: $search_term)"
        echo "================================================"
        echo "$results"
        echo
    fi
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

# If a search term is provided, search all tables and exit
if [ -n "$1" ]; then
    search_term="$1"
    found=0
    echo "Searching for: $search_term"
    echo "$tables" | while read table; do
        search_table "$table" "$search_term" && found=1
    done
    if [ "$found" -eq 0 ]; then
        echo "No results found for search: $search_term"
    fi
    echo "✅ Search completed"
    exit 0
fi

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