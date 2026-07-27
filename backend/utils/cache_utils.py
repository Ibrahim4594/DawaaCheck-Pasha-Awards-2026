"""Simple in-memory cache with TTL support for DRAP data and other lookups."""

import time
import threading
from functools import wraps
from typing import Any, Callable, TypeVar, ParamSpec

P = ParamSpec("P")
R = TypeVar("R")


class TTLCache:
    """Thread-safe in-memory key/value cache with per-entry TTL."""

    def __init__(self, default_ttl: float = 300.0) -> None:
        """
        Args:
            default_ttl: Default time-to-live in seconds for cached entries.
        """
        self._store: dict[str, tuple[Any, float]] = {}
        self._lock = threading.Lock()
        self.default_ttl = default_ttl

    def get(self, key: str) -> Any | None:
        """Return the cached value if it exists and has not expired, else None."""
        with self._lock:
            entry = self._store.get(key)
            if entry is None:
                return None
            value, expires_at = entry
            if time.monotonic() > expires_at:
                del self._store[key]
                return None
            return value

    def set(self, key: str, value: Any, ttl: float | None = None) -> None:
        """Store a value with an optional custom TTL (seconds)."""
        with self._lock:
            expires_at = time.monotonic() + (ttl if ttl is not None else self.default_ttl)
            self._store[key] = (value, expires_at)

    def invalidate(self, key: str) -> None:
        """Remove a specific key from the cache."""
        with self._lock:
            self._store.pop(key, None)

    def clear(self) -> None:
        """Remove all entries from the cache."""
        with self._lock:
            self._store.clear()

    def cleanup(self) -> int:
        """Remove all expired entries. Returns the number of entries removed."""
        now = time.monotonic()
        removed = 0
        with self._lock:
            expired_keys = [k for k, (_, exp) in self._store.items() if now > exp]
            for k in expired_keys:
                del self._store[k]
                removed += 1
        return removed


# Module-level shared cache instance
_default_cache = TTLCache()


def timed_cache(ttl_seconds: float = 300.0) -> Callable[[Callable[P, R]], Callable[P, R]]:
    """
    Decorator that caches the return value of a no-arg or simple-arg function.

    The cache key is derived from the function's qualified name and its arguments.

    Args:
        ttl_seconds: How long the cached value stays valid (in seconds).
    """

    def decorator(func: Callable[P, R]) -> Callable[P, R]:
        cache = TTLCache(default_ttl=ttl_seconds)

        @wraps(func)
        def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
            key = f"{func.__qualname__}:{repr(args)}:{repr(sorted(kwargs.items()))}"
            cached = cache.get(key)
            if cached is not None:
                return cached
            result = func(*args, **kwargs)
            cache.set(key, result)
            return result

        # Expose cache control on the wrapper
        wrapper.cache = cache  # type: ignore[attr-defined]
        return wrapper

    return decorator
