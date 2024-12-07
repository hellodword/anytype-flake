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
    # exclude alpha/beta and prerelease
    version_latest="$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        "https://api.github.com/repos/$repo/releases" | \
            jq -r 'first( .[] | select(.name | contains("beta") | not) | select(.name | contains("alpha") | not) | select(.prerelease | not) ) | .name')"

    if [ -z "$version_current" ]; then
        echo "no version_current"
        exit 1
    fi
    if [ -z "$version_latest" ]; then
        echo "no version_latest"
        exit 1
    fi
    echo "$pkg $version_current -> $version_latest"
    if [ "$version_current" != "$version_latest" ]; then
        echo "$(jq ".rev = \"$version_latest\"" "$base/src.json")" > "$base/src.json"
        echo "$(jq ".version = \"$version_latest\"" "$base/src.json")" > "$base/src.json"
        # echo "$(jq ".hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"" "$base/src.json")" > "$base/src.json"

        update_hash "$pkg" "$repo" "$base"
        find "$base" -type f -name "*.json" -exec git add {} \;
        git commit -m "chore[bot]: $pkg $version_current -> $version_latest"
    fi
}

# <pkg>;<github repo>;<base dir>
items=(
    "tantivy-go;anyproto/tantivy-go;tantivy-go"
    "anytype-heart;anyproto/anytype-heart;anytype-heart"
    "anytype;anyproto/anytype-ts;anytype"
)

commit_current="$(git rev-parse HEAD)"

for item in "${items[@]}"
do
    IFS=";" read -r -a arr <<< "${item}"
    pkg="${arr[0]}"
    repo="${arr[1]}"
    base="${arr[2]}"
    echo updating "$pkg"
    update "$pkg" "$repo" "$base"
done

commit_new="$(git rev-parse HEAD)"
if [ "$commit_current" != "$commit_new" ]; then
    nix flake check -L
fi

nix flake update nixpkgs
git add flake.lock
if git commit -m "chore: flake update nixpkgs"; then
    nix flake check -L
fi

commit_new="$(git rev-parse HEAD)"

if [ "$commit_current" != "$commit_new" ]; then
    inputs=( $(nix flake metadata --json | jq -r '.locks | .nodes[.root].inputs | keys[]') )
    for input in "${inputs[@]}"
    do
        nix flake update "$input"
        git add flake.lock
        if git commit -m "chore: flake update ($input)"; then
            nix flake check -L
        fi
    done
fi
