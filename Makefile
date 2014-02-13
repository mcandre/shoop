all: test

test: shoop.pl
	perl shoop.pl

perlwarn:
	-find . -type f -name '*.pl' -exec perl -MO=Lint -cw {} 2>&1 \; | grep -v "syntax OK" | grep -v "Can't locate"
	-find . -type f -name '*.pm' -exec perl -MO=Lint -cw {} 2>&1 \; | grep -v "syntax OK" | grep -v "Can't locate"
	-find . -type f -name '*.t' -exec perl -MO=Lint -cw {} 2>&1 \; | grep -v "syntax OK" | grep -v "Can't locate"

perlcritic:
	-perlcritic -q .

compile:
	for f in *.erl; do erlc -Wall +debug_info $$f; done

plt:
	dialyzer *.beam --build_plt --apps erts kernel stdlib

dialyzer: compile
	dialyzer *.beam --quiet

lint: perlwarn perlcritic dialyzer

clean:
	-rm *.beam
