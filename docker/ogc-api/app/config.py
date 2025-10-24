"""
Configuration management for OGC API Features service
"""
from pydantic_settings import BaseSettings
from typing import Optional
import os


class Settings(BaseSettings):
    """Application settings"""
    
    # Service configuration
    SERVICE_TITLE: str = "Geospatial Platform OGC API Features"
    SERVICE_DESCRIPTION: str = "OGC API Features implementation for querying geospatial data"
    SERVICE_VERSION: str = "1.0.0"
    
    # AWS configuration
    AWS_REGION: str = os.getenv("AWS_REGION", "us-west-2")
    S3_BUCKET: str = os.getenv("S3_BUCKET", "")
    DYNAMODB_TABLE: str = os.getenv("DYNAMODB_TABLE", "")
    
    # Polaris configuration
    POLARIS_ENDPOINT: str = os.getenv("POLARIS_ENDPOINT", "http://polaris:8181")
    POLARIS_CATALOG: str = "polaris"
    
    # Query configuration
    DEFAULT_LIMIT: int = 1000
    MAX_LIMIT: int = 10000
    H3_RESOLUTION: int = 5
    
    # DuckDB configuration
    DUCKDB_THREADS: int = 2
    DUCKDB_MEMORY_LIMIT: str = "2GB"
    
    # Feature flags
    ENABLE_GEOARROW: bool = True
    ENABLE_DIRECT_S3_ACCESS: bool = False
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Global settings instance
settings = Settings()