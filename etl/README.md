# ETL Scripts

This directory contains ETL scripts for loading geospatial data into Iceberg tables via DuckDB and the Polaris catalog.

## Setup

Install DuckDB and Python dependencies:

```bash
pip install -r requirements.txt
```

Or install DuckDB CLI:
- Download from https://duckdb.org/docs/installation/

## Usage

### Option 1: Python Script (Recommended)

```bash
python examples/sample_load.py \
    --input data/features.geojson \
    --table my_features \
    --polaris-endpoint http://<EC2_IP>:8181 \
    --s3-bucket <S3_BUCKET>
```

### Option 2: DuckDB SQL Scripts

```bash
# Set environment variables
export POLARIS_ENDPOINT=http://<EC2_IP>:8181
export S3_BUCKET=<your-bucket-name>
export AWS_REGION=us-west-2

# Run SQL script
duckdb < scripts/ingest_geojson.sql
```

## H3 Partitioning

All tables are partitioned by H3 cell (resolution 5) for efficient spatial queries. The ETL process:

1. Reads source geospatial data
2. Computes H3 cell for each feature's centroid
3. Writes to Iceberg table with H3 partition column
4. Polaris tracks metadata and commits transaction

## Supported Input Formats

- GeoJSON
- CSV with lat/lon columns
- GeoParquet
- Shapefile (via GDAL)
- PostGIS database

## ACID Guarantees

- Iceberg provides ACID transactions
- Each ETL run creates a new snapshot
- Failed writes don't affect existing data
- Time travel via snapshot IDs