"""
Quick test script to send a push notification to all DawaaCheck users.
Usage: python test_notification.py

Requires firebase-service-account.json in the backend/ folder.
"""

import firebase_admin
from firebase_admin import credentials, messaging

# Initialize Firebase Admin
cred = credentials.Certificate("firebase-service-account.json")
firebase_admin.initialize_app(cred)

print("Firebase Admin initialized successfully!")
print()

# Send to the 'all_users' topic (all app users are subscribed)
message = messaging.Message(
    notification=messaging.Notification(
        title="DawaaCheck Alert",
        body="Welcome to DawaaCheck! Your medicine safety guardian is now active. Scan any medicine to verify its authenticity.",
    ),
    data={
        "route": "/home",
        "type": "welcome",
    },
    topic="all_users",
)

try:
    response = messaging.send(message)
    print(f"Notification sent successfully!")
    print(f"Message ID: {response}")
except Exception as e:
    print(f"Error sending notification: {e}")
