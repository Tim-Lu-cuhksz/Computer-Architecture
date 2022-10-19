module alu (instruction, regA, regB, result, flags);
    input [31:0] instruction, regA, regB; // addr of A is 00000, while that of B is 00001
    output [31:0] result;
    output [2:0] flags; // negative, overflow, zero

    reg [3:0] ALUctr;

    reg [4:0] rs, rt, /*rd,*/ shamt;
    reg [5:0] opcode, funct;
    reg [15:0] imm;
    reg [31:0] regA_in, regB_in;

    // unsign: we are doing unsigned computation
    // isxor: we are doing xor operation
    // isless: we are doing slt(i) operation
    reg unsign, isxor, isless, shift, arithm;
    reg [31:0] xor_result, shift_result;

    wire [31:0] result_alu;
    wire [2:0] flag_alu,flag_tmp;

    parameter and_op = 4'b0;
    parameter or_op = 4'b0001;
    parameter add_op = 4'b0010;
    parameter sub_op = 4'b0110;
    parameter slt_op = 4'b0111;
    parameter nor_op = 4'b1100;

    parameter xor_op = 4'b1000;

    /*
    Implementation of fetching and parsing instructions
    Decode and obtain ALUctr
    */
    always @(*) begin
        opcode = instruction [31:26];
        funct = instruction [5:0];
        rs = instruction [25:21];
        rt = instruction [20:16];
        //rd = instruction [15:11];
        shamt = instruction [10:6];
        imm = instruction [15:0];

        // Set flags
        unsign = 1'b0;
        isxor = 1'b0;
        isless = 1'b0;
        shift = 1'b0;
        arithm = 1'b0;

        regA_in = (rs[0]) ? regB : regA;
        regB_in = (rt[0]) ? regB : regA;

        // R type instruction
        if (opcode == 6'b0) begin
            // add
            if (funct == 6'b100000) begin
                ALUctr = add_op;
                arithm = 1'b1;
            end
            // addu
            else if (funct == 6'b100001) begin
                ALUctr = add_op;
                unsign = 1'b1;
                arithm = 1'b1;
            end
            // sub
            else if (funct == 6'b100010) begin
                ALUctr = sub_op;
                arithm = 1'b1;
            end
            // subu
            else if (funct == 6'b100011) begin
                ALUctr = sub_op;
                unsign = 1'b1;
                arithm = 1'b1;
            end
            // and
            else if (funct == 6'b100100) begin
                ALUctr = and_op;
            end
            // or
            else if (funct == 6'b100101) begin
                ALUctr = or_op;
            end
            // nor
            else if (funct == 6'b100111) begin
                ALUctr = nor_op;
            end
            // xor
            else if (funct == 6'b100110) begin
                isxor = 1'b1;
                xor_result = regA_in ^ regB_in;
                ALUctr = xor_op; // Add or other i wish
            end
            //slt
            else if (funct == 6'b101010) begin
                isless = 1'b1;
                arithm = 1'b1;
                ALUctr = slt_op;
            end
            // sltu
            else if (funct == 6'b101011) begin
                unsign = 1'b1;
                isless = 1'b1;
                arithm = 1'b1;
                ALUctr = slt_op;
            end
            // sll
            else if (funct == 6'b0) begin
                shift_result = regB_in << shamt;
                shift = 1'b1;
                unsign = 1'b1;
                ALUctr = 4'b0010; // r
            end
            // sllv
            else if (funct == 6'b000100) begin
                shift_result = regB_in << regA_in;
                shift = 1'b1;
                unsign = 1'b1; // for flag
                ALUctr = 4'b0010; // r
            end
            // srl
            else if (funct == 6'b000010) begin
                shift_result = regB_in >> shamt;
                shift = 1'b1;
                unsign = 1'b1;
                ALUctr = 4'b0010; // r
            end
            // srlv
            else if (funct == 6'b000110) begin
                shift_result = regB_in >> regA_in;
                shift = 1'b1;
                unsign = 1'b1;
                ALUctr = 4'b0010; // r
            end
            // sra
            else if (funct == 6'b000011) begin
                shift_result = regB_in >>> shamt;
                shift = 1'b1;
                //unsign = 1'b1;
                ALUctr = 4'b0010; // r
            end
            // srav
            else if (funct == 6'b000111) begin
                shift_result = regB_in >>> regA_in;
                shift = 1'b1;
                //unsign = 1'b1;
                ALUctr = 4'b0010; // r
            end
        end
        // I instructions
        // addi
        else if (opcode == 6'b001000) begin
            regB_in = {{16{imm[15]}}, imm};
            ALUctr = 4'b0010;
        end
        // addiu
        else if (opcode == 6'b001001) begin
            regB_in = {{16{1'b0}}, imm};
            ALUctr = 4'b0010;
            unsign = 1'b1;
        end
        // andi
        else if (opcode == 6'b001100) begin
            regB_in = {{16{imm[15]}}, imm};
            ALUctr = 4'b0;
        end
        // ori
        else if (opcode == 6'b001101) begin
            regB_in = {{16{imm[15]}}, imm};
            ALUctr = 4'b1;
        end
        // xori
        else if (opcode == 6'b001110) begin
            isxor = 1'b1;
            regB_in = {{16{imm[15]}}, imm};
            xor_result = regA_in ^ regB_in;
            ALUctr = xor_op; // Add or other i wish
        end
        // beq + bne
        else if (opcode == 6'b000100 || opcode == 6'b000101) begin
            arithm = 1'b1;
            ALUctr = sub_op;
        end
        // slti
        else if (opcode == 6'b001010) begin
            regB_in = {{16{imm[15]}}, imm};
            ALUctr = slt_op;
            isless = 1'b1;
            arithm = 1'b1;
        end
        // sltiu
        else if (opcode == 6'b001011) begin
            unsign = 1'b1;
            regB_in = {{16{1'b0}}, imm};
            ALUctr = slt_op;
            arithm = 1'b1;
            isless = 1'b1;
        end
        // lw + sw
        else if (opcode == 6'b100011 || opcode == 6'b101011) begin
            regB_in = {{16{imm[15]}}, imm};
            ALUctr = add_op;
        end
    end

    ALU_32bits EX (ALUctr, regA_in, regB_in, result_alu, 
                    flag_alu, unsign, isless);

    assign result =  (isxor) ? xor_result : (shift) ? shift_result
                        : (isless) ? (flag_alu[1]) ? 'b1 : 'b0
                        :result_alu;
    assign flag_tmp = (arithm) ? flag_alu : {flag_alu[2],{2{1'b0}}};
    // reverse
    assign flags = {flag_tmp[0],flag_tmp[1],flag_tmp[2]};
endmodule

module bit_ext (unextend,extended,sign);
    // Input 1 if it's sign extension, otherwise 0
    input [15:0] unextend;
    input sign;
    output [31:0] extended;
    assign extended = (sign) ? {{16{unextend[15]}}, unextend} : 
                            {{16{1'b0}},unextend};
endmodule

// Implements a 32-bit ALU
module ALU_32bits (ALU_op, regA, regB, Result, flag, unsign, isless);

    input [3:0] ALU_op;
    input [31:0] regA, regB;
    input unsign, isless;
    output [31:0] Result;
    output [2:0] flag;
    //output Cout;

    parameter p1 = 1'b0;
    parameter p2 = 1'b1;
    
    // result variables
    wire r0, r1, r2, r3, r4 ,r5 ,r6, r7, r8, r9,
        r10, r11, r12, r13, r14, r15, r16, r17, r18, r19,
        r20, r21, r22, r23, r24, r25, r26, r27, r28, r29,
        r30, r31;
    // carry-out variables
    wire c0, c1, c2, c3, c4 ,c5 ,c6, c7, c8, c9,
        c10, c11, c12, c13, c14, c15, c16, c17, c18, c19,
        c20, c21, c22, c23, c24, c25, c26, c27, c28, c29,
        c30;
    // Check if subtraction
    reg r; reg is_xor = 0;
    // Used for slt
    wire w_lb; reg [31:0] xor_res;
    // Implementation of 32-bit ALU
    always @(*) begin
        /*
        if (ALU_op == 4'b1000)
            is_xor = 1;
        */
        if (ALU_op == 4'b0110)
            r = p2;
        else if (ALU_op == 4'b0111)
            r = p2;
        else
            r = p1;
    end
    
    ALU_1bit A0 (ALU_op, regA[0], regB[0], p1, r, r0, c0);
    ALU_1bit A1 (ALU_op, regA[1], regB[1], p1, c0, r1, c1);
    ALU_1bit A2 (ALU_op, regA[2], regB[2], p1, c1, r2, c2);
    ALU_1bit A3 (ALU_op, regA[3], regB[3], p1, c2, r3, c3);
    ALU_1bit A4 (ALU_op, regA[4], regB[4], p1, c3, r4, c4);
    ALU_1bit A5 (ALU_op, regA[5], regB[5], p1, c4, r5, c5);
    ALU_1bit A6 (ALU_op, regA[6], regB[6], p1, c5, r6, c6);
    ALU_1bit A7 (ALU_op, regA[7], regB[7], p1, c6, r7, c7);
    ALU_1bit A8 (ALU_op, regA[8], regB[8], p1, c7, r8, c8);
    ALU_1bit A9 (ALU_op, regA[9], regB[9], p1, c8, r9, c9);
    ALU_1bit A10 (ALU_op, regA[10], regB[10], p1, c9, r10, c10);
    ALU_1bit A11 (ALU_op, regA[11], regB[11], p1, c10, r11, c11);
    ALU_1bit A12 (ALU_op, regA[12], regB[12], p1, c11, r12, c12);
    ALU_1bit A13 (ALU_op, regA[13], regB[13], p1, c12, r13, c13);
    ALU_1bit A14 (ALU_op, regA[14], regB[14], p1, c13, r14, c14);
    ALU_1bit A15 (ALU_op, regA[15], regB[15], p1, c14, r15, c15);
    ALU_1bit A16 (ALU_op, regA[16], regB[16], p1, c15, r16, c16);
    ALU_1bit A17 (ALU_op, regA[17], regB[17], p1, c16, r17, c17);
    ALU_1bit A18 (ALU_op, regA[18], regB[18], p1, c17, r18, c18);
    ALU_1bit A19 (ALU_op, regA[19], regB[19], p1, c18, r19, c19);
    ALU_1bit A20 (ALU_op, regA[20], regB[20], p1, c19, r20, c20);
    ALU_1bit A21 (ALU_op, regA[21], regB[21], p1, c20, r21, c21);
    ALU_1bit A22 (ALU_op, regA[22], regB[22], p1, c21, r22, c22);
    ALU_1bit A23 (ALU_op, regA[23], regB[23], p1, c22, r23, c23);
    ALU_1bit A24 (ALU_op, regA[24], regB[24], p1, c23, r24, c24);
    ALU_1bit A25 (ALU_op, regA[25], regB[25], p1, c24, r25, c25);
    ALU_1bit A26 (ALU_op, regA[26], regB[26], p1, c25, r26, c26);
    ALU_1bit A27 (ALU_op, regA[27], regB[27], p1, c26, r27, c27);
    ALU_1bit A28 (ALU_op, regA[28], regB[28], p1, c27, r28, c28);
    ALU_1bit A29 (ALU_op, regA[29], regB[29], p1, c28, r29, c29);
    ALU_1bit A30 (ALU_op, regA[30], regB[30], p1, c29, r30, c30);
    ALU_1bit_last A31 (ALU_op, regA[31], regB[31], p1, c30, r31, c31,w_lb);

    // If slt, we assin the first bit to be the last bit
    reg r_tmp;
    always @(*) begin
        if (ALU_op == 4'b0111)
            r_tmp = w_lb;
        else
            r_tmp = r0;
    end
    
    assign Result = (is_xor)? (regA ^ regB) :{r31, r30, r29, r28, r27 ,r26 ,r25, r24, r23,
        r22, r21, r20, r19, r18, r17, r16, r15, r14, r13,
        r12, r11, r10, r9, r8, r7, r6, r5, r4, r3, r2,
        r1, r_tmp};

    // Negative flag
    
    assign flag[1] = (unsign)? (isless)? ((c31)?
                1'b0 : ~w_lb) : 1'b0 : w_lb;

    // Zero flag
    assign flag[2] = ~(r_tmp|r1|r2|r3|r4|r5|r6|r7|r8|r9|r10|r11|r12|
                    r13|r14|r15|r16|r17|r18|r19|r20|r21|r22|r23|
                    r24|r25|r26|r27|r28|r29|r30|r31);
    // Overflow detection
    assign flag[0] = (unsign || is_xor) ? 1'b0 : c30 ^ c31;
endmodule

module ALU_1bit_last (ALU_ctr,a, b, less, cin,result,cout,a_out);
    input [3:0] ALU_ctr;
    input a, b, less, cin;
    output result,cout,a_out;
    wire [1:0] ain, bin;
    wire aout, bout;

    MUX_2to1 M0(a, ~a, ALU_ctr[3], aout);
    MUX_2to1 M1(b, ~b, ALU_ctr[2], bout);

    wire and_out, or_out, add_out;
    assign and_out = aout & bout;
    assign or_out = aout | bout;

    full_adder U0(aout, bout, cin, add_out, cout);
    assign a_out = add_out;
    MUX_4to1 M2(and_out, or_out, add_out, less, ALU_ctr[1:0], result);

endmodule

// Implements an 1-bit ALU

module ALU_1bit (ALU_ctr, a, b, less, cin, result, cout);
    input [3:0] ALU_ctr;
    input a, b, less, cin;
    output result,cout;
    wire [1:0] ain, bin;
    wire aout, bout;
    //assign ain[1] = a; assign ain[0] = ~a;
    //assign bin[1] = b; assign bin[0] = ~b;
    MUX_2to1 M0(a, ~a, ALU_ctr[3], aout);
    MUX_2to1 M1(b, ~b, ALU_ctr[2], bout);

    wire and_out, or_out, add_out;

    assign and_out = aout & bout;
    assign or_out = aout | bout;
    full_adder U0(aout, bout, cin, add_out, cout);

    MUX_4to1 M2(and_out, or_out, add_out, less, ALU_ctr[1:0], result);

endmodule

// Implements a full-adder
module full_adder(Ai, Bi, Ci, So, Co);
    input Ai, Bi, Ci;
    output So, Co;
    wire [1:0] N;

    assign N[1] = Ai ^ Bi;
    assign N[0] = Ai & Bi;

    assign So = N[1] ^ Ci;
    assign Co = (N[0]) | (Ci & (N[1]));

endmodule

// Implements 2-to-1 and 4-to-1 MUX
module MUX_2to1(A, B, sel, out);
    // sel = 0 -> A
    // sel = 1 -> B
    input A,B,sel;
    output out;
    assign out = sel ? B : A;
endmodule

module MUX_2to1_32bits(A, B, sel, out);
    // sel = 0 -> A
    // sel = 1 -> B
    input [31:0] A,B;
    input sel;
    output [31:0] out;
    assign out = sel ? B : A;
endmodule

module MUX_4to1 (A,B,C,D,sel,out);
    // sel = 00 -> A
    // sel = 01 -> B
    // sel = 10 -> C
    // sel = 11 -> D
    input A,B,C,D;
    input [1:0] sel;
    output out;
    assign out = sel[1] ? (sel[0] ? D : C) : sel[0] ? B : A;
endmodule

module MUX_4to1_32bits (A,B,C,D,sel,out);
    // sel = 00 -> A
    // sel = 01 -> B
    // sel = 10 -> C
    // sel = 11 -> D
    input [31:0] A,B,C,D;
    input [1:0] sel;
    output [31:0] out;
    assign out = sel[1] ? (sel[0] ? D : C) : sel[0] ? B : A;
endmodule