"""Quick test for the DawaaCheck scan pipeline with a real medicine image."""

import base64
import json
import httpx
from PIL import Image
import io


def create_test_medicine_image(text: str, filename: str) -> str:
    """Create a simple test image with medicine text and return base64."""
    img = Image.new("RGB", (400, 300), color=(255, 255, 255))
    # We'll just use a white image with embedded text context
    # The Claude Vision API will see a blank label - that's fine for testing the pipeline
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def main():
    print("=" * 60)
    print("DawaaCheck Full Scan Pipeline Test")
    print("=" * 60)

    # Create simple test images (white rectangles - Claude Vision will analyze them)
    front_b64 = create_test_medicine_image("Panadol 500mg - Front", "front.png")
    back_b64 = create_test_medicine_image("Panadol 500mg - Back", "back.png")

    payload = {
        "front_image": front_b64,
        "back_image": back_b64,
        "ingredients_image": None,
        "user_id": "test-user-001",
        "patient_type": "adult",
        "current_medicines": ["Aspirin"],
    }

    print(f"\nSending scan request to http://localhost:8000/scan/verify")
    print(f"  Front image: {len(front_b64)} chars (base64)")
    print(f"  Back image:  {len(back_b64)} chars (base64)")
    print(f"  Patient: adult")
    print(f"  Current medicines: ['Aspirin']")
    print()

    try:
        with httpx.Client(timeout=120.0) as client:
            with client.stream(
                "POST",
                "http://localhost:8000/scan/verify",
                json=payload,
            ) as response:
                print(f"Status: {response.status_code}")
                print("-" * 60)

                for line in response.iter_lines():
                    if not line:
                        continue

                    if line.startswith("event:"):
                        event_type = line.split(":", 1)[1].strip()
                        continue

                    if line.startswith("data:"):
                        data_str = line.split(":", 1)[1].strip()
                        if not data_str:
                            continue
                        try:
                            data = json.loads(data_str)

                            if event_type == "status":
                                print(f"[SYSTEM] {data.get('message', '')}")

                            elif event_type == "agent_update":
                                agent = data.get("agent", "?")
                                status = data.get("status", "?")
                                agent_data = data.get("data", {})
                                name = agent_data.get("agent_name", f"Agent {agent}")
                                msg = agent_data.get("display_message", "")[:100]
                                print(f"  Agent {agent} ({name}): {status}")
                                if msg:
                                    print(f"    -> {msg}")

                            elif event_type == "verdict":
                                print("\n" + "=" * 60)
                                print("FINAL VERDICT")
                                print("=" * 60)
                                print(f"  Verdict:    {data.get('overall_verdict', 'N/A')}")
                                print(f"  Confidence: {data.get('confidence_score', 0):.1%}")
                                print(f"  Summary:    {data.get('verdict_summary', 'N/A')[:200]}")
                                print(f"  Message:    {data.get('consumer_message', 'N/A')[:200]}")

                                errors = data.get("errors", [])
                                if errors:
                                    print(f"\n  Errors ({len(errors)}):")
                                    for err in errors:
                                        print(f"    - Agent {err['agent']}: {err['error'][:100]}")

                                agents = data.get("agent_results", {})
                                print(f"\n  Agent Results ({len(agents)} agents):")
                                for key in sorted(agents.keys()):
                                    a = agents[key]
                                    print(f"    {key}: {a.get('agent_name', '?')} -> {a.get('status', '?')}")

                            elif event_type == "done":
                                print(f"\n[DONE] {data.get('message', 'Complete')}")

                            elif event_type == "error":
                                print(f"\n[ERROR] {data.get('message', 'Unknown error')}")
                                tb = data.get("traceback", "")
                                if tb:
                                    print(tb[-500:])

                            elif event_type == "ping":
                                pass  # keep-alive

                        except json.JSONDecodeError:
                            pass

    except httpx.ConnectError:
        print("ERROR: Cannot connect to http://localhost:8000")
        print("Make sure the backend is running: python -m uvicorn main:app --port 8000")
    except Exception as e:
        print(f"ERROR: {e}")

    print("\n" + "=" * 60)
    print("Test complete!")


if __name__ == "__main__":
    main()
