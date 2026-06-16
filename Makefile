ARCH ?= amd64
VARIANT ?= development
IMAGE_UPLOAD_OPTS=--verbose

# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1133276
# workaround for broken mkosi/26-2 in sid and forky
export PATH := $(addsuffix :/usr/sbin,$(PATH))

bengalos: build-${ARCH}-${VARIANT}/.done

bengalos-amd64-immutable:
	$(MAKE) ARCH=amd64 VARIANT=immutable bengalos

bengalos-amd64-development:
	$(MAKE) ARCH=amd64 VARIANT=development bengalos

build-${ARCH}-${VARIANT}/.prep:
	./bengalos-builder.py build-${ARCH}-${VARIANT}/
	touch build-${ARCH}-${VARIANT}/.prep

build-${ARCH}-${VARIANT}/.done: build-${ARCH}-${VARIANT}/.prep
	mkosi -C build-${ARCH}-${VARIANT} -B -i \
	  --hostname phosh \
		--profile image-${VARIANT},device-${ARCH},zram,phosh
	touch build-${ARCH}-${VARIANT}/.done

bengalos-run: build-${ARCH}-${VARIANT}/.done
	mkosi -C build-${ARCH}-${VARIANT} -i \
		--hostname phosh \
		--profile image-${VARIANT},device-${ARCH},zram,phosh \
		vm

deps:
	sudo apt install mkosi virtinst

pylint:
	mypy *.py
	black --check *.py
	flake8 *.py

shellcheck:
	shellcheck helpers/get-qcow2.sh

lint: pylint shellcheck
	mdl -s .mdl.rb -g *.md docs/*.md

clean:
	rm -rf build-${ARCH}-${VARIANT}/

upload:
	xz -zk build-${ARCH}-${VARIANT}/BengalOS_0.0.20??????.?.raw
	rsync ${IMAGE_UPLOAD_OPTS} \
		build-${ARCH}-${VARIANT}/BengalOS_0.0.20??????.?.raw.xz \
		"${IMAGE_HOST}:"

.PHONY: upload pylint deps clean
