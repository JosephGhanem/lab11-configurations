#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."

test "$(dpkg --print-architecture)" = amd64
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p dist "$stage/DEBIAN" "$stage/usr/local/bin" "$stage/usr/share/doc/helloworld"
gcc -std=c17 -Wall -Wextra -Werror -O2 -o "$stage/usr/local/bin/helloworld" src/helloworld.c
install -m 644 packaging/debian/control "$stage/DEBIAN/control"
install -m 644 README.md user_guide.txt "$stage/usr/share/doc/helloworld/"
set -x
dpkg-deb --root-owner-group --build "$stage" dist/helloworld_Joseph_Ghanem.deb
