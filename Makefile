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

~/.dialyzer_plt: compile
	dialyzer *.beam --build_plt --quiet

dialyzer: ~/.dialyzer_plt
	dialyzer *.beam

lint: perl perlcritic dialyzer

clean:
	-rm *.beam
