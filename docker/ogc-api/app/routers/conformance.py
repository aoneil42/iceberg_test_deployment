"""
OGC API Features - Conformance router
"""
from fastapi import APIRouter
from app.models import ConformanceClasses

router = APIRouter()


@router.get("/conformance", response_model=ConformanceClasses, tags=["Capabilities"])
async def get_conformance():
    """
    OGC API - Features conformance declaration
    
    Lists the OGC API conformance classes that this server implements
    """
    return ConformanceClasses(
        conformsTo=[
            "http://www.opengis.net/spec/ogcapi-features-1/1.0/conf/core",
            "http://www.opengis.net/spec/ogcapi-features-1/1.0/conf/oas30",
            "http://www.opengis.net/spec/ogcapi-features-1/1.0/conf/geojson",
            "http://www.opengis.net/spec/ogcapi-common-1/1.0/conf/core",
            "http://www.opengis.net/spec/ogcapi-common-2/1.0/conf/collections"
        ]
    )