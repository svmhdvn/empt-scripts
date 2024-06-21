.POSIX:
.SUFFIXES:
.SUFFIXES: .sh

DESTDIR =
PREFIX = /usr/local
SOURCES != ls *.sh
BINS = $(SOURCES:.sh=)

build: $(BINS)

#for f in $(BINS); do \
# install -m 0755 "$${f}" $(DESTDIR)$(PREFIX)/libexec/empt; \
#done
install: $(BINS)
	mkdir -p $(DESTDIR)$(PREFIX)/libexec/empt
	install -m 0755 $(BINS) $(DESTDIR)$(PREFIX)/libexec/empt

.sh:
	shellcheck -o all $<
	cp $< $@
	chmod a+x $@

clean:
	rm -f $(BINS)
