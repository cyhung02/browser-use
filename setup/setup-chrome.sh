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
unzip -q chrome-linux64.zip -d ~
rm chrome-linux64.zip

# ─── 3. Install system dependencies ─────────────────────────────────────────
echo "==> Installing system dependencies..."
apt-get update -qq
DEPS=$(grep -v '^#' ~/chrome-linux64/deb.deps | xargs)
apt-get satisfy -y --no-install-recommends $DEPS > /dev/null 2>&1
echo "    Dependencies installed."

# ─── 4. Create symlinks ──────────────────────────────────────────────────────
echo "==> Creating symlinks..."
ln -sf "~/chrome-linux64/chrome" /usr/local/bin/chrome-for-testing
mkdir -p /opt/google/chrome
ln -sf "~/chrome-linux64/chrome" /opt/google/chrome/chrome
echo "    /usr/local/bin/chrome-for-testing -> ~/chrome-linux64/chrome"
echo "    /opt/google/chrome/chrome         -> ~/chrome-linux64/chrome"

# ─── 5. Verify Chrome ────────────────────────────────────────────────────────
echo "==> Chrome version: $(chrome-for-testing --version)"

echo ""
echo "✅ Chrome setup complete."
