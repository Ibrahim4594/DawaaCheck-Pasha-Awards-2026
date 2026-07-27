"""Firebase ID token verification for DawaaCheck API."""

import logging
import os
from typing import Optional

from fastapi import Depends, HTTPException, Header, status

logger = logging.getLogger(__name__)

# ── Lazy Firebase Admin init (shared with notifications router) ──────────────

_firebase_initialized = False


def _ensure_firebase():
    """Initialize Firebase Admin SDK once (if not already done)."""
    global _firebase_initialized
    if _firebase_initialized:
        return

    import firebase_admin
    from firebase_admin import credentials

    if firebase_admin._apps:
        _firebase_initialized = True
        return

    cred_path = os.getenv(
        "GOOGLE_APPLICATION_CREDENTIALS",
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "secrets", "firebase-service-account.json"),
    )
    if os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    else:
        # Try default credentials (Cloud Run, GCE, etc.)
        firebase_admin.initialize_app()

    _firebase_initialized = True


async def get_current_user(authorization: str = Header(default=None)) -> dict:
    """Verify Firebase ID token from Authorization header.

    Returns the decoded token dict with uid, email, etc.
    Raises 401 if token is missing or invalid.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    _ensure_firebase()
    from firebase_admin import auth

    try:
        token = authorization.split(" ", 1)[1] if " " in authorization else authorization
        decoded = auth.verify_id_token(token)
        return decoded
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired — please sign in again",
        )
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        )
    except Exception as e:
        logger.warning("Auth verification failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
        )


async def get_optional_user(authorization: str = Header(default=None)) -> Optional[dict]:
    """Optional auth — returns None for guest users instead of 401.

    Use this for endpoints that work for both authenticated and guest users.
    """
    if not authorization:
        return None

    _ensure_firebase()
    from firebase_admin import auth

    try:
        token = authorization.split(" ", 1)[1] if " " in authorization else authorization
        decoded = auth.verify_id_token(token)
        return decoded
    except Exception:
        logger.debug("Optional auth token verification failed")
        return None
