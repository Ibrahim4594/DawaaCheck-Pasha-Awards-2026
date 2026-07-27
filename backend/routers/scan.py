"""Scan & Verify router - accepts medicine images and streams AI agent analysis."""

import asyncio
import json
import logging
import traceback
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from slowapi import Limiter
from slowapi.util import get_remote_address
from sse_starlette.sse import EventSourceResponse

from utils.auth import get_current_user

logger = logging.getLogger(__name__)

limiter = Limiter(key_func=get_remote_address)

router = APIRouter()


class ScanRequest(BaseModel):
    """Request body for the medicine scan/verify endpoint."""

    front_image: str = Field(..., max_length=10_000_000, description="Base64-encoded front image of the medicine")
    back_image: str = Field(..., max_length=10_000_000, description="Base64-encoded back image of the medicine")
    ingredients_image: Optional[str] = Field(
        None, max_length=10_000_000, description="Base64-encoded image of the ingredients list"
    )
    user_id: str = Field(..., description="Firebase UID of the requesting user")
    patient_type: str = Field(
        "adult", description="Patient type: 'adult', 'child', 'elderly', 'pregnant'"
    )
    child_age: Optional[float] = Field(None, description="Child age in years (if patient is child)")
    child_weight: Optional[float] = Field(
        None, description="Child weight in kg (if patient is child)"
    )
    latitude: Optional[float] = Field(None, description="User latitude for location context")
    longitude: Optional[float] = Field(None, description="User longitude for location context")
    current_medicines: Optional[list[str]] = Field(
        None, description="List of medicines the user is currently taking (for interaction check)"
    )


class AgentUpdate(BaseModel):
    """An incremental update from one agent in the verification pipeline."""

    agent: str
    status: str
    message: str
    data: Optional[dict] = None


class ScanVerdict(BaseModel):
    """Final verdict returned after all agents finish."""

    verdict: str
    confidence: float
    risk_level: str
    details: dict
    recommendations: list[str]


@router.post("/verify")
@limiter.limit("5/minute")
async def verify_medicine(request: Request, scan_request: ScanRequest, user: dict = Depends(get_current_user)) -> EventSourceResponse:
    """
    Accept medicine images and stream back AI agent analysis results via SSE.

    Each agent publishes its findings as an SSE event. The final event contains
    the aggregated verdict.
    """

    async def event_generator():
        update_queue: asyncio.Queue[dict] = asyncio.Queue()

        try:
            # Send initial acknowledgement
            yield {
                "event": "status",
                "data": json.dumps(
                    {"agent": "system", "status": "started", "message": "Analysis pipeline started"}
                ),
            }

            # Run the crew in a background thread so we don't block the event loop
            loop = asyncio.get_running_loop()

            async def run_crew():
                from agents.crew_config import build_and_run_crew

                def queue_callback(agent_num: int, status: str, result: dict):
                    update_queue.put_nowait({
                        "agent": agent_num,
                        "status": status,
                        "data": result,
                    })

                result = await loop.run_in_executor(
                    None,
                    lambda: build_and_run_crew(
                        front_image_b64=scan_request.front_image,
                        back_image_b64=scan_request.back_image,
                        ingredients_image_b64=scan_request.ingredients_image or "",
                        user_id=scan_request.user_id,
                        patient_type=scan_request.patient_type,
                        child_age=scan_request.child_age,
                        child_weight=scan_request.child_weight,
                        update_callback=queue_callback,
                        current_medicines=scan_request.current_medicines,
                    ),
                )
                return result

            crew_task = asyncio.create_task(run_crew())

            # Stream intermediate updates from the queue
            while not crew_task.done():
                try:
                    update = await asyncio.wait_for(update_queue.get(), timeout=1.0)
                    yield {"event": "agent_update", "data": json.dumps(update)}
                except asyncio.TimeoutError:
                    # Send a keep-alive comment so the connection stays open
                    yield {"event": "ping", "data": ""}

            # Drain any remaining updates
            while not update_queue.empty():
                update = update_queue.get_nowait()
                yield {"event": "agent_update", "data": json.dumps(update)}

            # Get the final result
            final_result = await crew_task

            yield {
                "event": "verdict",
                "data": json.dumps(final_result),
            }

            yield {
                "event": "done",
                "data": json.dumps({"message": "Analysis complete"}),
            }

        except Exception as exc:
            logger.error("SSE scan error: %s", traceback.format_exc())
            yield {
                "event": "error",
                "data": json.dumps(
                    {
                        "agent": "system",
                        "status": "error",
                        "message": "Analysis pipeline encountered an error. Please try again.",
                    }
                ),
            }

    return EventSourceResponse(event_generator())


@router.post("/verify-json")
@limiter.limit("5/minute")
async def verify_medicine_json(request: Request, scan_request: ScanRequest, user: dict = Depends(get_current_user)) -> dict:
    """
    Non-streaming version of verify. Returns the full result as JSON.
    Used by Flutter web where SSE streaming is not supported by Dio.
    """
    try:
        from agents.crew_config import build_and_run_crew

        logger.info("Starting sync scan for user %s", scan_request.user_id)

        loop = asyncio.get_running_loop()
        result = await loop.run_in_executor(
            None,
            lambda: build_and_run_crew(
                front_image_b64=scan_request.front_image,
                back_image_b64=scan_request.back_image,
                ingredients_image_b64=scan_request.ingredients_image or "",
                user_id=scan_request.user_id,
                patient_type=scan_request.patient_type,
                child_age=scan_request.child_age,
                child_weight=scan_request.child_weight,
                current_medicines=scan_request.current_medicines,
            ),
        )

        logger.info("Scan complete. Verdict: %s", result.get("overall_verdict"))
        return result

    except Exception as exc:
        logger.error("Scan failed: %s\n%s", exc, traceback.format_exc())
        raise HTTPException(status_code=500, detail="Scan analysis failed. Please try again.")
