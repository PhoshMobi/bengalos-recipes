BUILD=./build.sh -v -z -i

amd64:
	$(BUILD) -t $@
	ls -lh *.xz *.gz

deps:
	sudo apt install debos bmap-tools xz-utils zerofree virtinst

lint:
	mdl -s .mdl.rb -g *.md

clean:
	rm -rf build/

bengalos-amd64:
	./configure.py build/
	mkosi -C build -i
