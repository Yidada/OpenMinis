# localClaw personal TestFlight default model

In Xcode Cloud's **OpenMinis Release** workflow, add the environment variable
`LOCALCLAW_DEEPSEEK_API_KEY` and mark it **Secret**. Enter the credential directly
in Apple's settings; do not commit it, paste it into logs, or store it in this file.
The post-clone script fails early if the secret is absent, so a release cannot
silently omit the requested default provider.

`generate_localclaw_bootstrap.py` creates an ignored AES-256-GCM payload inside
the existing `default_mount` bundle resource. It uses fresh randomness per build.
The runtime opens it using CryptoKit and stores the API credential in Keychain.
The decryption key accompanies the ciphertext: an IPA recipient can recover the
credential. This avoids plaintext packaging but is **not secret protection** and
is intended only for this personal TestFlight distribution.

After the provider database is loaded, an installation with no providers,
models, groups, or deleted-provider tombstones gets an OpenAI-compatible DeepSeek
provider at `https://api.deepseek.com` (with the supported `/v1` suffix) and a
`deepseek-chat` default model group. Existing user configuration is preserved.
The installation marker prevents recreating a provider after the user deletes it.

Before distributing, verify the actual Xcode Cloud Archive and ASC processing
results, add the build to Benjamin Internal, and test a fresh install's chat
request plus relaunch persistence on an iPhone. Verify separately that upgrading
an installation with existing providers preserves its configuration. No device
or iOS compilation was performed in the Linux development environment.

Linux generator checks:

```sh
python3 -m unittest discover -s scripts/tests/localclaw -v
```
