#!/usr/bin/env bash
set -euo pipefail

valid=$1
malformed=$2
export HOME="$TMPDIR/catalogs"
export APERTURE_OPENCODE_CONFIG="$HOME/opencode.json"
export APERTURE_HERMES_CONFIG="$HOME/config.yaml"
APERTURE_AGENT_CONFIG_URL="file://$valid" aperture-agent-config-sync
cp "$APERTURE_OPENCODE_CONFIG" "$TMPDIR/opencode-good.json"
cp "$APERTURE_HERMES_CONFIG" "$TMPDIR/hermes-good.yaml"

case_index=0
while IFS='|' read -r label tool filter; do
  case_index=$((case_index + 1))
  response="$TMPDIR/response-$case_index.json"
  jq --arg tool "$tool" ".configs[\$tool] |= (fromjson | $filter | tojson)" "$valid" >"$response"

  before=$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")
  APERTURE_AGENT_CONFIG_URL="file://$response" aperture-agent-config-sync
  if [ "$before" != "$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")" ]; then
    echo "$label overwrote a working pair" >&2
    exit 1
  fi

  fresh_opencode="$TMPDIR/fresh-$case_index/opencode.json"
  fresh_hermes="$TMPDIR/fresh-$case_index/config.yaml"
  if APERTURE_AGENT_CONFIG_URL="file://$response" \
    APERTURE_OPENCODE_CONFIG="$fresh_opencode" \
    APERTURE_HERMES_CONFIG="$fresh_hermes" aperture-agent-config-sync; then
    echo "$label accepted on first activation" >&2
    exit 1
  fi
  test ! -e "$fresh_opencode"
  test ! -e "$fresh_hermes"

  if [ "$tool" = opencode ]; then
    jq "$filter" "$TMPDIR/opencode-good.json" >"$APERTURE_OPENCODE_CONFIG"
  else
    yq -o=json '.' "$TMPDIR/hermes-good.yaml" | jq "$filter" | yq -o=yaml -P '.' >"$APERTURE_HERMES_CONFIG"
  fi
  before=$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")
  if APERTURE_AGENT_CONFIG_URL="file://$malformed" aperture-agent-config-sync; then
    echo "$label accepted as a last-known-good fallback" >&2
    exit 1
  fi
  test "$before" = "$(sha256sum "$APERTURE_OPENCODE_CONFIG" "$APERTURE_HERMES_CONFIG")"
  cp "$TMPDIR/opencode-good.json" "$APERTURE_OPENCODE_CONFIG"
  cp "$TMPDIR/hermes-good.yaml" "$APERTURE_HERMES_CONFIG"
  echo "$label: refresh, bootstrap and fallback passed"
done <<'CASES'
no-enabled-providers|opencode|.enabled_providers = []
missing-enabled-provider|opencode|.enabled_providers -= ["aperture-openai"]
disabled-required-provider|opencode|.disabled_providers = ["aperture-openai"]
missing-opencode-model|opencode|del(.provider["aperture-openai"].models["openai/gpt-5.6-sol"])
null-opencode-model|opencode|.provider["aperture-openai"].models["openai/gpt-5.6-sol"] = null
missing-hermes-provider|hermes|del(.providers["aperture-responses"])
invalid-hermes-catalog-type|hermes|.providers["aperture-responses"].models = "openai/gpt-5.6-sol"
disabled-hermes-aggregator|hermes|.providers["aperture-responses"].enabled = false
disabled-hermes-anthropic|hermes|.providers["aperture-claude"].enabled = false
disabled-hermes-completions|hermes|.providers["aperture-completions"].enabled = false
quoted-disabled-hermes-provider|hermes|.providers["aperture-responses"].enabled = " FALSE "
null-enabled-hermes-provider|hermes|.providers["aperture-responses"].enabled = null
CASES
