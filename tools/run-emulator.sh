#!/usr/bin/env bash
# Compatibility entry → USER play path (offline PRG + windowed c64m).
#
# For agents debugging via the remote API, use:
#   tools/agent_session.py
#
# See agents/README.md (User path vs Agent path).

set -euo pipefail
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${TOOLS_DIR}/play.sh" "$@"
