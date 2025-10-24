"""
Pydantic models for OGC API Features
"""
from pydantic import BaseModel, Field, HttpUrl
from typing import List, Optional, Dict, Any, Union
from datetime import datetime
from enum import Enum


class LinkRelation(str, Enum):
    """Link relation types"""
    SELF = "self"
    ALTERNATE = "alternate"
    SERVICE_DESC = "service-desc"
    SERVICE_DOC = "service-doc"
    CONFORMANCE = "conformance"
    DATA = "data"
    COLLECTION = "collection"
    ITEMS = "items"


class Link(BaseModel):
    """OGC API Link object"""
    href: str
    rel: str
    type: Optional[str] = None
    title: Optional[str] = None
    hreflang: Optional[str] = None


class Extent(BaseModel):
    """Spatial and temporal extent"""
    spatial: Dict[str, Any] = Field(
        default_factory=lambda: {
            "bbox": [[-180, -90, 180, 90]],
            "crs": "http://www.opengis.net/def/crs/OGC/1.3/CRS84"
        }
    )
    temporal: Optional[Dict[str, Any]] = Field(
        default_factory=lambda: {
            "interval": [[None, None]]
        }
    )


class Collection(BaseModel):
    """OGC API Collection object"""
    id: str
    title: Optional[str] = None
    description: Optional[str] = None
    links: List[Link]
    extent: Optional[Extent] = None
    itemType: str = "feature"
    crs: List[str] = Field(
        default_factory=lambda: ["http://www.opengis.net/def/crs/OGC/1.3/CRS84"]
    )
    storageCrs: str = "http://www.opengis.net/def/crs/OGC/1.3/CRS84"


class Collections(BaseModel):
    """Collections response"""
    links: List[Link]
    collections: List[Collection]


class LandingPage(BaseModel):
    """OGC API Landing Page"""
    title: str
    description: str
    links: List[Link]


class ConformanceClasses(BaseModel):
    """Conformance declaration"""
    conformsTo: List[str]


class Feature(BaseModel):
    """GeoJSON Feature"""
    type: str = "Feature"
    id: Optional[Union[str, int]] = None
    geometry: Optional[Dict[str, Any]] = None
    properties: Optional[Dict[str, Any]] = None
    links: Optional[List[Link]] = None


class FeatureCollection(BaseModel):
    """GeoJSON FeatureCollection"""
    type: str = "FeatureCollection"
    features: List[Feature]
    links: List[Link]
    timeStamp: Optional[datetime] = None
    numberMatched: Optional[int] = None
    numberReturned: int