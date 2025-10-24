"""
OGC API Features - Collections router
"""
from fastapi import APIRouter, Request, Query, HTTPException, Response
from fastapi.responses import StreamingResponse
from typing import Optional, List
from datetime import datetime
import json
import pyarrow as pa
import logging

from app.models import Collections, Collection, Link, Extent, FeatureCollection, Feature
from app.duckdb_client import get_duckdb_client
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


@router.get("/collections", response_model=Collections, tags=["Collections"])
async def get_collections(request: Request):
    """
    List all available feature collections (Iceberg tables)
    """
    base_url = str(request.base_url).rstrip("/")
    client = get_duckdb_client()
    
    tables = client.list_tables()
    
    collections = []
    for table_name in tables:
        extent_bbox = client.get_table_extent(table_name)
        
        extent = Extent(
            spatial={
                "bbox": [list(extent_bbox) if extent_bbox else [-180, -90, 180, 90]],
                "crs": "http://www.opengis.net/def/crs/OGC/1.3/CRS84"
            }
        )
        
        collection = Collection(
            id=table_name,
            title=table_name.replace("_", " ").title(),
            description=f"Geospatial features from {table_name} Iceberg table",
            links=[
                Link(
                    href=f"{base_url}/collections/{table_name}",
                    rel="self",
                    type="application/json",
                    title=f"{table_name} metadata"
                ),
                Link(
                    href=f"{base_url}/collections/{table_name}/items",
                    rel="items",
                    type="application/geo+json",
                    title=f"{table_name} features"
                )
            ],
            extent=extent
        )
        collections.append(collection)
    
    return Collections(
        links=[
            Link(
                href=f"{base_url}/collections",
                rel="self",
                type="application/json"
            )
        ],
        collections=collections
    )


@router.get("/collections/{collection_id}", response_model=Collection, tags=["Collections"])
async def get_collection(collection_id: str, request: Request):
    """
    Get metadata for a specific collection
    """
    base_url = str(request.base_url).rstrip("/")
    client = get_duckdb_client()
    
    tables = client.list_tables()
    if collection_id not in tables:
        raise HTTPException(status_code=404, detail=f"Collection {collection_id} not found")
    
    extent_bbox = client.get_table_extent(collection_id)
    
    extent = Extent(
        spatial={
            "bbox": [list(extent_bbox) if extent_bbox else [-180, -90, 180, 90]],
            "crs": "http://www.opengis.net/def/crs/OGC/1.3/CRS84"
        }
    )
    
    return Collection(
        id=collection_id,
        title=collection_id.replace("_", " ").title(),
        description=f"Geospatial features from {collection_id} Iceberg table",
        links=[
            Link(
                href=f"{base_url}/collections/{collection_id}",
                rel="self",
                type="application/json"
            ),
            Link(
                href=f"{base_url}/collections/{collection_id}/items",
                rel="items",
                type="application/geo+json"
            )
        ],
        extent=extent
    )


@router.get("/collections/{collection_id}/items", tags=["Features"])
async def get_features(
    collection_id: str,
    request: Request,
    bbox: Optional[str] = Query(None, description="Bounding box: minx,miny,maxx,maxy"),
    limit: int = Query(settings.DEFAULT_LIMIT, ge=1, le=settings.MAX_LIMIT),
    offset: int = Query(0, ge=0),
    properties: Optional[str] = Query(None, description="Comma-separated list of properties"),
    f: Optional[str] = Query("json", description="Output format: json or arrow")
):
    """
    Get features from a collection
    
    Supports both GeoJSON and GeoArrow output formats
    """
    base_url = str(request.base_url).rstrip("/")
    client = get_duckdb_client()
    
    # Validate collection exists
    tables = client.list_tables()
    if collection_id not in tables:
        raise HTTPException(status_code=404, detail=f"Collection {collection_id} not found")
    
    # Parse bbox
    bbox_tuple = None
    if bbox:
        try:
            coords = [float(x) for x in bbox.split(",")]
            if len(coords) != 4:
                raise ValueError("bbox must have 4 values")
            bbox_tuple = tuple(coords)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid bbox parameter: {e}")
    
    # Parse properties
    props_list = None
    if properties:
        props_list = [p.strip() for p in properties.split(",")]
    
    # Handle GeoArrow format
    accept_header = request.headers.get("accept", "")
    if f == "arrow" or "application/vnd.apache.arrow" in accept_header:
        if not settings.ENABLE_GEOARROW:
            raise HTTPException(status_code=400, detail="GeoArrow format not enabled")
        
        arrow_table = client.query_features_arrow(
            table_name=collection_id,
            bbox=bbox_tuple,
            limit=limit,
            offset=offset
        )
        
        if arrow_table is None:
            raise HTTPException(status_code=500, detail="Error generating Arrow response")
        
        # Serialize to IPC format
        sink = pa.BufferOutputStream()
        with pa.ipc.new_stream(sink, arrow_table.schema) as writer:
            writer.write_table(arrow_table)
        
        buffer = sink.getvalue()
        
        return Response(
            content=buffer.to_pybytes(),
            media_type="application/vnd.apache.arrow.stream"
        )
    
    # Handle GeoJSON format (default)
    features_data = client.query_features(
        table_name=collection_id,
        bbox=bbox_tuple,
        limit=limit,
        offset=offset,
        properties=props_list
    )
    
    # Convert to GeoJSON features
    features = []
    for feat_data in features_data:
        geom_wkt = feat_data.pop("geom_wkt", None)
        
        # Parse WKT to GeoJSON geometry
        geometry = None
        if geom_wkt:
            geometry = wkt_to_geojson(geom_wkt)
        
        # Remove internal columns
        properties = {k: v for k, v in feat_data.items() if k not in ["geometry", "h3_cell"]}
        
        feature = Feature(
            type="Feature",
            id=feat_data.get("id"),
            geometry=geometry,
            properties=properties
        )
        features.append(feature)
    
    # Build response links
    self_link = f"{base_url}/collections/{collection_id}/items"
    if bbox:
        self_link += f"?bbox={bbox}"
    if limit != settings.DEFAULT_LIMIT:
        self_link += f"&limit={limit}"
    
    links = [
        Link(href=self_link, rel="self", type="application/geo+json")
    ]
    
    # Add next link if more results available
    if len(features) == limit:
        next_offset = offset + limit
        next_link = f"{base_url}/collections/{collection_id}/items?offset={next_offset}&limit={limit}"
        if bbox:
            next_link += f"&bbox={bbox}"
        links.append(Link(href=next_link, rel="next", type="application/geo+json"))
    
    return FeatureCollection(
        type="FeatureCollection",
        features=features,
        links=links,
        timeStamp=datetime.utcnow(),
        numberReturned=len(features)
    )


def wkt_to_geojson(wkt: str) -> dict:
    """Convert WKT geometry to GeoJSON"""
    try:
        # Simple WKT parser for common geometry types
        wkt = wkt.strip()
        
        if wkt.startswith("POINT"):
            coords_str = wkt.replace("POINT", "").replace("(", "").replace(")", "").strip()
            coords = [float(x) for x in coords_str.split()]
            return {"type": "Point", "coordinates": coords}
        
        elif wkt.startswith("LINESTRING"):
            coords_str = wkt.replace("LINESTRING", "").replace("(", "").replace(")", "").strip()
            coords = [[float(x) for x in pair.split()] for pair in coords_str.split(",")]
            return {"type": "LineString", "coordinates": coords}
        
        elif wkt.startswith("POLYGON"):
            # Remove POLYGON and outer parens
            coords_str = wkt.replace("POLYGON", "").strip()
            coords_str = coords_str[1:-1]  # Remove outer parens
            
            # Split rings
            rings = []
            for ring_str in coords_str.split("),("):
                ring_str = ring_str.replace("(", "").replace(")", "").strip()
                ring = [[float(x) for x in pair.split()] for pair in ring_str.split(",")]
                rings.append(ring)
            
            return {"type": "Polygon", "coordinates": rings}
        
        else:
            logger.warning(f"Unsupported WKT geometry type: {wkt[:20]}")
            return None
            
    except Exception as e:
        logger.error(f"Error parsing WKT: {e}")
        return None