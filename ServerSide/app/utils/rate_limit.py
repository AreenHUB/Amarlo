"""
app/utils/rate_limit.py
────────────────────────
Simple in-memory sliding-window rate limiter.

Usage (in an endpoint):
    from app.utils.rate_limit import rate_limit
    rate_limit(request, key="login", max_calls=5, window_seconds=60)

No external dependencies — uses only stdlib collections + threading.
Safe for single-process uvicorn workers (the default for this project).
For multi-worker deployments, swap the store for Redis.
"""
import time
import threading
from collections import defaultdict, deque

from fastapi import HTTPException, Request

# thread-safe lock for the shared store
_lock  = threading.Lock()
# key → deque of timestamps (oldest first)
_store: dict[str, deque] = defaultdict(deque)


def _client_ip(request: Request) -> str:
    """Best-effort client IP — respects X-Forwarded-For if present."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return "unknown"


def rate_limit(
    request: Request,
    *,
    key: str,
    max_calls: int,
    window_seconds: int,
) -> None:
    """
    Raise HTTP 429 if the caller has exceeded max_calls within window_seconds.
    The rate-limit key is scoped per IP + logical key so different endpoints
    don't share quotas.
    """
    ip      = _client_ip(request)
    bucket  = f"{ip}:{key}"
    now     = time.monotonic()
    cutoff  = now - window_seconds

    with _lock:
        q = _store[bucket]
        # drop timestamps outside the window
        while q and q[0] < cutoff:
            q.popleft()

        if len(q) >= max_calls:
            retry_after = int(window_seconds - (now - q[0])) + 1
            raise HTTPException(
                status_code=429,
                detail=f"Too many requests. Try again in {retry_after} seconds.",
                headers={"Retry-After": str(retry_after)},
            )

        q.append(now)
