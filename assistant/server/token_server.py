"""Token service for a PRIVATE Percy agent (optional).

Only needed after running `setup_agent.py --private`. The app asks this
service for a short-lived conversation token instead of connecting with the
agent id alone, so only your app (not anyone who finds the agent id) can use
your ElevenLabs credits. The API key stays here, never in the app.

Run on your PC for testing (phone on the same Wi-Fi):
    pip install -r assistant/requirements.txt
    $env:ELEVENLABS_API_KEY = "your key"
    $env:ELEVENLABS_AGENT_ID = "agent_xxx"
    $env:PERCIPERE_APP_KEY = "any long random text"   # optional shared secret
    uvicorn assistant.server.token_server:app --host 0.0.0.0 --port 8787

Then build the app with
    --dart-define=ELEVENLABS_TOKEN_URL=http://<your PC's IP>:8787/assistant/token
(and --dart-define=ELEVENLABS_APP_KEY=<the same text> if you set one).
For real use, put it behind HTTPS (e.g. with the web admin app).
"""

from __future__ import annotations

import os

import requests
from fastapi import FastAPI, Header, HTTPException

API = "https://api.elevenlabs.io/v1/convai/conversation/token"

app = FastAPI(title="Percipere assistant token service")


@app.get("/assistant/token")
def conversation_token(x_percipere_key: str | None = Header(default=None)) -> dict:
    """Returns {"token": "..."} for one conversation (valid about 10 minutes)."""
    expected = os.environ.get("PERCIPERE_APP_KEY")
    if expected and x_percipere_key != expected:
        raise HTTPException(status_code=401, detail="unknown app")
    key = os.environ.get("ELEVENLABS_API_KEY")
    agent_id = os.environ.get("ELEVENLABS_AGENT_ID")
    if not key or not agent_id:
        raise HTTPException(status_code=500, detail="server not configured")
    try:
        response = requests.get(
            API, params={"agent_id": agent_id}, headers={"xi-api-key": key}, timeout=15
        )
    except requests.RequestException as e:
        raise HTTPException(status_code=502, detail=f"ElevenLabs unreachable: {e}") from e
    if response.status_code != 200:
        raise HTTPException(status_code=502, detail=f"ElevenLabs said {response.status_code}")
    token = response.json().get("token")
    if not token:
        raise HTTPException(status_code=502, detail="no token in the answer")
    return {"token": token}


@app.get("/health")
def health() -> dict:
    return {"ok": True}
