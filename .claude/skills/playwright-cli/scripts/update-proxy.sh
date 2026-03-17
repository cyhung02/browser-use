#!/bin/bash
# Updates /root/.playwright/cli.config.json proxy settings from $HTTP_PROXY.
# Run this before creating any playwright-cli session to ensure the proxy is current.

set -e

CONFIG_PATH="/root/.playwright/cli.config.json"

if [ -z "$HTTP_PROXY" ]; then
  echo "WARNING: HTTP_PROXY is not set, skipping proxy update"
  exit 0
fi

python3 - <<'EOF'
import os, json
from urllib.parse import urlparse

proxy_url = os.environ.get("HTTP_PROXY", "")
parsed = urlparse(proxy_url)

server   = f"{parsed.scheme}://{parsed.hostname}:{parsed.port}"
username = parsed.username or ""
password = parsed.password or ""

config_path = "/root/.playwright/cli.config.json"
try:
    with open(config_path, "r") as f:
        config = json.load(f)
except FileNotFoundError:
    config = {}

config.setdefault("browser", {})
config["browser"].setdefault("launchOptions", {})
config["browser"]["launchOptions"].setdefault("chromiumSandbox", False)
config["browser"]["launchOptions"]["proxy"] = {
    "server": server,
    "username": username,
    "password": password,
}
config["browser"].setdefault("contextOptions", {})
config["browser"]["contextOptions"]["ignoreHTTPSErrors"] = True

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"Proxy updated: {server} (username: {username[:30]}...)")
EOF
