bengalos-amd64-development: build-amd64-development/.done

build-amd64-development/.done:
	./configure.py build-amd64-development/
	mkosi -C build-amd64-development -i \
	  --hostname phosh \
		--profile image-development,device-amd64,zram,phosh
	touch build-amd64-development/.done

bengalos-amd64-development-run: build-amd64-development/.done
	mkosi -C build-amd64-development -i \
		--hostname phosh \
		--profile image-development,device-amd64,zram,phosh \
		vm

bengalos-amd64-immutable: build-amd64-immutable/.done

build-amd64-immutable/.done:
	./configure.py build-amd64-immutable/
	mkosi -C build-amd64-immutable genkey
	mkosi -C build-amd64-immutable -i \
		--hostname phosh \
		--profile image-immutable,device-amd64,zram,phosh
	touch build-amd64-immutable/.done

bengalos-amd64-immutable-run: build-amd64-immutable/.done
	mkosi -C build-amd64-immutable -i \
		--hostname phosh \
		--profile image-immutable,device-amd64,zram,phosh \
		vm


deps:
	sudo apt install mkosi virtinst

pylint:
	mypy *.py
	black --check *.py
	flake8 *.py

lint: pylint
	mdl -s .mdl.rb -g *.md

clean:
	rm -rf build-amd64-development/
	rm -rf build-amd64-immutable/

