OUTPUT = benzo

CFLAGS = -Wall -Wextra -Wpedantic
SOURCE_FILES = main.c libsigscan.c

main:
	cc $(SOURCE_FILES) -o $(OUTPUT) $(CFLAGS)