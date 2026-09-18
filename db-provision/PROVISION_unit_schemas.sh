#!/usr/bin/env bash
set -euo pipefail

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER:-root}"

args=(-h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_ADMIN_USER")
if [[ -n "${MYSQL_ADMIN_PASSWORD:-}" ]]; then
  args+=("-p${MYSQL_ADMIN_PASSWORD}")
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mysql "${args[@]}" < "$repo_root/Database/App/PROVISION_pef_unit.sql"
mysql "${args[@]}" < "$repo_root/Database/BFW/PROVISION_bfw_pef_unit.sql"

echo "Provisioned pef_unit and bfw_pef_unit."
