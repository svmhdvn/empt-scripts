.POSIX:
.SUFFIXES:
.SUFFIXES: .sh

DESTDIR =
PREFIX = /usr/local
SOURCES != ls *.sh
BINS = $(SOURCES:.sh=)

all: $(BINS)

install: $(BINS)
	mkdir -p $(DESTDIR)$(PREFIX)/libexec/empt
	install -m 0755 $(BINS) $(DESTDIR)$(PREFIX)/libexec/empt

test: $(BINS)
	shellcheck -o all $(BINS)

clean:
	rm -f $(BINS)
