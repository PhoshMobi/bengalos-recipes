BUILD=./build.sh -v -z -i

amd64:
	$(BUILD) -t $@
	ls -lh *.gz

deps:
	sudo apt install debos bmap-tools xz-utils zerofree virtinst
