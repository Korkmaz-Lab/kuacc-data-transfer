#!/usr/bin/env bash
# Download a WeTransfer multi-file ZIP directly on KUACC, with resumable curl.
set -Eeuo pipefail

usage() {
  printf 'Usage: bash %s "https://we.tl/TRANSFER" "/approved/project/directory"\n' "$(basename "$0")" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
LINK=$1
DEST=$2

case "$LINK" in
  https://we.tl/*|https://wetransfer.com/*) ;;
  *) printf 'Error: expected an HTTPS WeTransfer link.\n' >&2; exit 2 ;;
esac

for program in python3 curl unzip sha256sum; do
  command -v "$program" >/dev/null 2>&1 || {
    printf 'Error: %s is not available.\n' "$program" >&2
    exit 1
  }
done

python3 -c 'import requests' >/dev/null 2>&1 || {
  printf 'Error: Python requests is missing. Ask KUACC support or install into your approved environment.\n' >&2
  exit 1
}

mkdir -p -- "$DEST"
DEST=$(cd -- "$DEST" && pwd -P)
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kuacc-data-transfer"
mkdir -p -- "$CACHE_DIR"
HELPER="$CACHE_DIR/transferwee.py"

# The helper is downloaded once. Review the upstream project before using it.
if [[ ! -s "$HELPER" ]]; then
  temp_helper=$(mktemp "$CACHE_DIR/transferwee.XXXXXXXX")
  trap 'rm -f -- "${temp_helper:-}"' EXIT
  curl -fsSL --retry 3 \
    'https://raw.githubusercontent.com/iamleot/transferwee/master/transferwee.py' \
    -o "$temp_helper"
  mv -f -- "$temp_helper" "$HELPER"
  trap - EXIT
fi

# Distinguish archives from different WeTransfer links in the same directory.
link_id=$(printf '%s' "$LINK" | sha256sum | cut -c 1-12)
archive="$DEST/wetransfer_${link_id}.zip"
partial="$archive.part"

if [[ -e "$archive" ]]; then
  if unzip -tq "$archive" >/dev/null; then
    printf 'Already downloaded and ZIP-verified: %s\n' "$archive"
    exit 0
  fi
  printf 'Error: existing archive failed ZIP validation; not overwriting: %s\n' "$archive" >&2
  exit 1
fi

direct_url=$(python3 "$HELPER" download -g "$LINK")
if [[ "$direct_url" != https://* || "$direct_url" == *$'\n'* ]]; then
  printf 'Error: no valid direct download URL was returned. The link may be expired.\n' >&2
  exit 1
fi

printf 'Downloading WeTransfer ZIP directly to KUACC: %s\n' "$archive"
# -C - resumes a partial file if the remote server supports HTTP byte ranges.
# On failure, the .part file is intentionally retained for a later retry.
curl -fL -C - --retry 10 --retry-delay 5 -o "$partial" "$direct_url"

printf 'Checking ZIP integrity (may take a while for large archives)...\n'
if ! unzip -tq "$partial"; then
  printf 'Error: ZIP validation failed. Partial file retained; do not extract it.\n' >&2
  exit 1
fi

mv -- "$partial" "$archive"
printf 'Success: downloaded and ZIP-verified: %s\n' "$archive"
printf 'If FASTQ MD5 checksums were provided, verify them after extraction.\n'
