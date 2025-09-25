#!/bin/sh

as main.s -o main.o
ld main.o -o benzo

rm main.o
