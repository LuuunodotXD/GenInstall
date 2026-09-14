#!/bin/sh
# 04-sinit.sh — build do sinit (init minimalista do suckless)
. "$(dirname "$0")/common.sh"

VERSION=1.1
URL="https://dl.suckless.org/tools/sinit-$VERSION.tar.gz"

step "sinit $VERSION"

fetch "$URL"
extract "$URL"

cd "$BUILD_DIR/sinit-$VERSION"

make CC=gcc CFLAGS="$CFLAGS -static" -j"$JOBS"
make PREFIX=/usr DESTDIR="$BASE" install

echo "  sinit $VERSION done."
