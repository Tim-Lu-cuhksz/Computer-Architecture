CC = g++

CFLAGS = -g

simulator: main.o
	$(CC) $(CFLAGS) -o simulator main.o

main.o: main.cpp
	$(CC) $(CFLAGS) -c main.cpp

clean:
	rm -rf simulator $(main.o)
