bengalos-amd64:
	./configure.py build/
	mkosi -C build -i

deps:
	sudo apt install mkosi virtinst

pylint:
	mypy *.py
	black --check *.py
	flake8 *.py

lint: pylint
	mdl -s .mdl.rb -g *.md

clean:
	rm -rf build/

