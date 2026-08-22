#!/usr/bin/env bash

# Emit a deterministic digest of an installed landscapeR package. This is an
# external identity check: it hashes the installed payload files and does not
# ask package code to report the expected revision.

set -euo pipefail

package_root=${1:?installed package directory is required}
[[ -d "$package_root" ]] || {
    printf 'payload digest: package directory is unavailable\n' >&2
    exit 2
}

hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        printf 'payload digest: no SHA-256 implementation is available\n' >&2
        exit 2
    fi
}

hash_stream() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        printf 'payload digest: no SHA-256 implementation is available\n' >&2
        exit 2
    fi
}

find "$package_root" -type f -print \
    | LC_ALL=C sort \
    | while IFS= read -r path; do
        relative=${path#"$package_root"/}
        printf '%s\t%s\n' "$relative" "$(hash_file "$path")"
    done \
    | hash_stream
