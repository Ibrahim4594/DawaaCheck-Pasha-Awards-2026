import time
import logging

logger = logging.getLogger(__name__)


def retry_api_call(func, max_retries=2, initial_delay=2.0):
    """Retry an API call with exponential backoff on 429/503/529 errors."""
    for attempt in range(max_retries + 1):
        try:
            return func()
        except Exception as exc:
            error_str = str(exc).lower()
            is_retryable = any(code in error_str for code in ['429', '503', '529', 'overloaded', 'rate_limit'])
            if not is_retryable or attempt == max_retries:
                raise
            delay = initial_delay * (2 ** attempt)
            logger.warning("API call failed (attempt %d/%d), retrying in %.1fs: %s", attempt + 1, max_retries + 1, delay, exc)
            time.sleep(delay)
