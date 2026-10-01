import base64
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

spec = importlib.util.spec_from_file_location(
    "bootstrap", Path(__file__).resolve().parents[2] / "generate_localclaw_bootstrap.py")
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class BootstrapTests(unittest.TestCase):
    def test_round_trip_and_no_plaintext(self):
        credential = "synthetic-test-credential"
        envelope = bootstrap.generate(credential)
        self.assertNotIn(credential, json.dumps(envelope))
        combined = base64.b64decode(envelope["sealed"])
        key = base64.b64decode(envelope["wrappingKey"])
        decoded = AESGCM(key).decrypt(combined[:12], combined[12:], bootstrap.AAD)
        self.assertEqual(json.loads(decoded), {"apiKey": credential})

    def test_tampering_is_rejected(self):
        envelope = bootstrap.generate("synthetic-test-credential")
        combined = bytearray(base64.b64decode(envelope["sealed"]))
        combined[-1] ^= 1
        with self.assertRaises(InvalidTag):
            AESGCM(base64.b64decode(envelope["wrappingKey"])).decrypt(
                bytes(combined[:12]), bytes(combined[12:]), bootstrap.AAD)

    def test_missing_secret_fails_and_removes_stale_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "bootstrap.json"
            output.write_text("stale")
            with patch.object(bootstrap, "OUTPUT", output), patch.dict(os.environ, {}, clear=True):
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(bootstrap.main(), 1)
            self.assertFalse(output.exists())

    def test_generation_is_random_and_does_not_log_secret(self):
        secret = "synthetic-test-credential"
        self.assertNotEqual(bootstrap.generate(secret), bootstrap.generate(secret))
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "bootstrap.json"
            log = io.StringIO()
            with patch.object(bootstrap, "OUTPUT", output), patch.dict(
                os.environ, {"LOCALCLAW_DEEPSEEK_API_KEY": secret}, clear=True
            ), contextlib.redirect_stdout(log):
                self.assertEqual(bootstrap.main(), 0)
            self.assertNotIn(secret, log.getvalue())
            self.assertNotIn(secret, output.read_text())
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
