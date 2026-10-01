#!/usr/bin/env python3
"""Generate a non-plaintext personal TestFlight credential payload.

The bundled wrapping key makes this recoverable by an IPA recipient. This is
obfuscation for private testing, not a way to protect a shared production key.
Never print the credential, and never commit the generated file.
"""
import base64
import json
import os
from pathlib import Path
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

AAD = b"localClaw.default-provider.v1"
OUTPUT = Path(__file__).resolve().parents[1] / "src/ios/default_mount/localclaw-bootstrap.json"


def generate(api_key: str) -> dict:
    if not api_key.strip():
        raise ValueError("LOCALCLAW_DEEPSEEK_API_KEY must be set as an Xcode Cloud secret")
    key = AESGCM.generate_key(bit_length=256)
    nonce = os.urandom(12)
    plaintext = json.dumps({"apiKey": api_key.strip()}).encode()
    sealed = nonce + AESGCM(key).encrypt(nonce, plaintext, AAD)
    return {
        "wrappingKey": base64.b64encode(key).decode(),
        "sealed": base64.b64encode(sealed).decode(),
    }


def main() -> int:
    api_key = os.environ.get("LOCALCLAW_DEEPSEEK_API_KEY", "")
    if not api_key.strip():
        OUTPUT.unlink(missing_ok=True)
        print("Missing Xcode Cloud secret LOCALCLAW_DEEPSEEK_API_KEY; default-provider build aborted.", file=sys.stderr)
        return 1
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    temporary = OUTPUT.with_suffix(".tmp")
    temporary.write_text(json.dumps(generate(api_key)) + "\n")
    temporary.chmod(0o600)
    temporary.replace(OUTPUT)
    print("Encrypted localClaw default-provider payload generated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
