"""DawaaCheck FastAPI Backend - Main Application Entry Point."""

import os
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from routers import scan, recalls, medicines, adr, notifications

load_dotenv()

# Set ALLOWED_ORIGINS in .env to your deployed web origin. Defaults to local
# development ports only, so a fresh clone never trusts an unknown origin.
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",")

limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])

app = FastAPI(
    title="DawaaCheck API",
    description="AI-powered medicine verification and safety API for Pakistan",
    version="1.0.0",
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Share the app-level limiter with the scan router so slowapi can enforce limits
scan.limiter = limiter

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(scan.router, prefix="/scan", tags=["Scan & Verify"])
app.include_router(recalls.router, prefix="/recalls", tags=["DRAP Recalls"])
app.include_router(medicines.router, prefix="/medicines", tags=["Medicines"])
app.include_router(adr.router, prefix="/adr", tags=["Adverse Drug Reports"])
app.include_router(notifications.router, prefix="/notifications", tags=["Push Notifications"])


@app.get("/", tags=["Health"])
async def health_check() -> dict[str, object]:
    """
    Liveness probe, also used by the mobile client to decide whether the live
    verification pipeline is reachable before falling back to on-device checks.

    Includes verification-cache stats, since cache hit rate is the metric that
    determines both response latency and per-scan model cost.
    """
    from utils.verification_cache import stats as cache_stats

    return {
        "status": "ok",
        "service": "DawaaCheck API",
        "verification_cache": cache_stats(),
    }
