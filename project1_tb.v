`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.07.2025 02:07:26
// Design Name: 
// Module Name: project1_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Modified testbench for CORDIC-based implementation
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module project1_tb();
    reg [3:0] in;
    reg [4:0] noise1;
    reg clk;
    reg rst;
    reg [15:0]freq;
    reg start;
    wire [3:0] out;
    wire error1bit;
    wire error2bit;
    wire errorparity;
    wire done;
  
    project1 dut(
        .clk(clk),
        .rst(rst),
        .sedbec_in(in),
        .noise1(noise1),
        .start(start),
        .freq(freq),
        .data_o(out),
        .error1bit(error1bit),
        .error2bit(error2bit),
        .errorparity(errorparity),
        .done(done)
    );
    
    integer success_count = 0;
    integer error_count = 0;
    integer i;
    
  
    initial begin 
        clk = 0;
        freq = 16'd4096;
        forever #5 clk = ~clk;
    end
    

    initial begin
        rst = 1;
        #100 rst = 0;
    end
    
 
    initial begin
        start = 0;
        
        wait(!rst);
        #50;
        
        for(i = 0; i < 16; i = i + 1) begin
            @(posedge clk);
            in = i;
            noise1 = 5'b00001;
            start = 1;
            
           repeat(45) @(posedge clk);
            start = 0;
            
            wait(done);
            
            // Wait a few cycles before checking
            repeat(30) @(posedge clk);
            
            compare_data(in, out, 1, 0, 0);
            
            repeat(10) @(posedge clk);
        end
        
        $display("Test completed: %d successes, %d errors", success_count, error_count);
        $finish;
    end
    
    task compare_data(input [3:0] in1, input [3:0] out1, input error1, input error2, input errorpari);
        begin
            if(!error2) begin
                if((in1 == out1) && (error1 == error1bit) && (errorpari == errorparity)) begin
                    success_count = success_count + 1;
                    $display("SUCCESS: in=%b, out=%b", in1, out1);
                end else begin
                    error_count = error_count + 1;
                    $display("ERROR: in=%b, out=%b, expected_out=%b", in1, out1, in1);
                end
            end else begin 
                if(error2 == error2bit) begin 
                    success_count = success_count + 1;
                    $display("SUCCESS: 2-bit error detected correctly");
                end else begin
                    error_count = error_count + 1;
                    $display("ERROR: 2-bit error detection failed");
                end
            end
            $display("1bit_err=%b, 2bit_err=%b, parity_err=%b", error1bit, error2bit, errorparity);
        end
    endtask
    
endmodule