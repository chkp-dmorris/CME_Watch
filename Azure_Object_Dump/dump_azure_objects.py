#!/usr/bin/env python3
"""
Azure Objects Dumper
====================
This script dumps all Azure objects stored in the CloudGuard Controller SQLite database.
It can output data in JSON format or as formatted tables.

Usage:
    python3 dump_azure_objects.py [--format json|table] [--table TABLE_NAME] [--output FILE]
"""

import sys
import sqlite3
import json
import os
import argparse
from typing import Dict, List, Any

# Add the CloudGuard Azure scripts path
AZURE_SCRIPTS_PATH = '/opt/CPvsec-R82/scripts/azure'
sys.path.insert(0, AZURE_SCRIPTS_PATH)

try:
    import vsec
    DB_PATH = vsec.DB_PATH_AND_NAME
except ImportError:
    DB_PATH = '/opt/CPvsec-R82/scripts/azure/cloudguard_controller'

def check_database_exists() -> bool:
    """Check if the database file exists."""
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found at: {DB_PATH}")
        print("💡 Run the Azure scanning process first:")
        print("   python3 /opt/CPvsec-R82/scripts/azure/vsec.py [options]")
        return False
    return True

def get_all_tables(cursor: sqlite3.Cursor) -> List[str]:
    """Get list of all tables in the database."""
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    return [row[0] for row in cursor.fetchall()]

def get_table_info(cursor: sqlite3.Cursor, table_name: str) -> Dict[str, Any]:
    """Get information about a specific table."""
    # Get column info
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = cursor.fetchall()
    
    # Get row count
    cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
    count = cursor.fetchone()[0]
    
    return {
        'name': table_name,
        'columns': [{'name': col[1], 'type': col[2]} for col in columns],
        'row_count': count
    }

def dump_table_data(cursor: sqlite3.Cursor, table_name: str) -> List[Dict[str, Any]]:
    """Dump all data from a specific table."""
    cursor.execute(f"SELECT * FROM {table_name}")
    columns = [description[0] for description in cursor.description]
    
    rows = []
    for row in cursor.fetchall():
        row_dict = {}
        for i, value in enumerate(row):
            # Try to parse JSON data if it's in json_data column
            if columns[i] == 'json_data' and value:
                try:
                    row_dict[columns[i]] = json.loads(value)
                except json.JSONDecodeError:
                    row_dict[columns[i]] = value
            else:
                row_dict[columns[i]] = value
        rows.append(row_dict)
    
    return rows

def format_table_output(table_info: Dict[str, Any], data: List[Dict[str, Any]]) -> str:
    """Format table data for readable output."""
    output = []
    output.append(f"\n{'='*60}")
    output.append(f"TABLE: {table_info['name'].upper()}")
    output.append(f"{'='*60}")
    output.append(f"Records: {table_info['row_count']}")
    
    if table_info['row_count'] == 0:
        output.append("No data found.")
        return '\n'.join(output)
    
    output.append(f"Columns: {', '.join([col['name'] for col in table_info['columns']])}")
    output.append("")
    
    # Show first few records
    for i, record in enumerate(data[:5]):  # Show max 5 records
        output.append(f"--- Record {i+1} ---")
        for key, value in record.items():
            if key == 'json_data' and isinstance(value, dict):
                output.append(f"  {key}: [JSON Object with {len(value)} keys]")
                # Show some key fields if available
                if 'name' in value:
                    output.append(f"    name: {value.get('name')}")
                if 'id' in value:
                    output.append(f"    id: {value.get('id')}")
                if 'location' in value:
                    output.append(f"    location: {value.get('location')}")
            else:
                output.append(f"  {key}: {value}")
        output.append("")
    
    if len(data) > 5:
        output.append(f"... and {len(data) - 5} more records")
    
    return '\n'.join(output)

def dump_all_objects(format_type: str = 'table', specific_table: str = None, output_file: str = None):
    """Main function to dump all Azure objects."""
    if not check_database_exists():
        return
    
    try:
        # Connect to database
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print(f"📊 Connected to database: {DB_PATH}")
        
        # Get all tables
        tables = get_all_tables(cursor)
        if not tables:
            print("❌ No tables found in database.")
            return
        
        # Filter to specific table if requested
        if specific_table:
            if specific_table not in tables:
                print(f"❌ Table '{specific_table}' not found.")
                print(f"Available tables: {', '.join(tables)}")
                return
            tables = [specific_table]
        
        # Collect all data
        all_data = {}
        
        for table_name in tables:
            table_info = get_table_info(cursor, table_name)
            table_data = dump_table_data(cursor, table_name)
            
            all_data[table_name] = {
                'info': table_info,
                'data': table_data
            }
        
        # Generate output
        if format_type == 'json':
            output_content = json.dumps(all_data, indent=2, default=str)
        else:
            output_parts = []
            output_parts.append(f"Azure Objects Database Dump")
            output_parts.append(f"Generated: {os.popen('date').read().strip()}")
            output_parts.append(f"Database: {DB_PATH}")
            output_parts.append(f"Tables found: {len(tables)}")
            
            for table_name in tables:
                table_info = all_data[table_name]['info']
                table_data = all_data[table_name]['data']
                output_parts.append(format_table_output(table_info, table_data))
            
            output_content = '\n'.join(output_parts)
        
        # Write to file or print
        if output_file:
            with open(output_file, 'w') as f:
                f.write(output_content)
            print(f"✅ Output written to: {output_file}")
        else:
            print(output_content)
        
        # Summary
        total_records = sum(all_data[table]['info']['row_count'] for table in all_data)
        print(f"\n📋 Summary:")
        print(f"   Tables: {len(tables)}")
        print(f"   Total records: {total_records}")
        
        for table_name in tables:
            count = all_data[table_name]['info']['row_count']
            print(f"   - {table_name}: {count} records")
        
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if 'conn' in locals():
            conn.close()

def main():
    """Command line interface."""
    parser = argparse.ArgumentParser(
        description="Dump Azure objects from CloudGuard Controller database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Dump all tables in readable format
    python3 dump_azure_objects.py
    
    # Dump as JSON
    python3 dump_azure_objects.py --format json
    
    # Dump specific table only
    python3 dump_azure_objects.py --table virtualMachines
    
    # Save to file
    python3 dump_azure_objects.py --output azure_dump.json --format json
        """
    )
    
    parser.add_argument('--format', choices=['json', 'table'], default='table',
                        help='Output format (default: table)')
    parser.add_argument('--table', help='Dump specific table only')
    parser.add_argument('--output', help='Output file (default: stdout)')
    
    args = parser.parse_args()
    
    dump_all_objects(args.format, args.table, args.output)

if __name__ == "__main__":
    main()