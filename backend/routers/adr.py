"""Adverse Drug Reaction (ADR) reporting router."""

import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from utils.auth import get_current_user
from utils.supabase_client import get_supabase

logger = logging.getLogger(__name__)

router = APIRouter()


class ADRReport(BaseModel):
    """Schema for an Adverse Drug Reaction report."""

    user_id: str = Field(..., description="Firebase UID of the reporter")
    medicine_name: str = Field(..., min_length=1, description="Name of the medicine")
    generic_name: Optional[str] = Field(None, description="Generic / salt name")
    batch_number: Optional[str] = Field(None, description="Batch or lot number")
    manufacturer: Optional[str] = Field(None, description="Manufacturer name")
    reaction_description: str = Field(
        ..., min_length=10, description="Description of the adverse reaction"
    )
    severity: str = Field(
        "moderate",
        description="Severity level: 'mild', 'moderate', 'severe', 'life_threatening'",
    )
    onset_date: Optional[str] = Field(None, description="Date the reaction started (ISO 8601)")
    patient_age: Optional[float] = Field(None, description="Patient age in years")
    patient_weight: Optional[float] = Field(None, description="Patient weight in kg")
    patient_gender: Optional[str] = Field(None, description="Patient gender")
    outcome: Optional[str] = Field(
        None,
        description="Outcome: 'recovered', 'recovering', 'not_recovered', 'fatal', 'unknown'",
    )
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class ADRReportResponse(BaseModel):
    """Response returned after successfully submitting an ADR report."""

    id: str
    status: str
    message: str
    submitted_at: str


@router.post("/report", response_model=ADRReportResponse)
async def submit_adr_report(report: ADRReport, user: dict = Depends(get_current_user)) -> ADRReportResponse:
    """
    Submit an Adverse Drug Reaction report.

    The report is stored in Supabase and can later be forwarded to DRAP.
    """
    client = get_supabase()

    now = datetime.now(timezone.utc).isoformat()

    row = {
        "user_id": report.user_id,
        "medicine_name": report.medicine_name,
        "generic_name": report.generic_name,
        "batch_number": report.batch_number,
        "manufacturer": report.manufacturer,
        "reaction_description": report.reaction_description,
        "severity": report.severity,
        "onset_date": report.onset_date,
        "patient_age": report.patient_age,
        "patient_weight": report.patient_weight,
        "patient_gender": report.patient_gender,
        "outcome": report.outcome,
        "latitude": report.latitude,
        "longitude": report.longitude,
        "status": "submitted",
        "submitted_at": now,
    }

    try:
        response = client.table("adr_reports").insert(row).execute()
    except Exception as exc:
        logger.exception("Failed to save ADR report for medicine '%s'", report.medicine_name)
        raise HTTPException(status_code=500, detail="Failed to save ADR report. Please try again.") from exc

    record_id = response.data[0]["id"] if response.data else "pending"

    return ADRReportResponse(
        id=str(record_id),
        status="submitted",
        message="ADR report submitted successfully. Thank you for helping keep medicines safe.",
        submitted_at=now,
    )
