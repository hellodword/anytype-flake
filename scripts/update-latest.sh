#!/usr/bin/env bash

set +e

update_hash() {
    pkg="$1"
    repo="$2"
    base="$3"

    while true
    do
        result="$(nix build .#"$pkg" 2>&1)"
        if [ $? -eq 0 ]; then
            break
        fi

        hashes=( $(echo "$result" | grep -A2 'error: hash mismatch' | grep -oP 'sha256-.{44}') )
        if [ ${#hashes[@]} -ne 2 ]; then
            echo "$result"
            exit 1
        fi
        echo "$pkg" upgrading "${hashes[0]}" to "${hashes[1]}"
        find "$base" -type f -name "*.json" -exec sed -i "s@${hashes[0]}@${hashes[1]}@" {} \;
    done
}

update() {
    pkg="$1"
    repo="$2"
    base="$3"

    version_current="$(jq -r '.rev' "$base/src.json")"
    version_latest="$(curl -fsS -w "%{redirect_url}" -o /dev/null "https://github.com/$repo/releases/latest" | grep -oP '(?<=/releases/tag/)[^/]+$')"

    if [ -z "$version_current" ]; then
        echo "no version_current"
        exit 1
    fi
    if [ -z "$version_latest" ]; then
        echo "no version_latest"
        exit 1
    fi
    if [ "$version_current" != "$version_latest" ]; then
        echo "$pkg $version_current -> $version_latest"
        echo "$(jq ".rev = \"$version_latest\"" "$base/src.json")" > "$base/src.json"
        echo "$(jq ".version = \"$version_latest\"" "$base/src.json")" > "$base/src.json"
        # echo "$(jq ".hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"" "$base/src.json")" > "$base/src.json"

        update_hash "$pkg" "$repo" "$base"
        find "$base" -type f -name "*.json" -exec git add {} \;
        git commit -m "chore[bot]: $pkg $version_current -> $version_latest"
    fi
}

# <pkg>/<github repo>/<base dir>
items=(
    "tantivy-go;anyproto/tantivy-go;tantivy-go"
    "anytype-heart;anyproto/anytype-heart;anytype-heart"
    "anytype;anyproto/anytype-ts;anytype"
)

for item in "${items[@]}"
do
    IFS=";" read -r -a arr <<< "${item}"
    pkg="${arr[0]}"
    repo="${arr[1]}"
    base="${arr[2]}"
    echo updating "$pkg"
    update "$pkg" "$repo" "$base"
done
