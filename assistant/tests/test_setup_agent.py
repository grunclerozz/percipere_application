"""Checks setup_agent.py without calling ElevenLabs (run: python -m unittest discover assistant/tests)."""

import argparse
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import setup_agent  # noqa: E402


class FakeApi:
    """Records calls; pretends one tool already exists."""

    def __init__(self, refuse_language=None):
        self.calls = []
        self.refuse_language = refuse_language

    def call(self, method, path, body=None):
        self.calls.append((method, path, body))
        if method == "GET" and path == "/v1/convai/tools":
            return {"tools": [{"id": "tool_old", "tool_config": {"name": "get_screen"}}]}
        if method == "POST":
            return {"id": f"tool_{body['tool_config']['name']}"}
        if method == "PATCH" and path.startswith("/v1/convai/agents/"):
            lang = body["conversation_config"]["agent"]["language"]
            if lang == self.refuse_language:
                raise setup_agent.ApiError(422, '{"detail": "unsupported language"}')
        return {}


def args(**kw):
    base = dict(agent_id="agent_abc", voice_id="EST9Ui6982FZPSi7gCHi", max_minutes=5,
                daily_limit=30, private=False, dry_run=False)
    base.update(kw)
    return argparse.Namespace(**base)


class SetupAgentTest(unittest.TestCase):
    def test_tools_match_the_app(self):
        tools = setup_agent.load_tools()
        names = [t["name"] for t in tools]
        self.assertEqual(len(names), len(set(names)))
        self.assertIn("get_screen", names)
        for t in tools:
            self.assertEqual(t["type"], "client")
            self.assertTrue(t["expects_response"])
            self.assertEqual(t["parameters"]["type"], "object")

    def test_creates_missing_tools_and_updates_existing(self):
        api = FakeApi()
        ids = setup_agent.sync_tools(api)
        self.assertEqual(len(ids), len(setup_agent.load_tools()))
        self.assertIn("tool_old", ids)
        methods = [(m, p) for m, p, _ in api.calls]
        self.assertIn(("PATCH", "/v1/convai/tools/tool_old"), methods)
        self.assertEqual(sum(1 for m, _ in methods if m == "POST"), len(ids) - 1)

    def test_agent_settings(self):
        body = setup_agent.agent_body(args(), ["t1", "t2"], "tl")
        agent = body["conversation_config"]["agent"]
        self.assertEqual(agent["language"], "tl")
        self.assertEqual(agent["prompt"]["tool_ids"], ["t1", "t2"])
        self.assertIn("end_call", agent["prompt"]["built_in_tools"])
        self.assertIn("{{user_name}}", agent["prompt"]["prompt"])
        self.assertEqual(body["conversation_config"]["tts"]["voice_id"], "EST9Ui6982FZPSi7gCHi")
        self.assertEqual(body["conversation_config"]["tts"]["model_id"], "eleven_flash_v2_5")
        self.assertEqual(body["conversation_config"]["conversation"]["max_duration_seconds"], 300)
        override = body["platform_settings"]["overrides"]["conversation_config_override"]
        self.assertTrue(override["agent"]["language"])
        self.assertTrue(override["agent"]["first_message"])
        self.assertTrue(override["tts"]["voice_id"])
        self.assertFalse(body["platform_settings"]["auth"]["enable_auth"])
        self.assertTrue(setup_agent.agent_body(args(private=True), [], "tl")["platform_settings"]["auth"]["enable_auth"])
        json.dumps(body)  # serialisable

    def test_falls_back_to_fil_if_tl_is_refused(self):
        api = FakeApi(refuse_language="tl")
        self.assertEqual(setup_agent.update_agent(api, args(), []), "fil")


if __name__ == "__main__":
    unittest.main()
