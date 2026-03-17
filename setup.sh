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

python3 - <<'PYEOF'
import os, json, shutil

src = "/root/.playwright"
candidate = os.environ["PWD"]
dst = os.path.join(candidate, ".playwright")
shutil.copytree(src, dst, dirs_exist_ok=True)

config_path = os.path.join(dst, "cli.config.json")
with open(config_path, "r") as f:
    config = json.load(f)

launch = config["browser"]["launchOptions"]
launch.pop("channel", None)
launch["args"] = ["--no-sandbox"]
launch["executablePath"] = os.path.expanduser("~/chrome-linux64/chrome")

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
print(f"    cli.config.json updated at {config_path}")
PYEOF

# ─── 7. Initialize playwright-cli workspace ───────────────────────────────────
echo "==> Initializing playwright-cli workspace..."
playwright-cli install --skills

echo ""
echo "✅ playwright-cli setup complete. Test with: playwright-cli open https://example.com"
