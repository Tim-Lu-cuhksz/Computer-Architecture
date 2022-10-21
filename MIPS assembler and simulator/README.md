# Description
The goal of the first project is to build MIPS (Microprocessor without Interlocked 
Pipelined Stages) simulator through C/C++. MIPS simulator serves the purpose of 
assembling a MIPS file into machine codes and executing each instruction line by line 
based on its type and functionality. Different from complex instruction set computer 
(CISC), MIPS is a reduced instruction set computer (RISC) instruction set architecture 
(ISA) with instructions of fixed size and more registers. Moreover, the design principles
of MIPS, such as simplicity and good compromises, help to make hardware perform
faster and better than other assembly language.

## Assembler
### 1.1 Read and remove
First and foremost, we need to open the MIPS file (.asm) and read the contents line by 
line. When doing so, redundant parts such as spaces and comments are cut off using
some fundamental methods (loops, character examiner, etc.). After removing them, the 
left parts can be much more easily processed in the following process.
### 1.2 Identify and store
Since it is not necessary to assemble “.data” section and labels (but the address), we 
should identify and skip them. In the meantime, address of labels needs to be stored for 
later use (I-type and J-type instruction may need the use of address). Starting from the 
first instruction after “.text”, which possesses the address of “100000_hex”, we use a 
global variable to indicate the address of each instruction and increment it by 4 after 
each line. When encountering a label, we store both the address and its string name in 
a label map.
### 1.3 Re-read and translate
Since all types of instruction have the same opcode field, it is much easier to store the commands of all instruction, such as “add”, into a map. Moreover, to better recognize 
the type of each command, it is convenient to construct three sets data structure for 
three formats of instructions. Once completing the construction of maps, we are ready 
to translate the instructions into the machine codes. Scan through each line again, 
recognize each type, and tokenize the segments based on the type. A structure is used 
to store different fields in a machine code.

## Simulator
### 2.1 Memory & Register simulation
As mentioned above, we use a C++ keyword new to dynamically allocate memory for 
virtual memory and registers in MIPS architecture. Based on the storage size for each 
section specified in the project file, we can get pointers for text section, data section, 
heap section, and stack section. For registers, simply construct an array with its 
elements pointing to int memory.
### 2.2 Data storing
We need to store two parts of data, machine codes and static data. For machine codes, 
we convert them into integers and store them in the newly allocated array starting from 
text section. For static data, we first need to identify whether the data type is a string or 
an integer. If it is an integer (word), we just keep its content into one block of memory 
in the virtual memory. However, if it is a string, we need to typecast corresponding 
pointers to store characters into the array (4 characters for one block).

### 2.3 Execution
Eventually, it is time to execute each line of machine codes in the virtual memory. Just 
use a program counter (PC), which is a pointer points to the bottom of text section in 
the beginning. Then, fetch the data from text segment and increment by 4 at each new 
round. To perform correct functionality, we identify both the opcode and funct code.
For syscalls, just recognize the number in $v0 and perform properly according the 
appendix on the textbook.

