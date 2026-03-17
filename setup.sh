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

# ─── 4. Create symlinks ──────────────────────────────────────────────────────
echo "==> Creating symlinks..."
ln -sf "$HOME/chrome-linux64/chrome" /usr/local/bin/chrome-for-testing
mkdir -p /opt/google/chrome
ln -sf "$HOME/chrome-linux64/chrome" /opt/google/chrome/chrome
echo "    /usr/local/bin/chrome-for-testing -> ~/chrome-linux64/chrome"
echo "    /opt/google/chrome/chrome         -> ~/chrome-linux64/chrome"

# ─── 5. Verify Chrome ────────────────────────────────────────────────────────
echo "==> Chrome version: $(chrome-for-testing --version)"

echo ""
echo "✅ Chrome setup complete."

# ─── 6. Install playwright-cli ───────────────────────────────────────────────
echo "==> Installing playwright-cli..."
npm install -g @playwright/cli

# ─── 7. Configure playwright-cli ─────────────────────────────────────────────
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

# ─── 8. Initialize playwright-cli workspace ───────────────────────────────────
echo "==> Initializing playwright-cli workspace..."
playwright-cli install --skills

# ─── 9. Symlink ~/.playwright into pwd so cli.config.json is found ────────────
echo "==> Linking ~/.playwright into current workspace..."
ln -sf "$HOME/.playwright" "$(pwd)/.playwright"
echo "    $(pwd)/.playwright -> $HOME/.playwright"

echo ""
echo "✅ playwright-cli setup complete. Test with: playwright-cli open https://example.com"
