DEVICE ?= amd64
FLAVOR ?= development
IMAGE_UPLOAD_OPTS=--verbose

# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1133276
# workaround for broken mkosi/26-2 in sid and forky
export PATH := $(addsuffix :/usr/sbin,$(PATH))

bengalos: build-${DEVICE}-${FLAVOR}/.done

bengalos-amd64-immutable:
	$(MAKE) DEVICE=amd64 FLAVOR=immutable bengalos

bengalos-sdm670-immutable:
	$(MAKE) DEVICE=sdm670 FLAVOR=immutable bengalos

bengalos-amd64-development:
	$(MAKE) DEVICE=amd64 FLAVOR=development bengalos

build-${DEVICE}-${FLAVOR}/.prep:
	./bengalos-builder.py build-${DEVICE}-${FLAVOR}/
	touch build-${DEVICE}-${FLAVOR}/.prep

build-${DEVICE}-${FLAVOR}/.done: build-${DEVICE}-${FLAVOR}/.prep
	mkosi -C build-${DEVICE}-${FLAVOR} -B -i \
	  --hostname phosh \
		--profile image-${FLAVOR},device-${DEVICE},zram,phosh \
		${MKOSI_OPTS}
	touch build-${DEVICE}-${FLAVOR}/.done

bengalos-run: build-${DEVICE}-${FLAVOR}/.done
	mkosi -C build-${DEVICE}-${FLAVOR} -i \
		--hostname phosh \
		--profile image-${FLAVOR},device-${DEVICE},zram,phosh \
		vm

deps:
	sudo apt install mkosi virtinst

pylint:
	mypy *.py
	black --check *.py
	flake8 *.py

shellcheck:
	shellcheck helpers/*.sh

lint: pylint shellcheck
	@if git --no-pager grep -I "	" -- ':(exclude)Makefile'; then \
		echo "Code contains tabs, please fix"; \
		exit 1; \
	fi
	mdl -s .mdl.rb -g *.md docs/*.md

clean:
	rm -rf build-${DEVICE}-${FLAVOR}/

upload:
	xz -zk build-${DEVICE}-${FLAVOR}/BengalOS_0.0.20??????.?.raw
	rsync ${IMAGE_UPLOAD_OPTS} \
		build-${DEVICE}-${FLAVOR}/BengalOS_0.0.20??????.?.raw.xz \
		"${IMAGE_HOST}:"

.PHONY: upload pylint deps clean
