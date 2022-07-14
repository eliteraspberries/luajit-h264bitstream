#!/bin/sh

set -e
set -x

dir="$(cd $(dirname $0) && pwd)"

VERSION="${VERSION:=0.2.0}"
test -f h264bitstream-${VERSION}.zip || \
    curl -L -o h264bitstream-${VERSION}.zip \
    https://github.com/aizvorski/h264bitstream/archive/refs/tags/${VERSION}.zip
test -d h264bitstream-${VERSION} || \
    unzip h264bitstream-${VERSION}.zip
patch -f -p0 < ${dir}/patches/patch-h264bitstream-${VERSION}.txt || true
cd h264bitstream-${VERSION}

AR="${AR:=ar}"
CC="${CC:=clang}"
LD="${LD:=${CC}}"

TARGET="${TARGET:=$(${CC} ${CFLAGS} -dumpmachine | sed -e 's/[0-9.]*$//')}"

test -f build/${TARGET}/lib/libh264bitstream.dylib && exit 0
test -f build/${TARGET}/lib/libh264bitstream.so && exit 0

DESTDIR="${dir}/build/${TARGET}"
PREFIX="${PREFIX:=/.}"

case "${TARGET}" in
    *-*-android*)
        AR="$(which ${AR})"
        CC="$(which ${CC})"
        LD="$(which ${LD})"
        SOEXT="so"
        ;;
    *-*-darwin*)
        AR="$(xcrun --sdk macosx --find ${AR})"
        CC="$(xcrun --sdk macosx --find ${CC})"
        LD="$(xcrun --sdk macosx --find ${LD})"
        SOEXT="dylib"
        ;;
    *-*-ios*)
        AR="$(xcrun --sdk iphoneos --find ${AR})"
        CC="$(xcrun --sdk iphoneos --find ${CC})"
        LD="$(xcrun --sdk iphoneos --find ${LD})"
        ;;
    *)
        ;;
esac

CFLAGS="${CFLAGS} -Wno-format"

SOURCES="h264_stream.c h264_sei.c h264_avcc.c h264_nal.c"
${CC} ${CPPFLAGS} ${CFLAGS} \
    -shared -o libh264bitstream.${SOEXT} ${SOURCES} ${LDFLAGS}

mkdir -p ${DESTDIR}${PREFIX}/lib
cp -f libh264bitstream.${SOEXT} ${DESTDIR}${PREFIX}/lib/
