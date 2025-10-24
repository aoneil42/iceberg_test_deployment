"""
DuckDB client for querying Iceberg tables via Polaris catalog
"""
import duckdb
import logging
from typing import List, Dict, Any, Optional, Tuple
from contextlib import contextmanager
import h3
import json

from app.config import settings

logger = logging.getLogger(__name__)


class DuckDBClient:
    """DuckDB client with Iceberg and spatial support"""
    
    def __init__(self):
        self.connection = None
        self._initialize_connection()
    
    def _initialize_connection(self):
        """Initialize DuckDB connection with extensions"""
        try:
            logger.info("Initializing DuckDB connection")
            
            # Create in-memory database
            self.connection = duckdb.connect(":memory:")
            
            # Configure DuckDB
            self.connection.execute(f"SET threads={settings.DUCKDB_THREADS}")
            self.connection.execute(f"SET memory_limit='{settings.DUCKDB_MEMORY_LIMIT}'")
            
            # Install and load extensions
            logger.info("Installing DuckDB extensions...")
            self.connection.execute("INSTALL iceberg")
            self.connection.execute("INSTALL spatial")
            self.connection.execute("INSTALL httpfs")
            self.connection.execute("INSTALL h3 FROM community")
            
            self.connection.execute("LOAD iceberg")
            self.connection.execute("LOAD spatial")
            self.connection.execute("LOAD httpfs")
            self.connection.execute("LOAD h3")
            
            # Configure AWS credentials (uses instance role)
            self.connection.execute(f"SET s3_region='{settings.AWS_REGION}'")
            
            # Attach Iceberg catalog
            logger.info(f"Attaching Polaris catalog: {settings.POLARIS_ENDPOINT}")
            catalog_sql = f"""
            CREATE OR REPLACE CATALOG {settings.POLARIS_CATALOG}
            FROM iceberg(
                'rest',
                uri='{settings.POLARIS_ENDPOINT}/v1/{settings.POLARIS_CATALOG}'
            )
            """
            self.connection.execute(catalog_sql)
            
            logger.info("DuckDB initialized successfully")
            
        except Exception as e:
            logger.error(f"Failed to initialize DuckDB: {e}", exc_info=True)
            raise
    
    def list_tables(self) -> List[str]:
        """List all tables in the catalog"""
        try:
            query = f"""
            SELECT table_name 
            FROM {settings.POLARIS_CATALOG}.information_schema.tables
            WHERE table_schema = 'default'
            """
            result = self.connection.execute(query).fetchall()
            return [row[0] for row in result]
        except Exception as e:
            logger.error(f"Error listing tables: {e}")
            return []
    
    def get_table_schema(self, table_name: str) -> List[Dict[str, str]]:
        """Get schema for a table"""
        try:
            query = f"""
            SELECT column_name, data_type
            FROM {settings.POLARIS_CATALOG}.information_schema.columns
            WHERE table_schema = 'default' AND table_name = '{table_name}'
            """
            result = self.connection.execute(query).fetchall()
            return [{"name": row[0], "type": row[1]} for row in result]
        except Exception as e:
            logger.error(f"Error getting schema for {table_name}: {e}")
            return []
    
    def get_table_extent(self, table_name: str, geom_column: str = "geometry") -> Optional[Tuple[float, float, float, float]]:
        """Get spatial extent (bbox) of a table"""
        try:
            query = f"""
            SELECT 
                MIN(ST_XMin(ST_GeomFromWKB({geom_column}))) as minx,
                MIN(ST_YMin(ST_GeomFromWKB({geom_column}))) as miny,
                MAX(ST_XMax(ST_GeomFromWKB({geom_column}))) as maxx,
                MAX(ST_YMax(ST_GeomFromWKB({geom_column}))) as maxy
            FROM {settings.POLARIS_CATALOG}.default.{table_name}
            """
            result = self.connection.execute(query).fetchone()
            if result and all(x is not None for x in result):
                return result
            return None
        except Exception as e:
            logger.warning(f"Could not compute extent for {table_name}: {e}")
            return None
    
    def bbox_to_h3_cells(self, bbox: Tuple[float, float, float, float]) -> List[str]:
        """Convert bbox to H3 cells for partition pruning"""
        minx, miny, maxx, maxy = bbox
        
        # Create polygon from bbox
        coords = [
            [minx, miny],
            [maxx, miny],
            [maxx, maxy],
            [minx, maxy],
            [minx, miny]
        ]
        
        # Get H3 cells covering the polygon
        # Note: h3.polygon_to_cells expects GeoJSON polygon format
        try:
            cells = h3.polygon_to_cells(
                {"type": "Polygon", "coordinates": [coords]},
                settings.H3_RESOLUTION
            )
            return list(cells)
        except Exception as e:
            logger.warning(f"Error converting bbox to H3 cells: {e}")
            return []
    
    def query_features(
        self,
        table_name: str,
        bbox: Optional[Tuple[float, float, float, float]] = None,
        limit: int = 1000,
        offset: int = 0,
        properties: Optional[List[str]] = None,
        geom_column: str = "geometry"
    ) -> List[Dict[str, Any]]:
        """Query features from a table"""
        try:
            # Build SELECT clause
            if properties:
                select_cols = ", ".join(properties)
            else:
                select_cols = "*"
            
            # Build WHERE clause
            where_clauses = []
            
            if bbox:
                # Convert bbox to H3 cells for partition pruning
                h3_cells = self.bbox_to_h3_cells(bbox)
                if h3_cells:
                    cells_str = "', '".join(h3_cells)
                    where_clauses.append(f"h3_cell IN ('{cells_str}')")
                
                # Add spatial filter
                minx, miny, maxx, maxy = bbox
                bbox_wkt = f"POLYGON(({minx} {miny}, {maxx} {miny}, {maxx} {maxy}, {minx} {maxy}, {minx} {miny}))"
                where_clauses.append(
                    f"ST_Intersects(ST_GeomFromWKB({geom_column}), ST_GeomFromText('{bbox_wkt}'))"
                )
            
            where_clause = " AND ".join(where_clauses) if where_clauses else "1=1"
            
            # Build query
            query = f"""
            SELECT {select_cols},
                   ST_AsText(ST_GeomFromWKB({geom_column})) as geom_wkt
            FROM {settings.POLARIS_CATALOG}.default.{table_name}
            WHERE {where_clause}
            LIMIT {limit}
            OFFSET {offset}
            """
            
            logger.info(f"Executing query: {query}")
            result = self.connection.execute(query).fetchall()
            
            # Get column names
            columns = [desc[0] for desc in self.connection.description]
            
            # Convert to list of dicts
            features = []
            for row in result:
                feature_dict = dict(zip(columns, row))
                features.append(feature_dict)
            
            return features
            
        except Exception as e:
            logger.error(f"Error querying features from {table_name}: {e}", exc_info=True)
            return []
    
    def query_features_arrow(
        self,
        table_name: str,
        bbox: Optional[Tuple[float, float, float, float]] = None,
        limit: int = 1000,
        offset: int = 0
    ):
        """Query features and return as Arrow table"""
        try:
            where_clauses = []
            
            if bbox:
                h3_cells = self.bbox_to_h3_cells(bbox)
                if h3_cells:
                    cells_str = "', '".join(h3_cells)
                    where_clauses.append(f"h3_cell IN ('{cells_str}')")
                
                minx, miny, maxx, maxy = bbox
                bbox_wkt = f"POLYGON(({minx} {miny}, {maxx} {miny}, {maxx} {maxy}, {minx} {maxy}, {minx} {miny}))"
                where_clauses.append(
                    f"ST_Intersects(ST_GeomFromWKB(geometry), ST_GeomFromText('{bbox_wkt}'))"
                )
            
            where_clause = " AND ".join(where_clauses) if where_clauses else "1=1"
            
            query = f"""
            SELECT *
            FROM {settings.POLARIS_CATALOG}.default.{table_name}
            WHERE {where_clause}
            LIMIT {limit}
            OFFSET {offset}
            """
            
            return self.connection.execute(query).arrow()
            
        except Exception as e:
            logger.error(f"Error querying Arrow features: {e}", exc_info=True)
            return None
    
    def close(self):
        """Close connection"""
        if self.connection:
            self.connection.close()


# Global client instance
_client: Optional[DuckDBClient] = None


def get_duckdb_client() -> DuckDBClient:
    """Get or create DuckDB client singleton"""
    global _client
    if _client is None:
        _client = DuckDBClient()
    return _client
            