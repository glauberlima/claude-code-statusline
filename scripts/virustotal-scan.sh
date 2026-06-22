#!/usr/bin/env bash
set -euo pipefail

# Usage: VT_API_KEY=<key> virustotal-scan.sh <binary1> <binary2> <binary3>
# Output: one line per binary: name|malicious|total|sha256|gui_url

scan_binary() {
  local path="$1"
  local name
  name=$(basename "$path")

  echo "Uploading $name to VirusTotal..." >&2
  local upload_response http_code body
  body=$(curl -sSL \
    --request POST \
    --url "https://www.virustotal.com/api/v3/files" \
    --header "x-apikey: ${VT_API_KEY}" \
    --form "file=@${path}" \
    --write-out "\n%{http_code}")
  http_code=$(printf '%s' "$body" | tail -1)
  body=$(printf '%s' "$body" | head -n -1)
  if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    echo "Upload failed for $name (HTTP $http_code): $body" >&2
    exit 1
  fi
  upload_response="$body"

  local analysis_id
  analysis_id=$(echo "$upload_response" | jq -r '.data.id')
  if [ -z "$analysis_id" ] || [ "$analysis_id" = "null" ]; then
    echo "Failed to extract analysis_id for $name. Response: $upload_response" >&2
    exit 1
  fi

  echo "Polling analysis $analysis_id for $name..." >&2
  local attempt=0
  local max_attempts=20
  while [ $attempt -lt $max_attempts ]; do
    sleep 30
    attempt=$((attempt + 1))
    echo "  Poll attempt $attempt/$max_attempts..." >&2

    local analysis_response
    analysis_response=$(curl -fsSL \
      --request GET \
      --url "https://www.virustotal.com/api/v3/analyses/${analysis_id}" \
      --header "x-apikey: ${VT_API_KEY}")

    local status
    status=$(echo "$analysis_response" | jq -r '.data.attributes.status')
    if [ "$status" = "completed" ]; then
      local malicious total sha256 gui_url
      malicious=$(echo "$analysis_response" | jq -r '.data.attributes.stats.malicious')
      # total = sum of all stat categories
      total=$(echo "$analysis_response" | jq '[.data.attributes.stats | to_entries[].value] | add')
      sha256=$(echo "$analysis_response" | jq -r '.meta.file_info.sha256')
      gui_url="https://www.virustotal.com/gui/file/${sha256}"
      echo "${name}|${malicious}|${total}|${sha256}|${gui_url}"
      echo "Done: $name — $malicious/$total engines flagged" >&2
      return
    fi

    echo "  Status: $status" >&2
  done

  echo "Scan timeout for $name after 10 minutes" >&2
  exit 1
}

if [ $# -ne 3 ]; then
  echo "Usage: $0 <binary1> <binary2> <binary3>" >&2
  exit 1
fi

scan_binary "$1"
scan_binary "$2"
scan_binary "$3"
