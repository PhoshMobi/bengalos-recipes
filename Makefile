ARCH ?= amd64
FLAVOR ?= development
IMAGE_UPLOAD_OPTS=--verbose

# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1133276
# workaround for broken mkosi/26-2 in sid and forky
export PATH := $(addsuffix :/usr/sbin,$(PATH))

bengalos: build-${ARCH}-${FLAVOR}/.done

bengalos-amd64-immutable:
	$(MAKE) ARCH=amd64 FLAVOR=immutable bengalos

bengalos-amd64-development:
	$(MAKE) ARCH=amd64 FLAVOR=development bengalos

build-${ARCH}-${FLAVOR}/.prep:
	./bengalos-builder.py build-${ARCH}-${FLAVOR}/
	touch build-${ARCH}-${FLAVOR}/.prep

build-${ARCH}-${FLAVOR}/.done: build-${ARCH}-${FLAVOR}/.prep
	mkosi -C build-${ARCH}-${FLAVOR} -B -i \
	  --hostname phosh \
		--profile image-${FLAVOR},device-${ARCH},zram,phosh
	touch build-${ARCH}-${FLAVOR}/.done

bengalos-run: build-${ARCH}-${FLAVOR}/.done
	mkosi -C build-${ARCH}-${FLAVOR} -i \
		--hostname phosh \
		--profile image-${FLAVOR},device-${ARCH},zram,phosh \
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
	mdl -s .mdl.rb -g *.md docs/*.md

clean:
	rm -rf build-${ARCH}-${FLAVOR}/

upload:
	xz -zk build-${ARCH}-${FLAVOR}/BengalOS_0.0.20??????.?.raw
	rsync ${IMAGE_UPLOAD_OPTS} \
		build-${ARCH}-${FLAVOR}/BengalOS_0.0.20??????.?.raw.xz \
		"${IMAGE_HOST}:"

.PHONY: upload pylint deps clean
