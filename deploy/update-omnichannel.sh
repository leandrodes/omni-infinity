#!/bin/bash
# Atualiza o Omni-Channel Infinity (núcleo). É um atalho para o update.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/update.sh" "$@"
