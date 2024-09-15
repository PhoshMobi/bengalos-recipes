all:
	./build.sh -v -z -i -t amd64
	ls -lh *.gz

deps:
	sudo apt install debos bmap-tools xz-utils zerofree
