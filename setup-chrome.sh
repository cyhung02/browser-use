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
unzip -q chrome-linux64.zip
rm chrome-linux64.zip

# ─── 3. Install system dependencies ─────────────────────────────────────────
echo "==> Installing system dependencies..."
apt-get update -qq
while read pkg; do
  apt-get satisfy -y --no-install-recommends "$pkg" > /dev/null 2>&1
done < chrome-linux64/deb.deps
echo "    Dependencies installed."

# ─── 4. Create symlinks ──────────────────────────────────────────────────────
echo "==> Creating symlinks..."
ln -sf "$PWD/chrome-linux64/chrome" /usr/local/bin/chrome-for-testing
mkdir -p /opt/google/chrome
ln -sf "$PWD/chrome-linux64/chrome" /opt/google/chrome/chrome
echo "    /usr/local/bin/chrome-for-testing -> $PWD/chrome-linux64/chrome"
echo "    /opt/google/chrome/chrome         -> $PWD/chrome-linux64/chrome"

# ─── 5. Verify Chrome ────────────────────────────────────────────────────────
echo "==> Chrome version: $(chrome-for-testing --version)"

# ─── 6. Configure playwright-cli ─────────────────────────────────────────────
echo "==> Configuring playwright-cli..."
mkdir -p .playwright

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

with open(".playwright/cli.config.json", "w") as f:
    json.dump(config, f, indent=2)
print("    Written to .playwright/cli.config.json")
PYEOF

# ─── 7. Initialize playwright-cli workspace ───────────────────────────────────
echo "==> Initializing playwright-cli workspace..."
playwright-cli install --skills

echo ""
echo "✅ Setup complete. Test with: playwright-cli open https://example.com"
