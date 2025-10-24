"""
Sample ETL script for loading geospatial data into Iceberg via DuckDB
"""
import duckdb
import argparse
import os
import sys
from pathlib import Path


def load_geospatial_data(
    input_file: str,
    table_name: str,
    polaris_endpoint: str,
    s3_bucket: str,
    aws_region: str = "us-west-2",
    h3_resolution: int = 5
):
    """
    Load geospatial data into Iceberg table with H3 partitioning
    
    Args:
        input_file: Path to input GeoJSON file
        table_name: Name of the Iceberg table to create
        polaris_endpoint: Polaris catalog endpoint URL
        s3_bucket: S3 bucket for data storage
        aws_region: AWS region
        h3_resolution: H3 resolution for partitioning (default: 5)
    """
    print(f"Loading data from {input_file}...")
    print(f"Target table: {table_name}")
    print(f"Polaris endpoint: {polaris_endpoint}")
    print(f"S3 bucket: {s3_bucket}")
    
    # Connect to DuckDB
    conn = duckdb.connect(":memory:")
    
    # Install and load extensions
    print("Installing DuckDB extensions...")
    conn.execute("INSTALL spatial")
    conn.execute("INSTALL httpfs")
    conn.execute("INSTALL h3 FROM community")
    conn.execute("INSTALL iceberg")
    
    conn.execute("LOAD spatial")
    conn.execute("LOAD httpfs")
    conn.execute("LOAD h3")
    conn.execute("LOAD iceberg")
    
    # Configure AWS
    conn.execute(f"SET s3_region='{aws_region}'")
    
    # Attach Polaris catalog
    print("Connecting to Polaris catalog...")
    catalog_sql = f"""
    CREATE OR REPLACE CATALOG polaris
    FROM iceberg(
        'rest',
        uri='{polaris_endpoint}/v1/polaris'
    )
    """
    conn.execute(catalog_sql)
    
    # Load source data
    print("Reading source data...")
    conn.execute(f"CREATE TABLE source_data AS SELECT * FROM ST_Read('{input_file}')")
    
    # Check if geometry column exists
    result = conn.execute("DESCRIBE source_data").fetchall()
    columns = [row[0] for row in result]
    
    if 'geom' not in columns and 'geometry' not in columns:
        print("Error: No geometry column found in input data")
        sys.exit(1)
    
    geom_col = 'geom' if 'geom' in columns else 'geometry'
    
    # Add H3 partition column
    print(f"Computing H3 cells at resolution {h3_resolution}...")
    h3_sql = f"""
    CREATE TABLE source_with_h3 AS
    SELECT 
        *,
        h3_h3_to_string(
            h3_latlng_to_cell(
                ST_Y(ST_Centroid({geom_col})),
                ST_X(ST_Centroid({geom_col})),
                {h3_resolution}
            )
        ) as h3_cell,
        ST_AsWKB({geom_col}) as geometry
    FROM source_data
    """
    conn.execute(h3_sql)
    
    # Remove original geometry column to avoid duplication
    conn.execute(f"ALTER TABLE source_with_h3 DROP COLUMN {geom_col}")
    
    # Count features
    count = conn.execute("SELECT COUNT(*) FROM source_with_h3").fetchone()[0]
    print(f"Processing {count:,} features...")
    
    # Get H3 cell distribution
    h3_dist = conn.execute("""
        SELECT h3_cell, COUNT(*) as count 
        FROM source_with_h3 
        GROUP BY h3_cell 
        ORDER BY count DESC 
        LIMIT 10
    """).fetchall()
    print(f"Top H3 cells: {len(h3_dist)} unique cells")
    for cell, cnt in h3_dist[:5]:
        print(f"  {cell}: {cnt:,} features")
    
    # Create Iceberg table with H3 partitioning
    print(f"Creating Iceberg table: {table_name}...")
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS polaris.default.{table_name} (
        SELECT * FROM source_with_h3
    )
    PARTITION BY (h3_cell)
    """
    
    try:
        conn.execute(create_table_sql)
        print(f"✓ Table {table_name} created successfully!")
        
        # Verify table
        table_count = conn.execute(
            f"SELECT COUNT(*) FROM polaris.default.{table_name}"
        ).fetchone()[0]
        print(f"✓ Verified {table_count:,} features in table")
        
        # Show table metadata
        print("\nTable information:")
        partitions = conn.execute(
            f"SELECT COUNT(DISTINCT h3_cell) FROM polaris.default.{table_name}"
        ).fetchone()[0]
        print(f"  Partitions: {partitions}")
        
        # Get extent
        extent = conn.execute(f"""
            SELECT 
                MIN(ST_XMin(ST_GeomFromWKB(geometry))) as minx,
                MIN(ST_YMin(ST_GeomFromWKB(geometry))) as miny,
                MAX(ST_XMax(ST_GeomFromWKB(geometry))) as maxx,
                MAX(ST_YMax(ST_GeomFromWKB(geometry))) as maxy
            FROM polaris.default.{table_name}
        """).fetchone()
        print(f"  Extent: [{extent[0]:.4f}, {extent[1]:.4f}, {extent[2]:.4f}, {extent[3]:.4f}]")
        
    except Exception as e:
        print(f"✗ Error creating table: {e}")
        sys.exit(1)
    
    conn.close()
    print("\n✓ ETL complete!")


def main():
    parser = argparse.ArgumentParser(description="Load geospatial data into Iceberg via DuckDB")
    parser.add_argument("--input", required=True, help="Input GeoJSON file")
    parser.add_argument("--table", required=True, help="Target Iceberg table name")
    parser.add_argument("--polaris-endpoint", required=True, help="Polaris catalog endpoint")
    parser.add_argument("--s3-bucket", required=True, help="S3 bucket name")
    parser.add_argument("--aws-region", default="us-west-2", help="AWS region")
    parser.add_argument("--h3-resolution", type=int, default=5, help="H3 resolution (default: 5)")
    
    args = parser.parse_args()
    
    # Validate input file exists
    if not Path(args.input).exists():
        print(f"Error: Input file not found: {args.input}")
        sys.exit(1)
    
    load_geospatial_data(
        input_file=args.input,
        table_name=args.table,
        polaris_endpoint=args.polaris_endpoint,
        s3_bucket=args.s3_bucket,
        aws_region=args.aws_region,
        h3_resolution=args.h3_resolution
    )


if __name__ == "__main__":
    main()