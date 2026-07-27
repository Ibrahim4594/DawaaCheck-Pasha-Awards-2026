# DawaaCheck Backend

FastAPI + 10 AI agents that verify medicine authenticity from 3 photos.
Endpoint: `POST /scan/verify` streams agent progress via SSE.

## Quick start (local dev)

```bash
pip install -r requirements.txt
cp .env.example .env           # then fill in real values
uvicorn main:app --reload --port 8000
# API docs at http://localhost:8000/docs
```

## Deploy to Railway

```bash
npm i -g @railway/cli
railway login
cd backend
railway init
# Set env vars from .env.example — every key except LOG_LEVEL is required
railway up
railway domain                 # get your public URL
```

Full deploy playbook: [../docs/pitch/production-deploy-checklist.md](../docs/pitch/production-deploy-checklist.md)

## Structure

```
backend/
├── main.py              # FastAPI app, 5 routers, CORS, rate-limit
├── agents/              # 10 agents (RAKIB → HAKIM) + crew_config.py
├── routers/             # scan, medicines, recalls, adr, notifications
├── data/                # JSON datasets, loaders, scrapers, migrations
└── utils/               # supabase_client, cache, image_utils, auth
```

## Scan flow (3 phases, SSE-streamed)

1. **Phase 1 (parallel):** agents 1-5 — registration, barcode, recall, ingredients, price
2. **Re-enrich:** Supabase lookups with Phase 1 results
3. **Phase 2 (parallel):** agents 7-10 — AMR guard, pediatric, ADR, interactions
4. **Phase 3:** agent 6 (HAKIM) synthesizes final verdict + risk score

## Cost model (Anthropic API)

At 1000 scans/day:
- Agents 1, 2, 4 use Opus 4.6 Vision (~$0.03 per agent call × 3 = $0.09 per scan)
- Agents 3, 5, 7-10 use Sonnet ($0.01 per call × 7 = $0.07 per scan)
- Agent 6 synthesis uses Opus ($0.05 per scan)
- **Total: ~$0.21 per scan × 1000 = $210/day at full scale**

For the P@SHA demo (<100 scans/month), cost is ~$10/month.

## Rate limiting

`slowapi` is configured for 10 req/min per IP on `/scan/verify` to prevent abuse.
See `main.py` for the limiter setup.
