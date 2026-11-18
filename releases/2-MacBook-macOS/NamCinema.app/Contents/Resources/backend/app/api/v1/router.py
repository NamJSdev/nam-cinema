from fastapi import APIRouter

from app.api.v1 import auth, catalog, library, playback

api_v1_router = APIRouter(prefix="/api/v1")
api_v1_router.include_router(auth.router)
api_v1_router.include_router(catalog.router)
api_v1_router.include_router(playback.router)
api_v1_router.include_router(library.router)
