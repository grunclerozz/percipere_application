"""Configures the ElevenLabs agent for Percipere's voice assistant ("Percy").

Run this on your PC (never in the app) after creating an agent in the
ElevenLabs dashboard. It makes the dashboard match the app:

* creates or updates the app's client tools (agent_config/tools.json),
* sets the instructions (agent_config/prompt.md), Tagalog + English, the
  voice, the end-call tool and a conversation time limit,
* allows the app to set the language, first message and voice per call
  ("overrides"),
* keeps the agent public (no server needed) unless --private is given.

Usage (Windows PowerShell):
    pip install -r assistant/requirements.txt
    $env:ELEVENLABS_API_KEY = "your key"      # never commit or share it
    python assistant/setup_agent.py            # your agent (default)
    python assistant/setup_agent.py --agent-id agent_other

Options: --voice-id, --max-minutes, --daily-limit, --private, --dry-run.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import requests

API = "https://api.elevenlabs.io"
HERE = Path(__file__).resolve().parent
CONFIG = HERE / "agent_config"

DEFAULT_AGENT_ID = "agent_1601m4b0j87se7x8tmtehq4znmas"
DEFAULT_VOICE_ID = "EST9Ui6982FZPSi7gCHi"
FIRST_MESSAGE_FIL = "Kumusta po! Ako si Percy. Ano po ang maitutulong ko?"
FIRST_MESSAGE_EN = "Hi! I'm Percy. How can I help you?"
# Agents in languages other than English need a multilingual voice model.
TTS_MODEL = "eleven_flash_v2_5"
# Filipino/Tagalog: "tl" in the Android SDK; some API versions use "fil".
LANGUAGE_CODES = ("tl", "fil")


def load_tools() -> list[dict]:
    """The client tools the app answers (same names as the Dart handlers)."""
    tools = json.loads((CONFIG / "tools.json").read_text(encoding="utf-8"))
    return [
        {
            "type": "client",
            "name": t["name"],
            "description": t["description"],
            "parameters": t["parameters"],
            "expects_response": True,
            "response_timeout_secs": 20,
        }
        for t in tools
    ]


class Api:
    """Tiny ElevenLabs REST client (the key goes only in this header)."""

    def __init__(self, key: str, dry_run: bool) -> None:
        self.session = requests.Session()
        self.session.headers.update({"xi-api-key": key, "Content-Type": "application/json"})
        self.dry_run = dry_run

    def call(self, method: str, path: str, body: dict | None = None) -> dict:
        if self.dry_run and method != "GET":
            print(f"[dry run] {method} {path}\n{json.dumps(body, ensure_ascii=False, indent=2)[:1500]}")
            return {"id": f"dry-run-{(body or {}).get('tool_config', {}).get('name', 'x')}"}
        response = self.session.request(method, f"{API}{path}", json=body, timeout=30)
        if response.status_code >= 400:
            raise ApiError(response.status_code, response.text)
        return response.json() if response.content else {}


class ApiError(Exception):
    def __init__(self, status: int, text: str) -> None:
        super().__init__(f"HTTP {status}: {text[:800]}")
        self.status = status
        self.text = text


def sync_tools(api: Api) -> list[str]:
    """Creates missing tools and updates existing ones; returns their ids."""
    existing = {}
    for tool in api.call("GET", "/v1/convai/tools").get("tools", []):
        name = tool.get("tool_config", {}).get("name")
        if name:
            existing[name] = tool["id"]
    ids = []
    for config in load_tools():
        body = {"tool_config": config}
        if config["name"] in existing:
            tool_id = existing[config["name"]]
            api.call("PATCH", f"/v1/convai/tools/{tool_id}", body)
            print(f"  updated tool {config['name']}")
        else:
            tool_id = api.call("POST", "/v1/convai/tools", body)["id"]
            print(f"  created tool {config['name']}")
        ids.append(tool_id)
    return ids


def agent_body(args: argparse.Namespace, tool_ids: list[str], language: str) -> dict:
    prompt = (CONFIG / "prompt.md").read_text(encoding="utf-8")
    return {
        "name": "Percy (Percipere)",
        "conversation_config": {
            "agent": {
                "first_message": FIRST_MESSAGE_FIL,
                "language": language,
                "dynamic_variables": {
                    "dynamic_variable_placeholders": {
                        "user_name": "kaibigan",
                        "app_language": "fil",
                    }
                },
                "prompt": {
                    "prompt": prompt,
                    "tool_ids": tool_ids,
                    "built_in_tools": {
                        "end_call": {
                            "type": "system",
                            "name": "end_call",
                            "description": (
                                "End the conversation: after handing over to the app "
                                "(open, read, scan or upload a document) or when the "
                                "user says goodbye."
                            ),
                            "params": {"system_tool_type": "end_call"},
                        }
                    },
                },
            },
            "language_presets": {
                "en": {"overrides": {"agent": {"first_message": FIRST_MESSAGE_EN}}}
            },
            "tts": {"model_id": TTS_MODEL, "voice_id": args.voice_id},
            "conversation": {"max_duration_seconds": args.max_minutes * 60},
        },
        "platform_settings": {
            "overrides": {
                "conversation_config_override": {
                    "agent": {"first_message": True, "language": True},
                    "tts": {"voice_id": True},
                }
            },
            "auth": {"enable_auth": args.private},
            "call_limits": {"daily_limit": args.daily_limit},
        },
    }


def update_agent(api: Api, args: argparse.Namespace, tool_ids: list[str]) -> str:
    last_error: ApiError | None = None
    for language in LANGUAGE_CODES:
        try:
            api.call("PATCH", f"/v1/convai/agents/{args.agent_id}", agent_body(args, tool_ids, language))
            return language
        except ApiError as e:
            # Try the other Filipino code only if the language was the problem.
            if e.status in (400, 422) and "language" in e.text.lower():
                print(f"  language '{language}' was refused, trying the next code…")
                last_error = e
                continue
            raise
    raise last_error or RuntimeError("no language code accepted")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--agent-id", default=DEFAULT_AGENT_ID, help="agent_... from the dashboard")
    parser.add_argument("--voice-id", default=DEFAULT_VOICE_ID)
    parser.add_argument("--max-minutes", type=int, default=5, help="longest conversation (protects credits)")
    parser.add_argument("--daily-limit", type=int, default=30, help="most conversations per day")
    parser.add_argument("--private", action="store_true", help="require a token from token_server.py")
    parser.add_argument("--dry-run", action="store_true", help="show what would be sent")
    args = parser.parse_args()

    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        print("Set ELEVENLABS_API_KEY first (see the top of this file).", file=sys.stderr)
        return 2
    if not args.agent_id.startswith("agent_"):
        print("That doesn't look like an agent id (it should start with 'agent_').", file=sys.stderr)
        return 2

    api = Api(key, args.dry_run)
    try:
        print("Tools:")
        tool_ids = sync_tools(api)
        print("Agent:")
        language = update_agent(api, args, tool_ids)
    except ApiError as e:
        print(f"ElevenLabs refused the request: {e}", file=sys.stderr)
        return 1
    except requests.RequestException as e:
        print(f"Couldn't reach ElevenLabs: {e}", file=sys.stderr)
        return 1

    print(f"  updated {args.agent_id}: language={language}, voice={args.voice_id}, "
          f"{len(tool_ids)} tools, max {args.max_minutes} min, "
          f"{'private' if args.private else 'public'}")
    print("\nDone. Build the app with:")
    print(f"  flutter build apk --release --dart-define=ELEVENLABS_AGENT_ID={args.agent_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
