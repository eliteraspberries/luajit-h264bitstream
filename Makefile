AR?=	ar
CC?=	clang
LD?=	$(CC)

ifeq ("$(TARGET)","")
TARGET:=	$(shell $(CC) $(CFLAGS) -dumpmachine | sed -e 's/[0-9.]*$$//')
endif
SYS:=		$(shell echo "$(TARGET)" | awk -F- '{print $$3}')

CFLAGS+=	--target=$(TARGET)

ifeq ("$(SYS)","darwin")
SDKROOT:=	$(shell xcrun --sdk macosx --show-sdk-path)
AR:=		$(shell xcrun --sdk macosx --find ar)
CC:=		$(shell xcrun --sdk macosx --find clang)
CPPFLAGS+=	-isysroot $(SDKROOT)
CFLAGS+=	--sysroot=$(SDKROOT)
LDFLAGS+=	--sysroot=$(SDKROOT)
CFLAGS+=	-mmacosx-version-min=10.9
LDFLAGS+=	--target=$(TARGET)
endif

ifeq ($(shell uname -s),Darwin)
DYLD_LIBRARY_PATH:=	$(shell pwd)/build/$(TARGET)/lib:$(DYLD_LIBRARY_PATH)
LUA:=				DYLD_LIBRARY_PATH="$(DYLD_LIBRARY_PATH)" luajit
else
LD_LIBRARY_PATH:=	$(shell pwd)/build/$(TARGET)/lib:$(LD_LIBRARY_PATH)
LUA:=				LD_LIBRARY_PATH="$(LD_LIBRARY_PATH)" luajit
endif
LUA_CPATH:=			$(shell pwd)/build/$(TARGET)/lib/?

.PHONY: h264bitstream
h264bitstream: build-h264bitstream.sh
	/bin/sh build-h264bitstream.sh

.PHONY: lib
lib:

.PHONY: so
so: h264bitstream

.PHONY: check
check:
	luacheck *.lua

.PHONY: test
test: h264bitstream.lua test.lua
	LUA_CPATH="$(LUA_CPATH)" $(LUA) h264bitstream.lua
	LUA_CPATH="$(LUA_CPATH)" $(LUA) test.lua | tee test.txt
	cat test-expected.txt
	cmp test-expected.txt test.txt

.PHONY: cleanup
cleanup:
	rm -f test.txt
	rm -rf h264bitstream-[0-9].[0-9].[0-9]
	$(MAKE) -f android/Makefile cleanup

.PHONY: clean
clean: cleanup
	rm -rf build/*
	$(MAKE) -f android/Makefile clean
