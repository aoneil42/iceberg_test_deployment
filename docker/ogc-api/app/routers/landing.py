"""
OGC API Features - Landing page router
"""
from fastapi import APIRouter, Request
from app.models import LandingPage, Link
from app.config import settings

router = APIRouter()


@router.get("/", response_model=LandingPage, tags=["Capabilities"])
async def get_landing_page(request: Request):
    """
    OGC API - Features landing page
    
    Provides links to the API capabilities
    """
    base_url = str(request.base_url).rstrip("/")
    
    return LandingPage(
        title=settings.SERVICE_TITLE,
        description=settings.SERVICE_DESCRIPTION,
        links=[
            Link(
                href=f"{base_url}/",
                rel="self",
                type="application/json",
                title="This document"
            ),
            Link(
                href=f"{base_url}/api/docs",
                rel="service-desc",
                type="text/html",
                title="API documentation"
            ),
            Link(
                href=f"{base_url}/conformance",
                rel="conformance",
                type="application/json",
                title="Conformance declaration"
            ),
            Link(
                href=f"{base_url}/collections",
                rel="data",
                type="application/json",
                title="Collections"
            )
        ]
    )