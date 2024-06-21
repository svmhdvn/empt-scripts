.POSIX:
.SUFFIXES:
.SUFFIXES: .sh

DESTDIR =
PREFIX = /usr/local
SOURCES != ls *.sh
BINS = $(SOURCES:.sh=)

build: $(BINS)

install: $(BINS)
	mkdir -p $(DESTDIR)$(PREFIX)/libexec/empt
	@for f in $(BINS); do \
	 install -o root -g wheel -m 0755 $f $(DESTDIR)$(PREFIX)/libexec/empt; \
	done

.sh:
	shellcheck -o all $<
	cp $< $@
	chmod a+x $@

clean:
	rm -f $(BINS)
