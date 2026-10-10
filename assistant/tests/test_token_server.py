"""Checks token_server.py with ElevenLabs faked (run: python -m unittest discover assistant/tests)."""

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

try:
    from fastapi.testclient import TestClient
except ImportError:  # fastapi/httpx not installed: skip
    TestClient = None


@unittest.skipIf(TestClient is None, "pip install -r assistant/requirements.txt httpx")
class TokenServerTest(unittest.TestCase):
    def setUp(self):
        from assistant.server import token_server

        self.server = token_server
        self.client = TestClient(token_server.app)

    def env(self, **values):
        return mock.patch.dict(os.environ, values, clear=False)

    def test_returns_a_token(self):
        answer = mock.Mock(status_code=200)
        answer.json.return_value = {"token": "tok-1"}
        with self.env(ELEVENLABS_API_KEY="k", ELEVENLABS_AGENT_ID="agent_1", PERCIPERE_APP_KEY=""), \
                mock.patch.object(self.server.requests, "get", return_value=answer) as get:
            response = self.client.get("/assistant/token")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"token": "tok-1"})
        self.assertEqual(get.call_args.kwargs["params"], {"agent_id": "agent_1"})
        self.assertEqual(get.call_args.kwargs["headers"], {"xi-api-key": "k"})

    def test_app_key_is_checked(self):
        with self.env(ELEVENLABS_API_KEY="k", ELEVENLABS_AGENT_ID="agent_1", PERCIPERE_APP_KEY="secret"):
            self.assertEqual(self.client.get("/assistant/token").status_code, 401)

    def test_not_configured(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(self.client.get("/assistant/token").status_code, 500)


if __name__ == "__main__":
    unittest.main()
