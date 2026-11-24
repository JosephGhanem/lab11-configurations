#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p build dist
x86_64-w64-mingw32-g++ -std=c++17 -Wall -Wextra -Werror -O2 -static -o build/helloworld.exe src/helloworld.cpp
set -x
wixl -a x64 -o dist/helloworld_Joseph_Ghanem.msi helloworld.wxs
