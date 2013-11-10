all: test

test: shoop.pl
	perl shoop.pl

lint:
	-perlcritic . | grep -v "source OK"
