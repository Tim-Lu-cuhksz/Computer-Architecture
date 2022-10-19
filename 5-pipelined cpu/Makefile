CC = iverilog
PROG = test_CPU

$(PROG): $(PROG).v ALU.v CPU.v InstructionRAM.v MainMemory.v
	$(CC) -o $(PROG) $(PROG).v ALU.v CPU.v InstructionRAM.v MainMemory.v

clean:
	rm $(PROG)
