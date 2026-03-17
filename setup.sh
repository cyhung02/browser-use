#!/usr/bin/env bash
set -euo pipefail

# ─── 1. Download Chrome for Testing (Stable) ───────────────────────────────
echo "==> Fetching Chrome for Testing stable download URLs..."
CHROME_JSON=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json)
CHROME_URL=$(echo "$CHROME_JSON" | jq -r '.channels.Stable.downloads.chrome[] | select(.platform == "linux64") | .url')
echo "    Chrome URL: $CHROME_URL"

echo "==> Downloading Chrome for Testing..."
curl -O "$CHROME_URL"

# ─── 2. Extract ─────────────────────────────────────────────────────────────
echo "==> Extracting chrome-linux64.zip..."
unzip -oq chrome-linux64.zip -d ~
rm chrome-linux64.zip

# ─── 3. Install system dependencies ─────────────────────────────────────────
echo "==> Installing system dependencies..."
apt-get update -qq
DEPS=$(grep -v '^#' ~/chrome-linux64/deb.deps | paste -sd ',')
apt-get satisfy -y --no-install-recommends "$DEPS" > /dev/null 2>&1
echo "    Dependencies installed."

# ─── 4. Verify Chrome ────────────────────────────────────────────────────────
echo "==> Chrome version: $("$HOME/chrome-linux64/chrome" --version --no-sandbox)"

echo ""
echo "✅ Chrome setup complete."

# ─── 5. Install playwright-cli ───────────────────────────────────────────────
echo "==> Installing playwright-cli..."
npm install -g @playwright/cli

# ─── 6. Configure playwright-cli ─────────────────────────────────────────────
echo "==> Configuring playwright-cli..."
mkdir -p ~/.playwright

python3 - <<'PYEOF'
import urllib.parse, os, json

config = {
  "browser": {
    "browserName": "chromium",
    "launchOptions": {
      "channel": "chrome",
      "executablePath": os.path.expanduser("~/chrome-linux64/chrome"),
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
