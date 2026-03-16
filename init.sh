#!/bin/bash
set -euo pipefail

# Install
pip install "browser-use[cli]"
echo "Installed browser-use[cli]\n" >> ~/init.log
playwright install chromium --with-deps
echo "Installed chromium\n" >> ~/init.log

# Write proxy config from HTTP_PROXY
PROXY_CONFIG="$HOME/.browser_use_proxy.json"
_proxy="${HTTP_PROXY}"
_no_scheme="${_proxy#http://}"
_userinfo="${_no_scheme%@*}"
_hostport="${_no_scheme##*@}"

python3 -c "
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    'server': 'http://${_hostport}',
    'username': '${_userinfo%%:*}',
    'password': '${_userinfo#*:}',
}, indent=2) + '\n')
" "$PROXY_CONFIG"
echo "Wrote $PROXY_CONFIG\n" >> ~/init.log

# Patch browser_use to read proxy from config file
TARGET="/usr/local/lib/python3.11/dist-packages/browser_use/skill_cli/sessions.py"

if grep -q '_proxy_from_config' "$TARGET"; then
	echo "Already patched — nothing to do."
else
	python3 - "$TARGET" <<'PYEOF'
import pathlib, re, sys, textwrap

p = pathlib.Path(sys.argv[1])
src = p.read_text()

# 1) Insert _proxy_from_config() before async def create_browser_session
indent_to_tabs = lambda s: re.sub(r"(?m)^( {4})+", lambda m: "\t" * (len(m.group()) // 4), s)
PROXY_FUNC = indent_to_tabs(textwrap.dedent("""\
def _proxy_from_config() -> 'ProxySettings | None':
    \"\"\"Load proxy settings from ~/.browser_use_proxy.json, or return None.\"\"\"
    import json
    from pathlib import Path
    from browser_use.browser.profile import ProxySettings

    cfg_path = Path.home() / '.browser_use_proxy.json'
    if not cfg_path.is_file():
        return None

    cfg = json.loads(cfg_path.read_text())
    if not cfg.get('server'):
        return None

    return ProxySettings(
        server=cfg['server'],
        bypass=cfg.get('bypass'),
        username=cfg.get('username') or None,
        password=cfg.get('password') or None,
    )


"""))

marker = "async def create_browser_session("
assert marker in src, f"Cannot find: {marker}"
src = src.replace(marker, PROXY_FUNC + marker, 1)

# 2) Insert proxy = _proxy_from_config() before the first "if mode" in create_browser_session
func_start = src.index(marker)
mode_match = re.search(r"^\tif mode\b", src[func_start:], re.MULTILINE)
assert mode_match, "Cannot find 'if mode' dispatch in create_browser_session"
pos = func_start + mode_match.start()
src = src[:pos] + "\tproxy = _proxy_from_config()\n\n" + src[pos:]

# 3) Add proxy=proxy to every BrowserSession(...) that contains headless=not headed
prev = src
src = re.sub(
    r"(return BrowserSession\(.*?headless=not headed[^\n]*\n)(\t+)(\))",
    lambda m: f"{m[1]}{m[2]}\tproxy=proxy,\n{m[2]}\tdisable_security=True,\n{m[2]}{m[3]}",
    src,
    flags=re.DOTALL,
)
assert src != prev, "Failed to add proxy=proxy to any BrowserSession"

# 4) Verify patched file is valid Python
compile(src, str(p), "exec")

p.write_text(src)
PYEOF
	echo "Patched $TARGET\n" >> ~/init.log
fi

# Install browser-use skill
mkdir -p ~/.claude/skills/browser-use
curl -o ~/.claude/skills/browser-use/SKILL.md \
  https://raw.githubusercontent.com/browser-use/browser-use/main/skills/browser-use/SKILL.md
echo "Installed skill\n" >> ~/init.log
