#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

runtime_dir="tools/agent-runtime"
package_json="${runtime_dir}/package.json"
lock_json="${runtime_dir}/package-lock.json"
module_package_json="${runtime_dir}/node_modules/@openai/codex/package.json"

if [[ ! -f "${package_json}" ]] || [[ ! -f "${lock_json}" ]]; then
  echo "Missing ${package_json} or ${lock_json}." >&2
  exit 1
fi

pkg_version="$(
  grep -Eo '"@openai/codex"[[:space:]]*:[[:space:]]*"[^"]+"' "${package_json}" |
    head -n 1 |
    sed -E 's|.*"@openai/codex"[[:space:]]*:[[:space:]]*"([^"]+)".*|\1|'
)"
if [[ -z "${pkg_version}" ]]; then
  echo "${package_json}: could not determine pinned @openai/codex version." >&2
  exit 1
fi

lock_version="$(
  awk '
    $0 ~ /"node_modules\/@openai\/codex"[[:space:]]*:[[:space:]]*\{/ {in_block=1; next}
    in_block && $0 ~ /"version"[[:space:]]*:/ {
      gsub(/.*"version"[[:space:]]*:[[:space:]]*"/, "", $0)
      gsub(/".*/, "", $0)
      print $0
      exit
    }
  ' "${lock_json}"
)"
if [[ -z "${lock_version}" ]]; then
  echo "${lock_json}: could not determine locked @openai/codex version." >&2
  exit 1
fi

if [[ "${pkg_version}" != "${lock_version}" ]]; then
  echo "tools/agent-runtime pin mismatch: package.json=${pkg_version} package-lock.json=${lock_version}" >&2
  exit 1
fi

if [[ -f "${module_package_json}" ]]; then
  module_version="$(
    grep -Eo '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "${module_package_json}" |
      head -n 1 |
      sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
  )"
  if [[ -z "${module_version}" ]]; then
    echo "${module_package_json}: could not determine installed @openai/codex version." >&2
    exit 1
  fi
  if [[ "${module_version}" != "${pkg_version}" ]]; then
    echo "tools/agent-runtime pin mismatch: package.json=${pkg_version} node_modules=${module_version}" >&2
    exit 1
  fi
fi

echo "tools/agent-runtime is pinned to @openai/codex@${pkg_version}"
