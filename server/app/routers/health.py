"""Liveness, and enough detail to tell two deploys apart."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from ..catalog import catalog
from ..config import Settings, get_settings
from ..schemas import Health

router = APIRouter(prefix="/v1", tags=["health"])


@router.get("/health", response_model=Health, summary="Is the service up")
def health(settings: Settings = Depends(get_settings)) -> Health:
    return Health(release=settings.release, packs=len(catalog))
