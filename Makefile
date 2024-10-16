.POSIX:
.SUFFIXES:

DESTDIR =
PREFIX = /usr/local
SOURCES != find . -type f -name '*.sh'

all:
	@echo "Nothing to build."

install:
	mkdir -p \
	    $(DESTDIR)$(PREFIX)/libexec/empt \
	    $(DESTDIR)$(PREFIX)/etc/periodic
	install -m 0755 *.sh $(DESTDIR)$(PREFIX)/libexec/empt
	for d in periodic/*; do \
	    install -m 0755 $d/* $(DESTDIR)$(PREFIX)/etc/$d; \
	done

test:
	shellcheck -o all $(SOURCES)
