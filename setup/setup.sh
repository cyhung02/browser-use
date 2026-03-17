#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(pwd)"

bash "$SCRIPT_DIR/setup-chrome.sh"
bash "$SCRIPT_DIR/setup-playwright-cli.sh"
