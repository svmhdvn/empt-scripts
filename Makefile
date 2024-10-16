.POSIX:
.SUFFIXES:

all: test
test:
	find . -type f -name '*.sh' | xargs shellcheck -o all
