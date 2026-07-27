"""Push notification endpoints for DawaaCheck.

Sends FCM messages to individual devices or topic subscribers.
Requires GOOGLE_APPLICATION_CREDENTIALS env var pointing to the
Firebase service account JSON file.
"""

import logging
import os
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from utils.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter()

# ── Lazy Firebase Admin init ──────────────────────────────────────────────────

_firebase_app = None


def _ensure_firebase():
    """Initialize Firebase Admin SDK once."""
    global _firebase_app
    if _firebase_app is not None:
        return

    try:
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            _firebase_app = firebase_admin.get_app()
            return

        cred_path = os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS",
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "secrets", "firebase-service-account.json"),
        )
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
        else:
            # Try default credentials (Cloud Run, GCE, etc.)
            _firebase_app = firebase_admin.initialize_app()
    except Exception as e:
        logger.exception("Firebase Admin SDK initialization failed")
        raise HTTPException(
            status_code=500,
            detail="Firebase notification service unavailable. Please try again later.",
        )


# ── Request models ────────────────────────────────────────────────────────────


class SendNotificationRequest(BaseModel):
    """Send a notification to a single device token."""

    token: str
    title: str
    body: str
    data: dict = {}


class TopicNotificationRequest(BaseModel):
    """Broadcast a notification to all subscribers of a topic."""

    topic: str
    title: str
    body: str
    data: dict = {}


class RecallAlertRequest(BaseModel):
    """Send a recall alert for a specific medicine."""

    medicine_name: str
    reason: str = ""


# ── Endpoints ─────────────────────────────────────────────────────────────────


@router.post("/send")
async def send_to_device(req: SendNotificationRequest, user: dict = Depends(get_current_user)):
    """Send a push notification to a specific device."""
    _ensure_firebase()
    from firebase_admin import messaging

    message = messaging.Message(
        notification=messaging.Notification(title=req.title, body=req.body),
        data={k: str(v) for k, v in req.data.items()},
        token=req.token,
    )
    try:
        msg_id = messaging.send(message)
        return {"success": True, "message_id": msg_id}
    except Exception as e:
        logger.exception("Failed to send push notification to device")
        raise HTTPException(status_code=500, detail="Notification delivery failed. Please try again.")


@router.post("/broadcast")
async def broadcast_to_topic(req: TopicNotificationRequest, user: dict = Depends(get_current_user)):
    """Broadcast a notification to all users subscribed to a topic."""
    _ensure_firebase()
    from firebase_admin import messaging

    message = messaging.Message(
        notification=messaging.Notification(title=req.title, body=req.body),
        data={k: str(v) for k, v in req.data.items()},
        topic=req.topic,
    )
    try:
        msg_id = messaging.send(message)
        return {"success": True, "message_id": msg_id}
    except Exception as e:
        logger.exception("Failed to broadcast notification to topic")
        raise HTTPException(status_code=500, detail="Notification delivery failed. Please try again.")


@router.post("/recall-alert")
async def send_recall_alert(req: RecallAlertRequest, user: dict = Depends(get_current_user)):
    """Send a medicine recall alert to all subscribed users."""
    _ensure_firebase()
    from firebase_admin import messaging

    body = f"{req.medicine_name} has been recalled by DRAP."
    if req.reason:
        body += f" Reason: {req.reason}"
    body += " Open DawaaCheck for details."

    message = messaging.Message(
        notification=messaging.Notification(
            title="Medicine Recall Alert",
            body=body,
        ),
        data={
            "route": "/recalls",
            "medicine": req.medicine_name,
            "type": "recall_alert",
        },
        topic="recall_alerts",
    )
    try:
        msg_id = messaging.send(message)
        return {"success": True, "message_id": msg_id}
    except Exception as e:
        logger.exception("Failed to send recall alert notification")
        raise HTTPException(status_code=500, detail="Notification delivery failed. Please try again.")


@router.post("/safety-tip")
async def send_safety_tip(title: str, body: str, user: dict = Depends(get_current_user)):
    """Send a general safety tip to all users."""
    _ensure_firebase()
    from firebase_admin import messaging

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={"route": "/home", "type": "safety_tip"},
        topic="all_users",
    )
    try:
        msg_id = messaging.send(message)
        return {"success": True, "message_id": msg_id}
    except Exception as e:
        logger.exception("Failed to send safety tip notification")
        raise HTTPException(status_code=500, detail="Notification delivery failed. Please try again.")
