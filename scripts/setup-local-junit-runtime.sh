#!/usr/bin/env bash
set -euo pipefail

backend_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "${backend_dir}/.." && pwd)"
demo_home="${1:-${repo_root}/.local/DXC/DEMO}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${repo_root}/.local/gradle-home}"
gradle_cmd="${GRADLE_CMD:-./gradlew}"

mkdir -p \
  "${demo_home}/release/bin" \
  "${demo_home}/release/ctl" \
  "${demo_home}/release/lib" \
  "${demo_home}/release/cron" \
  "${demo_home}/shared/TMA/templates" \
  "${demo_home}/shared/TMA/data/input" \
  "${demo_home}/shared/TMA/data/output" \
  "${demo_home}/shared/TMA/data/download" \
  "${demo_home}/shared/TMA/data/archive/success" \
  "${demo_home}/shared/TMA/data/archive/error" \
  "${demo_home}/shared/TMA/excel/upload/success" \
  "${demo_home}/shared/TMA/excel/upload/error" \
  "${demo_home}/shared/TMA/interface/tmp" \
  "${demo_home}/shared/tmp/poifiles" \
  "${demo_home}/log"

(
  cd "${backend_dir}"
  ${gradle_cmd} :jConfig:processResources :batch-resource:processResources \
    -Papp.homepath="${demo_home}" \
    -Papp.home="${demo_home}" \
    --rerun-tasks
)

echo "Local JUnit runtime is ready at: ${demo_home}"
echo
echo "Run JUnit with the same path override, for example:"
echo "  cd ${backend_dir}"
echo "  ${gradle_cmd} :jBatch:test -Papp.homepath=${demo_home} -Papp.home=${demo_home} --tests '*CPEF222UploadGoodPartQuantityPartFromMatsTest'"
echo
echo "If the wrapper cannot download Gradle, rerun this script with: GRADLE_CMD=gradle"
