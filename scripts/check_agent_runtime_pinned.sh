#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PACKAGE_JSON="tools/agent-runtime/package.json"
LOCK_JSON="tools/agent-runtime/package-lock.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

if [[ ! -f "${PACKAGE_JSON}" ]]; then
  echo "Missing ${PACKAGE_JSON}." >&2
  exit 1
fi
if [[ ! -f "${LOCK_JSON}" ]]; then
  echo "Missing ${LOCK_JSON}." >&2
  exit 1
fi

pkg_version="$(jq -r '.devDependencies["@openai/codex"] // empty' "${PACKAGE_JSON}")"
if [[ -z "${pkg_version}" ]]; then
  echo "${PACKAGE_JSON}: devDependencies[\"@openai/codex\"] must be set." >&2
  exit 1
fi
case "${pkg_version}" in
  ^* | "~"* | *" "* | *"|"* | *"<"* | *">"* | *"="* )
    echo "${PACKAGE_JSON}: @openai/codex must be an exact version (no ranges): ${pkg_version}" >&2
    exit 1
    ;;
esac
if [[ ! "${pkg_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([\-+].+)?$ ]]; then
  echo "${PACKAGE_JSON}: @openai/codex version does not look like SemVer: ${pkg_version}" >&2
  exit 1
fi

lock_version="$(jq -r '.packages[""].devDependencies["@openai/codex"] // empty' "${LOCK_JSON}")"
if [[ "${lock_version}" != "${pkg_version}" ]]; then
  echo "${LOCK_JSON}: root devDependencies @openai/codex ${lock_version} does not match ${PACKAGE_JSON} ${pkg_version}" >&2
  exit 1
fi

installed_version="$(jq -r '.packages["node_modules/@openai/codex"].version // empty' "${LOCK_JSON}")"
if [[ "${installed_version}" != "${pkg_version}" ]]; then
  echo "${LOCK_JSON}: node_modules/@openai/codex version ${installed_version} does not match ${PACKAGE_JSON} ${pkg_version}" >&2
  exit 1
fi

resolved="$(jq -r '.packages["node_modules/@openai/codex"].resolved // empty' "${LOCK_JSON}")"
integrity="$(jq -r '.packages["node_modules/@openai/codex"].integrity // empty' "${LOCK_JSON}")"
if [[ -z "${resolved}" || -z "${integrity}" ]]; then
  echo "${LOCK_JSON}: @openai/codex must have resolved+integrity fields." >&2
  exit 1
fi

echo "Agent runtime pin check passed (@openai/codex ${pkg_version})."
