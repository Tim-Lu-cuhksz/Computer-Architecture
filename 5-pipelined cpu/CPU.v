`timescale 100fs/100fs

module cpu(clk, RESET);
    input clk, RESET;
    // parameter declaration
    parameter add_op = 4'b0010;
    parameter FOUR = 'b0100;
    parameter HIGH = 1'b1; parameter LOW= 1'b0;

    /* ----------IF stage---------- */
    // Wires needed in IF stage
    // inst: instruction obtained from the memory
    wire [31:0] inst, PCF, PC, PCPlus4F, PCBranchM, InstrD, PCPlus4D;
    wire [31:0] PCPlus4_delay;
    wire PCSrcM, flagF; // A control signal
    assign PCSrcM = 1'b0;
    // PC buffer
    PC_buff PB (.clk(clk),.PC_in(PC),.PC_out(PCF),.flagF(flagF));
    // Instruction fetch
    InstructionRAM IMEM(.CLOCK(clk),.RESET(RESET),.ENABLE(HIGH),.DATA(inst),.FETCH_ADDRESS(PCF>>>2));

    adder ad(.A(PCF), .B(FOUR), .SUM(PCPlus4F),.flag(flagF));
    MUX_2to1_32bits mux1(.A(PCPlus4F),.B(PCBranchM),.out(PC),.sel(PCSrcM));   
    
    regBuff_IF_ID b1(.clk(clk),.inst_in(inst),.inst_out(InstrD),
                .addr_in(PCPlus4_delay),.addr_out(PCPlus4D));
    // This buffer is used to stall for synchronizng data
    branchBuff b11(.clk(clk),.branch_in(PCPlus4F),.branch_out(PCPlus4_delay));

    /* ----------ID stage---------- */
    wire [31:0] RD1D, RD2D, SignImmD;
    wire [9:0] controlD;
    wire [4:0] signalD;
    wire [4:0] WriteRegW; // From WB
    wire [31:0] ResultW; // From WB
    
    /*
    control_in [9] RegWrite
    control_in [8] MemtoReg
    control_in [7] MemWrite
    control_in [6] Branch
    control_in [5] ALUSrc
    control_in [4] RegDst
    control_in [3:0] ALUControl
    */
    
    ControlUnit CU(.opcode(InstrD[31:26]), .funct(InstrD[5:0]), .control(controlD),
            .signal(signalD));
    
    /*
    signal[4] -> unsign
    signal[3] -> isxor
    signal[2] -> isless
    signal[1] -> shift
    signal[0] -> arithm
    */

    RegFile RF(.clk(clk), .WE3(controlW[1]), .A1(InstrD[25:21]), .A2(InstrD[20:16]),
            .A3(WriteRegW), .WD3(ResultW), .RD1(RD1D), .RD2(RD2D));

    bit_ext be(.unextend(InstrD[15:0]),.extended(SignImmD),.sign(HIGH));

    // Wires for EX stage
    //wire RegWriteE, MemtoRegE, MemWriteE, BranchE, ALUSrcE, RegDstE;
    wire [31:0] SrcAE, WriteDataE, SignImmE, PCPlus4E;
    wire [4:0] RtE, RdE, signalE, shamtE;

    wire [9:0] control_delay, controlE;
    wire [4:0] Rt_delay, Rd_delay, signal_delay, shamt_delay;
    wire [31:0] SignImm_delay, PCPlus4_delay2;

    EXBuff b22(
            //Input part
            .clk(clk), .control_in(controlD),.SignImm_in(SignImmD),
            .PCPlus4_in(PCPlus4D), .Rt_in(InstrD[20:16]), .Rd_in(InstrD[15:11]),
            .signal_in(signalD), .shamt_in(InstrD[10:6]),
            //Output part
            .control_out(control_delay),.Rt_out(Rt_delay), .Rd_out(Rd_delay),
            .PCPlus4_out(PCPlus4_delay2),.SignImm_out(SignImm_delay),
            .signal_out(signal_delay),.shamt_out(shamt_delay));

    // Register buffer, massive, isn't it?
    regBuff_ID_EX b2(
            //Input part
            .clk(clk), .control_in(control_delay),.SignImm_in(SignImm_delay),
            .PCPlus4_in(PCPlus4_delay2), .Rt_in(Rt_delay), .Rd_in(Rd_delay),
            .RD1_in(RD1D), .RD2_in(RD2D), .signal_in(signal_delay), .shamt_in(shamt_delay),
            //Output part
            .control_out(controlE), .Rt_out(RtE), .Rd_out(RdE), .SignImm_out(SignImmE),
            .PCPlus4_out(PCPlus4E),.RD1_out(SrcAE), .RD2_out(WriteDataE), 
            .signal_out(signalE), .shamt_out(shamtE)); 

    /* ----------EX stage---------- */
    // Wires needed in this stage
    wire [31:0] ALUOutE, PCBranchE, SrcBE;
    wire ZeroE;
    wire [4:0] WriteRegE;
    reg [31:0] shift_result, xor_result;

    // Operation code for some instruction
    parameter xor_op = 4'b1000;
    parameter sll_op = 4'b0011;
    parameter sllv_op = 4'b1001;
    parameter srl_op = 4'b0100;
    parameter srlv_op = 4'b1010;
    parameter sra_op = 4'b0101;
    parameter srav_op = 4'b1011;
    parameter xori_op = 4'b1101;

    /*
    control_in [9] RegWrite
    control_in [8] MemtoReg
    control_in [7] MemWrite
    control_in [6] Branch
    control_in [5] ALUSrc
    control_in [4] RegDst
    control_in [3:0] ALUControl
    */

    MUX_2to1_32bits mux2(.A(WriteDataE),.B(SignImmE),.out(SrcBE),.sel(controlE[5]));  
    MUX_2to1_5bits mux3(.A(RtE),.B(RdE),.out(WriteRegE),.sel(controlE[4])); 
    
    ALU_32bits alu3(.ALU_op(add_op),.regA(SignImmE<<2),.regB(PCPlus4E),
                .unsign(HIGH),.isless(LOW),.Result(PCBranchE));
    
    // Implementation of ALU
    always @(*) begin
        if (controlE[3:0] == xor_op)
            xor_result = SrcAE ^ SrcBE;
        else if (controlE[3:0] == xori_op)
            xor_result = SrcAE ^ SignImmE;
        else if (controlE[3:0] == sll_op)
            shift_result = WriteDataE << shamtE;
        else if (controlE[3:0] == sllv_op)
            shift_result = WriteDataE << SrcAE;
        else if (controlE[3:0] == srl_op)
            shift_result = WriteDataE >> shamtE;
        else if (controlE[3:0] == srlv_op)
            shift_result = WriteDataE >> SrcAE;
        else if (controlE[3:0] == sra_op)
            shift_result = WriteDataE >>> shamtE;
        else if (controlE[3:0] == srav_op)
            shift_result = WriteDataE >>> SrcAE;
    end

    /*
    signal[4] -> unsign
    signal[3] -> isxor
    signal[2] -> isless
    signal[1] -> shift
    signal[0] -> arithm
    */
    wire [31:0] result_alu;
    wire [2:0] flag_alu, flag_tmp, flag_out;
    ALU_32bits alu2 (.ALU_op(controlE[3:0]), .regA(SrcAE), .regB(SrcBE), .flag(flag_alu),
            .Result(result_alu), .unsign(signalE[4]), .isless(signalE[2]));

    assign ALUOutE =  (signalE[3]) ? xor_result : (signalE[1]) ? shift_result
                        : (signalE[2]) ? result_alu :result_alu;
    assign flag_tmp = (signalE[0]) ? flag_alu : {flag_alu[2],{2{1'b0}}};
    // reverse
    assign flag_out = {flag_tmp[0],flag_tmp[1],flag_tmp[2]};

    assign ZeroE = flag_out[0];

    // next, we are going to realize EX/MEM buffer
    // Control wires
    /*
    control_in [9] RegWrite
    control_in [8] MemtoReg
    control_in [7] MemWrite
    control_in [6] Branch
    control_in [5] ALUSrc
    control_in [4] RegDst
    control_in [3:0] ALUControl
    */
    wire ZeroM;
    wire [31:0] ALUOutM;
    wire [64:0] EditSerialM;
    wire [4:0] WriteRegM;
    wire [3:0] controlM;

    regBuff_Ex_MEM b3(.clk(clk), .control_in(controlE[9:6]), .Zero_in(ZeroE), 
            .ALUOut_in(ALUOutE), .WriteData_in(WriteDataE),
            .WriteReg_in(WriteRegE), .PCBranch_in(PCBranchE),
            //========================================================================
            .control_out(controlM), .Zero_out(ZeroM),
            .ALUOut_out(ALUOutM), .EditSerial_out(EditSerialM), 
            .WriteReg_out(WriteRegM), .PCBranch_out(PCBranchM));

    /* ----------MEM stage---------- */
    //reg reset = LOW;
    wire [31:0] ReadDataM, ALUOutM_delay;
    wire [1:0] controlM_delay;
    wire [4:0] WriteRegM_delay;

    //assign PCSrcM = controlM[0] & ZeroM;
    // Implementation of main memory
    MainMemory MMEM(.CLOCK(clk), .RESET(RESET), .ENABLE(HIGH), .FETCH_ADDRESS(ALUOutM>>>2),
            .EDIT_SERIAL(EditSerialM), .DATA(ReadDataM));

    MEMBuff MB(.clk(clk), .control_in(controlM[3:2]), .ALUOut_in(ALUOutM), 
            .WriteReg_in(WriteRegM), .control_out(controlM_delay),
            .ALUOut_out(ALUOutM_delay), .WriteReg_out(WriteRegM_delay));
    
    // Next, we implement MEM/WB buffer
    wire [31:0] ALUOutW, ReadDataW;
    wire [1:0] controlW;

    regBuff_MEM_WB b4(.clk(clk), .control_in(controlM_delay), .ALUOut_in(ALUOutM_delay),
            .ReadData_in(ReadDataM), .WriteReg_in(WriteRegM_delay), .ALUOut_out(ALUOutW),
            .control_out(controlW), .ReadData_out(ReadDataW), 
            .WriteReg_out(WriteRegW));

    /* ----------WB stage---------- */
    MUX_2to1_32bits mux4(.A(ALUOutW),.B(ReadDataW),.out(ResultW),.sel(controlW[0]));  

    /* ---------- Output ---------- */

endmodule

module PC_buff (
    input clk,
    input [31:0] PC_in,
    output reg [31:0] PC_out,
    output reg flagF
);
    //reg [31:0] PC_tmp = 'b0;
    reg flag = 0; reg flag2 = 1'b0;
    always @(posedge clk ) begin //#30
        if (flag == 0) begin
            PC_out <= 'b0;
            flag = 1;
        end 
        else PC_out <= PC_in;
        flag2 = ~flag2;
        flagF = flag2;
        //PC_out <= PC_tmp;
    end
endmodule

module regBuff_IF_ID (clk,inst_in,inst_out,addr_in,addr_out);
    input clk;
    input [31:0] inst_in, addr_in;
    output reg [31:0] addr_out, inst_out;

    // The tmp is used to store data and is initialized to 0
    reg [31:0] inst_tmp = 'b0;
    reg [31:0] addr_tmp = 'b0;
    integer cnt = 0;
    always @(posedge clk) begin
        if (cnt < 2) begin
            inst_out <= 32'b111111; 
            addr_out <= 'b0;          
        end 
        else begin
            if (inst_tmp == inst_in) inst_out <= 32'b111111;
            else inst_out <= inst_in;

            if (addr_tmp == addr_in) addr_out <= 'b0;
            else addr_out <= addr_in; 

            inst_tmp <= inst_in;
            addr_tmp <= addr_in;                        
        end  
        //inst_out <= inst_tmp;
        //addr_out <= addr_tmp;
        cnt = cnt + 1;
    end
endmodule

module ControlUnit (
    input [5:0] opcode, funct,
    //output reg RegWriteD,MemtoRegD,MemWriteD,BranchD,ALUSrcD,RegDstD,
    output reg [9:0] control,
    output reg [4:0] signal
);
    reg unsign = 1'b0; reg isxor = 1'b0; reg isless = 1'b0;
    reg shift = 1'b0; reg arithm = 1'b0;

    reg RegWriteD = 1'b0; reg MemtoRegD = 1'b0;
    reg MemWriteD = 1'b0; reg BranchD = 1'b0;
    reg ALUSrcD = 1'b0; reg RegDstD = 1'b0;
    reg [3:0] ALUControlD = 4'b0;

    parameter and_op = 4'b0;
    parameter or_op = 4'b0001;
    parameter add_op = 4'b0010;
    parameter sub_op = 4'b0110;
    parameter slt_op = 4'b0111;
    parameter nor_op = 4'b1100;
    parameter xor_op = 4'b1000;
    parameter xori_op = 4'b1101;

    parameter sll_op = 4'b0011;
    parameter sllv_op = 4'b1001;
    parameter srl_op = 4'b0100;
    parameter srlv_op = 4'b1010;
    parameter sra_op = 4'b0101;
    parameter srav_op = 4'b1011;
    
    always @(*) begin
        // R type instruction
        if (opcode == 6'b0) begin
            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b0; RegDstD = 1'b1;
            // add
            if (funct == 6'b100000) begin
                ALUControlD = add_op;
                arithm = 1'b1; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
                
            end
            // addu
            else if (funct == 6'b100001) begin
                ALUControlD = add_op;
                arithm = 1'b1; unsign = 1'b1; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;

            end
            // sub
            else if (funct == 6'b100010) begin
                ALUControlD = sub_op;
                arithm = 1'b1; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;

            end
            // subu
            else if (funct == 6'b100011) begin
                ALUControlD = sub_op;
                arithm = 1'b1; unsign = 1'b1; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
            end
            // and
            else if (funct == 6'b100100) begin
                ALUControlD = and_op;
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
            end
            // or
            else if (funct == 6'b100101) begin
                ALUControlD = or_op;
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
            end
            // nor
            else if (funct == 6'b100111) begin
                ALUControlD = nor_op;
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
            end
            // xor
            else if (funct == 6'b100110) begin
                //xor_result = regA_in ^ regB_in;
                ALUControlD = xor_op; // Add or other i wish
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b1;
                isless = 1'b0; shift = 1'b0;

            end
            //slt
            else if (funct == 6'b101010) begin
                ALUControlD = slt_op;
                arithm = 1'b1; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b1; shift = 1'b0;
            end
            // sltu
            else if (funct == 6'b101011) begin
                ALUControlD = slt_op;
                arithm = 1'b1; unsign = 1'b1; isxor = 1'b0;
                isless = 1'b1; shift = 1'b0;
            end
            // sll
            else if (funct == 6'b0) begin
                // shift_result = regB_in << shamt;
                ALUControlD = sll_op;
                arithm = 1'b0; unsign = 1'b1; isxor = 1'b0;
                isless = 1'b0; shift = 1'b1;
            end
            // sllv
            else if (funct == 6'b000100) begin
                ALUControlD = sllv_op; // r
                arithm = 1'b0; unsign = 1'b1; isxor = 1'b0;
                isless = 1'b0; shift = 1'b1;
            end
            // srl
            else if (funct == 6'b000010) begin
                //shift_result = regB_in >> shamt;
                ALUControlD = srl_op; // r
                arithm = 1'b0; unsign = 1'b1; isxor = 1'b0;
                isless = 1'b0; shift = 1'b1;
                
            end
            // srlv
            else if (funct == 6'b000110) begin
                //shift_result = regB_in >> regA_in;
                ALUControlD = srlv_op; // r
                arithm = 1'b0; unsign = 1'b1; isxor = 1'b0;
                isless = 1'b0; shift = 1'b1;
            end
            // sra
            else if (funct == 6'b000011) begin
                //shift_result = regB_in >>> shamt;
                ALUControlD = sra_op; // r
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b1;
            end
            // srav
            else if (funct == 6'b000111) begin
                //shift_result = regB_in >>> regA_in;
                ALUControlD = srav_op; // r
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b1;
            end
            // jalr
            else if (funct == 6'b001001) begin
                ALUControlD = sll_op;
                RegWriteD = 1'b0;
                RegDstD = 1'b0;
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
            end
            // jr
            else if (funct == 6'b001000) begin
                ALUControlD = sll_op;
                RegWriteD = 1'b0;
                RegDstD = 1'b0;
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
            end
            // INVALID
            else if (funct == 6'b111111) begin
                ALUControlD = 4'b0;
                RegWriteD = 1'b0;
                RegDstD = 1'b0;
                arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
                isless = 1'b0; shift = 1'b0;
            end
            

        end
        // I instructions
        // addi
        else if (opcode == 6'b001000) begin
            //regB_in = {{16{imm[15]}}, imm};
            ALUControlD = add_op;
            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b1; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end
        // addiu
        else if (opcode == 6'b001001) begin
            //regB_in = {{16{1'b0}}, imm};
            ALUControlD = add_op;
            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b1; unsign = 1'b1; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end
        // andi
        else if (opcode == 6'b001100) begin
            //regB_in = {{16{imm[15]}}, imm};
            ALUControlD = and_op;
            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end
        // ori
        else if (opcode == 6'b001101) begin
            //regB_in = {{16{imm[15]}}, imm};
            ALUControlD = or_op;
            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end
        // xori
        else if (opcode == 6'b001110) begin
            //isxor = 1'b1;
            //regB_in = {{16{imm[15]}}, imm};
            //xor_result = regA_in ^ regB_in;
            ALUControlD = xori_op; // Add or other i wish
            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b0; unsign = 1'b0; isxor = 1'b1;
            isless = 1'b0; shift = 1'b0;
        end
        // beq + bne
        else if (opcode == 6'b000100 || opcode == 6'b000101) begin
            //arithm = 1'b1;
            ALUControlD = sub_op;
            RegWriteD = 1'b0; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b1;
            ALUSrcD = 1'b0; RegDstD = 1'b0;
            arithm = 1'b1; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end
        // slti
        else if (opcode == 6'b001010) begin
            //regB_in = {{16{imm[15]}}, imm};
            ALUControlD = sub_op;
            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b1; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b1; shift = 1'b0;
        end
        // sltiu
        else if (opcode == 6'b001011) begin
            //regB_in = {{16{1'b0}}, imm};
            ALUControlD = sub_op;

            RegWriteD = 1'b1; MemtoRegD = 1'b0;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b1; unsign = 1'b1; isxor = 1'b0;
            isless = 1'b1; shift = 1'b0;
        end
        // lw
        else if (opcode == 6'b100011) begin
            //regB_in = {{16{imm[15]}}, imm};
            ALUControlD = add_op;
            RegWriteD = 1'b1; MemtoRegD = 1'b1;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end
        // sw
        else if (opcode == 6'b101011) begin
            //regB_in = {{16{imm[15]}}, imm};
            ALUControlD = add_op;
            RegWriteD = 1'b0; MemtoRegD = 1'b1;
            MemWriteD = 1'b1; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end
        // j
        else if (opcode == 6'b000010) begin
            ALUControlD = sll_op;
            RegWriteD = 1'b0; MemtoRegD = 1'b1;
            MemWriteD = 1'b0; BranchD = 1'b0;
            ALUSrcD = 1'b1; RegDstD = 1'b0;
            arithm = 1'b0; unsign = 1'b0; isxor = 1'b0;
            isless = 1'b0; shift = 1'b0;
        end

        signal = {unsign,isxor,isless,shift,arithm};
        control = {RegWriteD,MemtoRegD,MemWriteD,BranchD,ALUSrcD,
                RegDstD,ALUControlD};
    end

    /*
    signal[4] -> unsign
    signal[3] -> isxor
    signal[2] -> isless
    signal[1] -> shift
    signal[0] -> arithm
    */

endmodule

module RegFile (
    input clk, WE3,
    input [4:0] A1,A2,A3,
    input [31:0] WD3,
    output reg [31:0] RD1, RD2
);
    reg [31:0] zero = 'b0; reg [31:0] at = 'b0; reg [31:0] v0 = 'b0;
    reg [31:0] v1 = 'b0; reg [31:0] a0 = 'b0; reg [31:0] a1 = 'b0;
    reg [31:0] a2 = 'b0; reg [31:0] a3 = 'b0; reg [31:0] t0 = 'b0;
    reg [31:0] t1 = 'b0; reg [31:0] t2 = 'b0; reg [31:0] t3 = 'b0;
    reg [31:0] t4 = 'b0; reg [31:0] t5 = 'b0; reg [31:0] t6 = 'b0;
    reg [31:0] t7 = 'b0; reg [31:0] s0 = 'b0; reg [31:0] s1 = 'b0;
    reg [31:0] s2 = 'b0; reg [31:0] s3 = 'b0; reg [31:0] s4 = 'b0;
    reg [31:0] s5 = 'b0; reg [31:0] s6 = 'b0; reg [31:0] s7 = 'b0;
    reg [31:0] t8 = 'b0; reg [31:0] t9 = 'b0; reg [31:0] k0 = 'b0;
    reg [31:0] k1 = 'b0; reg [31:0] gp = 'b0; reg [31:0] sp = 'b0;
    reg [31:0] fp = 'b0; reg [31:0] ra = 'b0;

    always @(posedge clk ) begin
        // To achieve the functionality, we use = rather than <=
        if (WE3 == 1'b1) begin
        case(A3)
        5'b0: ; // we cannot write zero reg
        5'b1: at = WD3;
        5'b10: v0 = WD3;
        5'b11: v1 = WD3;
        5'b100: a0 = WD3;
        5'b101: a1 = WD3;
        5'b110: a2 = WD3;
        5'b111: a3 = WD3;
        5'b1000: t0 = WD3;
        5'b1001: t1 = WD3;
        5'b1010: t2 = WD3;
        5'b1011: t3 = WD3;
        5'b1100: t4 = WD3;
        5'b1101: t5 = WD3;
        5'b1110: t6 = WD3;
        5'b1111: t7 = WD3;
        5'b10000: s0 = WD3;
        5'b10001: s1 = WD3;
        5'b10010: s2 = WD3;
        5'b10011: s3 = WD3;
        5'b10100: s4 = WD3;
        5'b10101: s5 = WD3;
        5'b10110: s6 = WD3;
        5'b10111: s7 = WD3;
        5'b11000: t8 = WD3;
        5'b11001: t9 = WD3;
        5'b11010: k0 = WD3;
        5'b11011: k1 = WD3;
        5'b11100: gp = WD3;
        5'b11101: sp = WD3;
        5'b11110: fp = WD3;
        5'b11111: ra = WD3;
        // default: ;
        endcase
        end

        case(A1)
        5'b0: RD1 = zero;
        5'b1: RD1 = at;
        5'b10: RD1 = v0;
        5'b11: RD1 = v1;
        5'b100: RD1 = a0;
        5'b101: RD1 = a1;
        5'b110: RD1 = a2;
        5'b111: RD1 = a3;
        5'b1000: RD1 = t0;
        5'b1001: RD1 = t1;
        5'b1010: RD1 = t2;
        5'b1011: RD1 = t3;
        5'b1100: RD1 = t4;
        5'b1101: RD1 = t5;
        5'b1110: RD1 = t6;
        5'b1111: RD1 = t7;
        5'b10000: RD1 = s0;
        5'b10001: RD1 = s1;
        5'b10010: RD1 = s2;
        5'b10011: RD1 = s3;
        5'b10100: RD1 = s4;
        5'b10101: RD1 = s5;
        5'b10110: RD1 = s6;
        5'b10111: RD1 = s7;
        5'b11000: RD1 = t8;
        5'b11001: RD1 = t9;
        5'b11010: RD1 = k0;
        5'b11011: RD1 = k1;
        5'b11100: RD1 = gp;
        5'b11101: RD1 = sp;
        5'b11110: RD1 = fp;
        5'b11111: RD1 = ra;
        default: RD1 = 'b0;
        endcase

        case(A2)
        5'b0: RD2 = zero;
        5'b1: RD2 = at;
        5'b10: RD2 = v0;
        5'b11: RD2 = v1;
        5'b100: RD2 = a0;
        5'b101: RD2 = a1;
        5'b110: RD2 = a2;
        5'b111: RD2 = a3;
        5'b1000: RD2 = t0;
        5'b1001: RD2 = t1;
        5'b1010: RD2 = t2;
        5'b1011: RD2 = t3;
        5'b1100: RD2 = t4;
        5'b1101: RD2 = t5;
        5'b1110: RD2 = t6;
        5'b1111: RD2 = t7;
        5'b10000: RD2 = s0;
        5'b10001: RD2 = s1;
        5'b10010: RD2 = s2;
        5'b10011: RD2 = s3;
        5'b10100: RD2 = s4;
        5'b10101: RD2 = s5;
        5'b10110: RD2 = s6;
        5'b10111: RD2 = s7;
        5'b11000: RD2 = t8;
        5'b11001: RD2 = t9;
        5'b11010: RD2 = k0;
        5'b11011: RD2 = k1;
        5'b11100: RD2 = gp;
        5'b11101: RD2 = sp;
        5'b11110: RD2 = fp;
        5'b11111: RD2 = ra;
        default: RD2 = 'b0;
        endcase
    end
endmodule

module regBuff_ID_EX (clk,control_in,control_out,SignImm_in,Rt_in,
                Rd_in,Rt_out,Rd_out,SignImm_out,PCPlus4_in,PCPlus4_out,
                RD1_in,RD1_out,RD2_in,RD2_out,signal_in,signal_out,
                shamt_in,shamt_out);

    input clk;
    /*
    control_in [9] RegWrite
    control_in [8] MemtoReg
    control_in [7] MemWrite
    control_in [6] Branch
    control_in [5] ALUSrc
    control_in [4] RegDst
    control_in [3:0] ALUControl
    */
    input [9:0] control_in;
    input [4:0] Rt_in ,Rd_in, signal_in, shamt_in;
    input [31:0] SignImm_in, PCPlus4_in, RD1_in, RD2_in;
    output reg [9:0] control_out;
    output reg [4:0] Rt_out, Rd_out, signal_out, shamt_out;
    output reg [31:0] SignImm_out, PCPlus4_out, RD1_out, RD2_out;

    integer cnt = 0;

    always @(posedge clk ) begin
        if (cnt < 4) begin
            control_out <= 10'b0;
            Rt_out <= 5'b0; Rd_out <= 5'b0;
            signal_out <= 5'b0; shamt_out <= 5'b0;
            SignImm_out <= 'b0; PCPlus4_out <= 'b0;
            RD1_out <= 'b0; RD2_out <= 'b0;
        end
        else begin
            control_out <= control_in;
            Rt_out <= Rt_in; Rd_out <= Rd_in;
            SignImm_out <= SignImm_in;
            PCPlus4_out <= PCPlus4_in;
            RD1_out <= RD1_in; RD2_out <= RD2_in;
            shamt_out <= shamt_in;
            signal_out <= signal_in;
        end     
        cnt = cnt + 1;
    end  
endmodule

module MUX_2to1_5bits(A, B, sel, out);
    // sel = 0 -> A
    // sel = 1 -> B
    input [4:0] A,B;
    input sel;
    output [4:0] out;
    assign out = sel ? B : A;
endmodule

module regBuff_Ex_MEM (clk, control_in, control_out, Zero_in, Zero_out, ALUOut_in,
             ALUOut_out, WriteData_in, EditSerial_out, WriteReg_in,
             WriteReg_out, PCBranch_in, PCBranch_out);
    /*
    control_in[3] -> RegWrite
    control_in[2] -> MemtoReg
    control_in[1] -> MemWrite
    control_in[0] -> BranchM
    */
    input [3:0] control_in;
    input Zero_in, clk;
    input [31:0] ALUOut_in, WriteData_in , PCBranch_in;
    input [4:0] WriteReg_in;
    output reg [3:0] control_out; 
    output reg Zero_out;
    output reg [64:0] EditSerial_out;
    output reg [31:0] ALUOut_out, PCBranch_out;
    output reg [4:0] WriteReg_out;

    integer cnt = 0;
    always @(posedge clk ) begin
        if (cnt < 5) begin
            control_out = 4'b0; Zero_out = 1'b0;
            ALUOut_out = 'b0; EditSerial_out = 65'b0;
            PCBranch_out = 'b0; WriteReg_out = 5'b0;
        end
        else begin
            control_out <= control_in;
            Zero_out <= Zero_in;
            ALUOut_out <= ALUOut_in;
            EditSerial_out = {control_in[1],ALUOut_in>>>2,WriteData_in};
            PCBranch_out <= PCBranch_in;
            WriteReg_out <= WriteReg_in;
        end       
        cnt = cnt + 1;
    end
    
endmodule

module regBuff_MEM_WB (clk, control_in, control_out, ALUOut_in, ALUOut_out,
              ReadData_in, ReadData_out, WriteReg_in, WriteReg_out);
    /*
    control_in[1] -> RegWrite
    control_in[0] -> MemtoReg
    */
    input clk;
    input [1:0] control_in;
    input [31:0] ALUOut_in, ReadData_in;
    input [4:0] WriteReg_in;
    output reg [1:0] control_out;
    output reg [31:0] ALUOut_out, ReadData_out;
    output reg [4:0] WriteReg_out;

    integer cnt = 0;
    always @(posedge clk ) begin
        if (cnt < 7) begin
            control_out <= 2'b0;
            ALUOut_out <= 'b0;
            ReadData_out <= 'b0;
            WriteReg_out <= 'b0;
        end
        else begin
            control_out <= control_in;
            ALUOut_out <= ALUOut_in;
            ReadData_out <= ReadData_in;
            WriteReg_out <= WriteReg_in;
        end        
        cnt = cnt + 1;
    end
endmodule

module branchBuff (
    input clk,
    input [31:0] branch_in,
    output reg [31:0] branch_out
);

    always @(posedge clk ) begin
        branch_out <= branch_in;
    end
endmodule

module EXBuff (
    input clk,
    input [9:0] control_in,
    input [4:0] Rt_in, Rd_in, signal_in, shamt_in,
    input [31:0] SignImm_in, PCPlus4_in,
    output reg [9:0] control_out,
    output reg [4:0] Rt_out, Rd_out, signal_out, shamt_out,
    output reg [31:0] SignImm_out, PCPlus4_out
);
    integer cnt = 0;

    always @(posedge clk ) begin
        if (cnt < 3) begin
            control_out <= 10'b0;
            Rt_out <= 5'b0; Rd_out <= 5'b0; 
            SignImm_out <= 'b0;
            PCPlus4_out <= 'b0;
            signal_out <= 5'b0;
            shamt_out <= 5'b0;
        end
        else begin
            control_out <= control_in;
            Rt_out <= Rt_in; Rd_out <= Rd_in;
            SignImm_out <= SignImm_in;
            PCPlus4_out <= PCPlus4_in;
            signal_out <= signal_in;
            shamt_out <= shamt_in;
        end
        cnt = cnt + 1;
    end
endmodule

module MEMBuff (
    input clk,
    input [1:0] control_in,
    input [31:0] ALUOut_in,
    input [4:0] WriteReg_in,
    output reg [1:0] control_out,
    output reg [31:0] ALUOut_out,
    output reg [4:0] WriteReg_out
);
    integer cnt = 0;
    always @(posedge clk ) begin
        if (cnt < 6) begin
            control_out <= 2'b0;
            ALUOut_out <= 'b0;
            WriteReg_out <= 5'b0;
        end
        else begin
            control_out <= control_in;
            ALUOut_out <= ALUOut_in;
            WriteReg_out <= WriteReg_in;
        end
        cnt = cnt + 1;
    end
endmodule

module adder (
    input flag,
    input [31:0] A,B,
    output reg [31:0] SUM   
);
    always @(*) begin
        if(flag == 1'b1) SUM = A + 'b0;
        else SUM = A+B;           
    end 
endmodule