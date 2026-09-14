#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required to validate tools/agent-runtime pins" >&2
  exit 2
fi

want_version="$(
  node -e 'const p=require("./tools/agent-runtime/package.json"); process.stdout.write(p.devDependencies?.["@openai/codex"]||"")'
)"
if [[ -z "${want_version}" ]]; then
  echo "tools/agent-runtime/package.json missing devDependencies.@openai/codex" >&2
  exit 1
fi
if [[ "${want_version}" =~ [^0-9.] ]]; then
  echo "tools/agent-runtime/package.json must pin an exact version (got ${want_version})" >&2
  exit 1
fi

lock_version="$(
  node -e 'const l=require("./tools/agent-runtime/package-lock.json"); const p=l.packages?.["node_modules/@openai/codex"]; process.stdout.write(p?.version||"")'
)"
if [[ -z "${lock_version}" ]]; then
  echo "tools/agent-runtime/package-lock.json missing packages[\"node_modules/@openai/codex\"].version" >&2
  exit 1
fi

installed_version=""
if [[ -f tools/agent-runtime/node_modules/@openai/codex/package.json ]]; then
  installed_version="$(
    node -e 'const p=require("./tools/agent-runtime/node_modules/@openai/codex/package.json"); process.stdout.write(p.version||"")'
  )"
fi

if [[ "${want_version}" != "${lock_version}" ]]; then
  echo "agent-runtime pin mismatch: package.json wants ${want_version}, package-lock.json has ${lock_version}" >&2
  exit 1
fi
if [[ -n "${installed_version}" && "${want_version}" != "${installed_version}" ]]; then
  echo "agent-runtime pin mismatch: package.json wants ${want_version}, node_modules has ${installed_version}" >&2
  exit 1
fi

echo "tools/agent-runtime @openai/codex pinned to ${want_version}"

