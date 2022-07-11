MAKEFILE:=	$(firstword $(MAKEFILE_LIST))
MAKEDIR:=	$(shell cd $(dir $(MAKEFILE)) && pwd)

ABIS:=		armeabi-v7a arm64-v8a
LIBS:=		

ifeq ("$(ABI)","armeabi-v7a")
TARGET:=	arm-linux-androideabi
endif
ifeq ("$(ABI)","arm64-v8a")
TARGET:=	aarch64-linux-android
endif

.PHONY: lib
lib:
	for abi in $(ABIS); do \
		ABI=$$abi python -m androidenv $(MAKE) lib; \
	done

.PHONY: so
so: lib
	for abi in $(ABIS); do \
		ABI=$$abi python -m androidenv $(MAKE) so; \
	done

.PHONY: install-so
install-so:
	cp -fPR build/$(TARGET)/lib/*.so* $(DESTDIR)$(PREFIX)/lib/$(ABI)/

.PHONY: install
install:
	for abi in $(ABIS); do \
		ABI=$$abi $(MAKE) -f $(MAKEFILE) install-so; \
	done
	for abi in $(ABIS); do \
		ABI=$$abi API=$(API) python -m androidenv --find-library $(LIBS) \
		| while read f; do \
			install "$$f" "$(DESTDIR)$(PREFIX)/lib/$$abi/"; \
		done; \
	done

.PHONY: cleanup
cleanup:

.PHONY: clean
clean: cleanup
	rm -rf build/*-*-android*/*
