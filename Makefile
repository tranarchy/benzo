OUTPUT = benzo

CFLAGS = -Wall -Wextra -Wpedantic

main:
	cc main.c -o $(OUTPUT) $(CFLAGS)