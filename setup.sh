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

# ─── 6. Configure playwright-cli via environment variables ───────────────────
echo "==> Configuring playwright-cli..."

{
  echo "export PLAYWRIGHT_MCP_EXECUTABLE_PATH=\"$HOME/chrome-linux64/chrome\""
  echo "export PLAYWRIGHT_MCP_SANDBOX=false"
  echo "export PLAYWRIGHT_MCP_IGNORE_HTTPS_ERRORS=true"
} >> ~/.bashrc

export PLAYWRIGHT_MCP_EXECUTABLE_PATH="$HOME/chrome-linux64/chrome"
export PLAYWRIGHT_MCP_SANDBOX=false
export PLAYWRIGHT_MCP_IGNORE_HTTPS_ERRORS=true

echo "    Environment variables written to ~/.bashrc"

# ─── 7. Initialize playwright-cli workspace ───────────────────────────────────
echo "==> Initializing playwright-cli workspace..."
playwright-cli install --skills

echo ""
echo "✅ playwright-cli setup complete. Test with: playwright-cli open https://example.com"
