#!/usr/bin/env bash

# ─── 1. Download Chrome for Testing (Stable) ───────────────────────────────
echo "==> Fetching Chrome for Testing stable download URLs..." > ~/1.log
CHROME_JSON=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json)
CHROME_URL=$(echo "$CHROME_JSON" | jq -r '.channels.Stable.downloads.chrome[] | select(.platform == "linux64") | .url')
echo "    Chrome URL: $CHROME_URL"

echo "==> Downloading Chrome for Testing..."
curl -O "$CHROME_URL"

# ─── 2. Extract ─────────────────────────────────────────────────────────────
echo "==> Extracting chrome-linux64.zip..." > ~/2.log
unzip -oq chrome-linux64.zip -d ~
rm chrome-linux64.zip

# ─── 3. Install system dependencies ─────────────────────────────────────────
echo "==> Installing system dependencies..." > ~/3.log
apt-get update -qq
DEPS=$(grep -v '^#' ~/chrome-linux64/deb.deps | paste -sd ',')
apt-get satisfy -y --no-install-recommends "$DEPS" > /dev/null 2>&1
echo "    Dependencies installed."

# ─── 4. Verify Chrome ────────────────────────────────────────────────────────
echo "==> Chrome version: $("$HOME/chrome-linux64/chrome" --version --no-sandbox)" > ~/4.log

echo ""
echo "✅ Chrome setup complete."

# ─── 5. Install playwright-cli ───────────────────────────────────────────────
echo "==> Installing playwright-cli..." > ~/5.log
npm install -g @playwright/cli

# ─── 6. Initialize playwright-cli workspace ───────────────────────────────────
echo "==> Initializing playwright-cli workspace..." > ~/6.log
playwright-cli install --skills

# ─── 7. Configure playwright-cli via config file ─────────────────────────────
echo "==> Configuring playwright-cli..." > ~/7.log

python3 - <<'PYEOF'
import json, os
from urllib.parse import urlparse

dst = os.path.expanduser("~/.playwright/cli.config.json")
os.makedirs(os.path.dirname(dst), exist_ok=True)

with open(dst) as f:
    config = json.load(f)

proxy_url = os.environ.get("HTTP_PROXY", "")
parsed = urlparse(proxy_url)
proxy_server = f"{parsed.scheme}://{parsed.hostname}:{parsed.port}"

launch = config["browser"]["launchOptions"]
launch.pop("channel", None)
launch["executablePath"] = os.path.expanduser("~/chrome-linux64/chrome")
launch["args"] = ["--no-sandbox"]
launch["proxy"] = {
    "server": proxy_server,
    "username": parsed.username or "",
    "password": parsed.password or ""
}

with open(dst, "w") as f:
    json.dump(config, f, indent=2)

print(f"    Config written at {dst}")
PYEOF

echo ""
echo "✅ playwright-cli setup complete. Test with: playwright-cli open https://example.com"
