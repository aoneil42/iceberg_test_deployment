-- DuckDB SQL script for ingesting GeoJSON into Iceberg
-- Usage: duckdb < ingest_geojson.sql

-- Install extensions
INSTALL spatial;
INSTALL httpfs;
INSTALL h3 FROM community;
INSTALL iceberg;

LOAD spatial;
LOAD httpfs;
LOAD h3;
LOAD iceberg;

-- Configure AWS (uses environment variables or instance role)
SET s3_region=getenv('AWS_REGION');

-- Attach Polaris catalog
CREATE OR REPLACE CATALOG polaris
FROM iceberg(
    'rest',
    uri=getenv('POLARIS_ENDPOINT') || '/v1/polaris'
);

-- Read GeoJSON file
CREATE TABLE source_data AS 
SELECT * FROM ST_Read('data/input.geojson');

-- Add H3 partition column and convert geometry to WKB
CREATE TABLE source_with_h3 AS
SELECT 
    *,
    h3_h3_to_string(
        h3_latlng_to_cell(
            ST_Y(ST_Centroid(geom)),
            ST_X(ST_Centroid(geom)),
            5  -- H3 resolution
        )
    ) as h3_cell,
    ST_AsWKB(geom) as geometry
FROM source_data;

-- Drop original geometry column
ALTER TABLE source_with_h3 DROP COLUMN geom;

-- Create Iceberg table with H3 partitioning
CREATE TABLE IF NOT EXISTS polaris.default.my_features AS
SELECT * FROM source_with_h3
PARTITION BY (h3_cell);

-- Verify data
SELECT 
    COUNT(*) as total_features,
    COUNT(DISTINCT h3_cell) as num_partitions
FROM polaris.default.my_features;

-- Show sample data
SELECT * FROM polaris.default.my_features LIMIT 5;

-- Show extent
SELECT 
    MIN(ST_XMin(ST_GeomFromWKB(geometry))) as minx,
    MIN(ST_YMin(ST_GeomFromWKB(geometry))) as miny,
    MAX(ST_XMax(ST_GeomFromWKB(geometry))) as maxx,
    MAX(ST_YMax(ST_GeomFromWKB(geometry))) as maxy
FROM polaris.default.my_features;