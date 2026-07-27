"""Shared Supabase client singleton for the DawaaCheck backend."""

import os
from functools import lru_cache

from supabase import create_client, Client


@lru_cache(maxsize=1)
def get_supabase() -> Client:
    """Return a shared Supabase client. Raises if credentials are missing."""
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")
    if not url or not key:
        raise RuntimeError(
            "SUPABASE_URL and SUPABASE_KEY must be set in environment variables"
        )
    return create_client(url, key)


def sanitize_like(value: str) -> str:
    """Escape SQL LIKE/ILIKE wildcard characters in user-supplied values.

    Prevents pattern injection when building ilike filters for Supabase.
    """
    return value.replace("\\", "\\\\").replace("%", r"\%").replace("_", r"\_")
