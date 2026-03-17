#!/usr/bin/env bash
set -euo pipefail

# ─── 1. Install playwright-cli ───────────────────────────────────────────────
echo "==> Installing playwright-cli..."
npm install -g @playwright/cli

# ─── 2. Configure playwright-cli ─────────────────────────────────────────────
echo "==> Configuring playwright-cli..."
mkdir -p ~/.playwright

python3 - <<'PYEOF'
import urllib.parse, os, json

config = {
  "browser": {
    "browserName": "chromium",
    "launchOptions": {
      "channel": "chrome",
      "chromiumSandbox": False
    },
    "contextOptions": {
      "ignoreHTTPSErrors": True
    }
  }
}

# Configure proxy from HTTP_PROXY env var if available
proxy_url = os.environ.get("HTTP_PROXY") or os.environ.get("http_proxy")
if proxy_url:
    p = urllib.parse.urlparse(proxy_url)
    proxy_config = {"server": f"{p.scheme}://{p.hostname}:{p.port}"}
    if p.username:
        proxy_config["username"] = p.username
    if p.password:
        proxy_config["password"] = p.password
    config["browser"]["launchOptions"]["proxy"] = proxy_config
    print(f"    Proxy configured: {p.scheme}://{p.hostname}:{p.port}")
else:
    print("    No HTTP_PROXY found, skipping proxy config.")

config_path = os.path.expanduser("~/.playwright/cli.config.json")
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
print(f"    Written to {config_path}")
PYEOF

# ─── 3. Initialize playwright-cli workspace ───────────────────────────────────
echo "==> Initializing playwright-cli workspace..."
playwright-cli install --skills

# ─── 4. Symlink ~/.playwright into pwd so cli.config.json is found ────────────
echo "==> Linking ~/.playwright into current workspace..."
ln -sf "$HOME/.playwright" "$(pwd)/.playwright"
echo "    $(pwd)/.playwright -> $HOME/.playwright"

echo ""
echo "✅ playwright-cli setup complete. Test with: playwright-cli open https://example.com"
