`timescale 100fs/100fs

module test_CPU;
    reg clk, reset, clk2;
    //reg cnt = 0;
    integer cnt,i,file,cycle;
    // uut: unit under testing
    cpu uut(.clk(clk), .RESET(reset));

    //always #50 clk = ~clk;
    initial begin
        $dumpfile("test_CPU.vcd");
        $dumpvars(0, test_CPU);
        clk = 0;
        reset = 0;
        cnt = 0;
        cycle = 0;
        file = $fopen("RAM_out.txt","w");

        #50 clk = 1;
        #50 clk = 0;

        // When there's an empty instruction, we stop
        while (uut.InstrD !== 32'hffff_ffff) begin
            #50 clk = ~clk;
        end
        // The last few cycles are to finish last instr 
        while (cnt != 10) begin
            #50 clk = ~clk;
            cnt = cnt + 1;
        end

        for (i=0; i<512; i=i+1) begin
            $fwrite(file, "%b\n", uut.MMEM.DATA_RAM[i]);
            $display("%b",uut.MMEM.DATA_RAM[i]);
        end
        $fclose(file);
        $display("==============================");
        $display("Number of cycles:",cycle/2+4);
        $display("Test finished.");
        $finish;
    end

    always @(posedge clk ) begin
        cycle  = cycle + 1;
    end

endmodule
