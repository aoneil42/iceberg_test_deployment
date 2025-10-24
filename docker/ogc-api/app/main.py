"""
OGC API Features service for querying Iceberg tables with geospatial data
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging

from app.config import settings
from app.routers import landing, conformance, collections

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create FastAPI app
app = FastAPI(
    title="OGC API Features - Geospatial Platform",
    description="OGC API Features service for querying geospatial data stored in Apache Iceberg tables",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)

# Include routers
app.include_router(landing.router)
app.include_router(conformance.router)
app.include_router(collections.router)

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "ogc-api-features"}

# Exception handlers
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Global exception handler caught: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "code": "InternalServerError",
            "description": "An internal server error occurred"
        }
    )

@app.on_event("startup")
async def startup_event():
    """Startup event handler"""
    logger.info(f"Starting OGC API Features service")
    logger.info(f"Polaris catalog endpoint: {settings.POLARIS_ENDPOINT}")
    logger.info(f"S3 bucket: {settings.S3_BUCKET}")
    logger.info(f"AWS region: {settings.AWS_REGION}")

@app.on_event("shutdown")
async def shutdown_event():
    """Shutdown event handler"""
    logger.info("Shutting down OGC API Features service")