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
DEPS_LOG="/tmp/apt-deps-install.log"
echo "==> Installing system dependencies (log: $DEPS_LOG)..."
apt-get update -qq 2>&1 | tee -a "$DEPS_LOG"
DEPS=$(grep -v '^#' ~/chrome-linux64/deb.deps | paste -sd ',')
if apt-get satisfy -y --no-install-recommends "$DEPS" >> "$DEPS_LOG" 2>&1; then
    echo "    Dependencies installed."
else
    echo "ERROR: apt-get satisfy failed. Last 30 lines of log:" >&2
    tail -30 "$DEPS_LOG" >&2
    exit 1
fi

# ─── 4. Create symlinks ──────────────────────────────────────────────────────
echo "==> Creating symlinks..."
ln -sf "$HOME/chrome-linux64/chrome" /usr/local/bin/chrome-for-testing
mkdir -p /opt/google/chrome
ln -sf "$HOME/chrome-linux64/chrome" /opt/google/chrome/chrome
echo "    /usr/local/bin/chrome-for-testing -> ~/chrome-linux64/chrome"
echo "    /opt/google/chrome/chrome         -> ~/chrome-linux64/chrome"
