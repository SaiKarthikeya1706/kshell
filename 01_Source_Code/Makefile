# KShell - simple Unix shell
CC     = gcc
CFLAGS = -std=c11 -Wall -Wextra -pedantic -O2 -g
TARGET = kshell

all: $(TARGET)

$(TARGET): main.c
	$(CC) $(CFLAGS) -o $(TARGET) main.c

run: $(TARGET)
	./$(TARGET)

test: $(TARGET)
	bash supporting_files/test_basic.sh
	bash supporting_files/leak_check.sh

clean:
	rm -rf $(TARGET) $(TARGET).dSYM

.PHONY: all run test clean
