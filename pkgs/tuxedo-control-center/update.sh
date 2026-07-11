#!/usr/bin/env nix-shell
#! nix-shell -i bash -p prefetch-npm-deps nix-prefetch-github curl

set -eu -o pipefail

if [ "$#" -ne 1 ]; then
    >&2 echo "Error: Missing version parameter"
    >&2 echo
    >&2 echo "Usage: $0 tcc-version"
    >&2 echo
    >&2 echo "Example:"
    >&2 echo "$0 3.0.6"

    exit 1
fi

TUXEDO_VERSION="$1"
TUXEDO_SRC_URL="https://raw.githubusercontent.com/tuxedocomputers/tuxedo-control-center/v${TUXEDO_VERSION}"

WORKDIR=$(mktemp -d)
trap 'rm -r "$WORKDIR"' EXIT

curl -f "$TUXEDO_SRC_URL/package-lock.json" > "$WORKDIR/package-lock.json"

echo "Computing src hash..."
SRC_HASH=$(nix-prefetch-github --json tuxedocomputers tuxedo-control-center --rev "v${TUXEDO_VERSION}" | python3 -c "import json,sys; print(json.load(sys.stdin)['hash'])")

echo "Computing npmDepsHash..."
NPM_DEPS_HASH=$(prefetch-npm-deps "$WORKDIR/package-lock.json")

echo
echo "src hash:      $SRC_HASH"
echo "npmDepsHash:   $NPM_DEPS_HASH"
echo
echo "Update default.nix with:"
echo "  version = \"${TUXEDO_VERSION}\";"
echo "  hash = \"$SRC_HASH\";"
echo "  npmDepsHash = \"$NPM_DEPS_HASH\";"
