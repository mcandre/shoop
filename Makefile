all: test

test: shoop.pl
	perl shoop.pl

perl:
	-for f in *.pl; do perl -MO=Lint -cw $$f 2>&1 | grep -v "syntax OK"; done
	-for f in **/*.pl; do perl -MO=Lint -cw $$f 2>&1 | grep -v "syntax OK"; done
	-for f in *.pm; do perl -MO=Lint -cw $$f 2>&1 | grep -v "syntax OK"; done
	-for f in **/*.pm; do perl -MO=Lint -cw $$f 2>&1 | grep -v "syntax OK"; done

perlcritic:
	-perlcritic . | grep -v "source OK"

compile:
	for f in *.erl; do erlc -Wall +debug_info $$f; done

plt:
	dialyzer *.beam --build_plt --apps erts kernel stdlib

dialyzer: compile
	dialyzer *.beam --quiet

lint: perl perlcritic dialyzer

clean:
	-rm *.beam
