#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PACKAGE_JSON="tools/agent-runtime/package.json"
LOCK_JSON="tools/agent-runtime/package-lock.json"

if [[ ! -f "${PACKAGE_JSON}" ]]; then
  echo "missing ${PACKAGE_JSON}" >&2
  exit 1
fi

if [[ ! -f "${LOCK_JSON}" ]]; then
  echo "missing ${LOCK_JSON}" >&2
  exit 1
fi

python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="python3"
elif command -v python >/dev/null 2>&1; then
  python_bin="python"
else
  echo "python3 (or python) is required to validate ${PACKAGE_JSON} and ${LOCK_JSON}" >&2
  exit 1
fi

codex_version="$("${python_bin}" - <<PY
import json
with open("${PACKAGE_JSON}", "r", encoding="utf-8") as f:
    pkg = json.load(f)
print(pkg.get("devDependencies", {}).get("@openai/codex", ""))
PY
)"

if [[ -z "${codex_version}" ]]; then
  echo "${PACKAGE_JSON}: could not find @openai/codex version" >&2
  exit 1
fi

if [[ ! "${codex_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "${PACKAGE_JSON}: @openai/codex must be pinned to an exact x.y.z version (got ${codex_version})" >&2
  exit 1
fi

lock_report="$("${python_bin}" - <<PY
import json
with open("${LOCK_JSON}", "r", encoding="utf-8") as f:
    lock = json.load(f)
packages = lock.get("packages", {})
root = packages.get("", {})
root_ver = root.get("devDependencies", {}).get("@openai/codex", "")
codex = packages.get("node_modules/@openai/codex", {})
print(root_ver)
print(codex.get("version", ""))
print(codex.get("resolved", ""))
print("1" if codex.get("integrity") else "0")
optional = codex.get("optionalDependencies", {})
for suf in ["darwin-arm64","darwin-x64","linux-arm64","linux-x64","win32-arm64","win32-x64"]:
    print(optional.get(f"@openai/codex-{suf}", ""))
PY
)"

lock_root_version="$(printf '%s\n' "${lock_report}" | sed -n '1p')"
lock_node_version="$(printf '%s\n' "${lock_report}" | sed -n '2p')"
resolved="$(printf '%s\n' "${lock_report}" | sed -n '3p')"
has_integrity="$(printf '%s\n' "${lock_report}" | sed -n '4p')"

if [[ "${lock_root_version}" != "${codex_version}" ]]; then
  echo "${LOCK_JSON}: root @openai/codex version ${lock_root_version} does not match ${PACKAGE_JSON} ${codex_version}" >&2
  exit 1
fi

if [[ "${lock_node_version}" != "${codex_version}" ]]; then
  echo "${LOCK_JSON}: node_modules/@openai/codex version ${lock_node_version} does not match ${codex_version}" >&2
  exit 1
fi

if [[ -z "${resolved}" ]] || [[ ! "${resolved}" =~ ^https://registry\.npmjs\.org/@openai/codex/-/codex-${codex_version}\.tgz$ ]]; then
  echo "${LOCK_JSON}: unexpected resolved URL for @openai/codex: ${resolved}" >&2
  exit 1
fi

if [[ "${has_integrity}" != "1" ]]; then
  echo "${LOCK_JSON}: missing integrity field for @openai/codex" >&2
  exit 1
fi

line=5
for suffix in darwin-arm64 darwin-x64 linux-arm64 linux-x64 win32-arm64 win32-x64; do
  got="$(printf '%s\n' "${lock_report}" | sed -n "${line}p")"
  want="npm:@openai/codex@${codex_version}-${suffix}"
  if [[ "${got}" != "${want}" ]]; then
    echo "${LOCK_JSON}: missing optional dependency pin: @openai/codex-${suffix} -> ${want}" >&2
    exit 1
  fi
  line=$((line + 1))
done

echo "agent runtime pins ok: @openai/codex ${codex_version}"
