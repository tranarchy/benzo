OUTPUT = benzo

main:
	as main.s -o main.o
	ld main.o -o $(OUTPUT)
	rm main.o