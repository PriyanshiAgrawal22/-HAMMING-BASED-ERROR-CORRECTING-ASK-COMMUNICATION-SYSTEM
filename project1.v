// Code your design here
`timescale 1ns / 1ps

module hamming74en(
input [3:0]data,
output [6:0]o_hammingcode,
output parity
    );
    
reg p1,p2,p4;
always @(*)
begin
 p1 = data[0]^data[1]^data[3];
 p2 = data[0]^data[2]^data[3];
 p4 = data[1]^data[2]^data[3];
end

assign o_hammingcode = {data[3:1],p4,data[0],p2,p1};
assign parity = ^o_hammingcode;
endmodule

module noise(
input [7:0]data_in,
input [4:0]i_noise,
output [7:0]data_out
    );
 
reg [6:0]noise;
always @(*) begin 
case(i_noise[2:0])
  default: noise = {i_noise[3],6'b000000};
  3'd0: noise = {i_noise[3],6'b000000};
  3'd1: noise = {i_noise[3],6'b000001};
  3'd2: noise = {i_noise[3],6'b000010};
  3'd3: noise = {i_noise[3],6'b000100};
  3'd4: noise = {i_noise[3],6'b001000};
  3'd5: noise = {i_noise[3],6'b010000};
  3'd6: noise = {i_noise[3],6'b100000};
  3'd7: noise = {6'b100000,i_noise[3]};
endcase
end
assign data_out = data_in ^{i_noise[4],noise[6:0]};
endmodule

module hamming74dec(
input [6:0]data_in,
input i_parity,
output [3:0]data_dec,
output error_1bit,
output error_2bit,
output parity_error
    );
reg p1,p2,p4;
reg [6:0]syndrome;
wire [6:0]out_data;

always @(*) begin 
p1 = data_in[0]^data_in[2]^data_in[4]^data_in[6];
p2 = data_in[1]^data_in[2]^data_in[5]^data_in[6];
p4 = data_in[3]^data_in[4]^data_in[5]^data_in[6];
end
always @(*)begin
case({p4,p2,p1})
default: syndrome = 7'b0;
3'b000: syndrome = 7'b0;
3'b001: syndrome = 7'b0000001;
3'b010: syndrome = 7'b0000010;
3'b011: syndrome = 7'b0000100;
3'b100: syndrome = 7'b0001000;
3'b101: syndrome = 7'b0010000;
3'b110: syndrome = 7'b0100000;
3'b111: syndrome = 7'b1000000;
endcase
end
wire overall_parity;
assign out_data = syndrome^data_in;
assign overall_parity = ^{i_parity,data_in[6:0]};
assign error_1bit = (syndrome!= 7'b0);
assign error_2bit = ((syndrome!=7'b0) && (~overall_parity));
assign parity_error = ((syndrome==7'b0) && (overall_parity));
assign data_dec = {out_data[6:4],out_data[2]};
endmodule

module sinewave(
    input wire clk,
    input wire reset,
    input wire [15:0] freq,
    output reg [7:0] sine_out
);

    reg [15:0] phase_acc;
    wire [3:0] addr;
    reg [7:0] sine_lut [0:15];

    assign addr = phase_acc[15:12];

    initial begin
        sine_lut[ 0] = 8'd128;
        sine_lut[ 1] = 8'd176;
        sine_lut[ 2] = 8'd218;
        sine_lut[ 3] = 8'd245;
        sine_lut[ 4] = 8'd255;
        sine_lut[ 5] = 8'd245;
        sine_lut[ 6] = 8'd218;
        sine_lut[ 7] = 8'd176;
        sine_lut[ 8] = 8'd128;
        sine_lut[ 9] = 8'd80;
        sine_lut[10] = 8'd38;
        sine_lut[11] = 8'd11;
        sine_lut[12] = 8'd0;
        sine_lut[13] = 8'd11;
        sine_lut[14] = 8'd38;
        sine_lut[15] = 8'd80;
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            phase_acc <= 0;
        else
            phase_acc <= phase_acc + freq;
    end

    always @(posedge clk) begin
        sine_out <= sine_lut[addr];
    end

endmodule


module ask_modulator(
    input  clk,
    input  rst,
    input  data_bit,
    input  start,
    input [15:0]freq,
    output reg [7:0] ask_out,
    output reg done
);
    wire [7:0] sine_value;
    reg active;
    reg [7:0] sample_count;
    parameter SAMPLES_PER_BIT = 128;  // Define how many samples per bit

    sinewave rom(clk, rst, freq, sine_value);  // Fixed: was 'reset', now 'rst'

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ask_out <= 0;
            active <= 0;
            done <= 0;
            sample_count <= 0;
        end else begin
            if (start && !active) begin
                active <= 1;
                done <= 0;
                sample_count <= 0;
            end else if (active) begin
                ask_out <= data_bit ? sine_value : 8'd0;
                sample_count <= sample_count + 1;
                
                if (sample_count >= SAMPLES_PER_BIT - 1) begin
                    done <= 1;
                    active <= 0;
                    sample_count <= 0;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule

module ask_demodulator(
    input clk,
    input  rst,
    input  [7:0] received_signal,
    input  start,
    output reg data_out,
    output reg done
);
 parameter samples=128;
    reg [7:0] counter;
    reg [31:0] i;
    reg active;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            i <= 0;
            data_out <= 0;
            done <= 0;
            active <= 0;
        end else begin
            if (start && !active) begin
                active <= 1;
                counter <= 0;
                i <= 0;
                done <= 0;
            end else if (active) begin
                if (i < samples) begin
                    if (received_signal> 8'd128)
                        counter <= counter + 1;
                    i <= i + 1;
                end else begin
                    data_out <= (counter > (samples>>2));  
                    done <= 1;
                    active <= 0;
                    i <= 0;
                    counter <= 0;
                end
            end else begin
                done <= 0;
            end
        end
    end
endmodule


module project1(
    input clk,
    input rst,
    input [3:0] sedbec_in,
    input [4:0] noise1,
    input start,
    input [15:0]freq,
    output [3:0] data_o,
    output error1bit,
    output error2bit,
    output errorparity,
    output done
);
    // Encoded data
    wire [6:0] encoded_o;
    wire enc_parity;
    wire [7:0] noise_o;
    wire [7:0] demodu_o;
    
    // Modulator/Demodulator control signals
    wire [7:0] mod_start, mod_done;
    wire [7:0] demod_start, demod_done;
    
    // ASK modulator outputs
    wire [7:0] ask_out0, ask_out1, ask_out2, ask_out3;
    wire [7:0] ask_out4, ask_out5, ask_out6, ask_out7;
    
    // State machine for controlling the pipeline
    reg [2:0] state;
    reg [7:0] mod_start_reg, demod_start_reg;
    reg done_reg;
    
    localparam IDLE = 3'd0, ENCODE = 3'd1, MODULATE = 3'd2, 
               DEMODULATE = 3'd3, DECODE = 3'd4, DONE = 3'd5;

    // Hamming encoder
    hamming74en en(sedbec_in, encoded_o, enc_parity);
    
    // Noise injection
    noise noi({enc_parity, encoded_o}, noise1, noise_o);
    
    // ASK modulators and demodulators
    ask_modulator a_0(clk, rst, noise_o[0], mod_start[0], freq,ask_out0, mod_done[0]);
    ask_demodulator b_0(clk, rst, ask_out0, demod_start[0], demodu_o[0], demod_done[0]);
    
    ask_modulator a_1(clk, rst, noise_o[1], mod_start[1], freq,ask_out1, mod_done[1]);
    ask_demodulator b_1(clk, rst, ask_out1, demod_start[1], demodu_o[1], demod_done[1]);
    
    ask_modulator a_2(clk, rst, noise_o[2], mod_start[2], freq,ask_out2, mod_done[2]);
    ask_demodulator b_2(clk, rst, ask_out2, demod_start[2], demodu_o[2], demod_done[2]);
    
    ask_modulator a_3(clk, rst, noise_o[3], mod_start[3], freq,ask_out3, mod_done[3]);
    ask_demodulator b_3(clk, rst, ask_out3, demod_start[3], demodu_o[3], demod_done[3]);
    
    ask_modulator a_4(clk, rst, noise_o[4], mod_start[4], freq,ask_out4, mod_done[4]);
    ask_demodulator b_4(clk, rst, ask_out4, demod_start[4], demodu_o[4], demod_done[4]);
    
    ask_modulator a_5(clk, rst, noise_o[5], mod_start[5], freq,ask_out5, mod_done[5]);
    ask_demodulator b_5(clk, rst, ask_out5, demod_start[5], demodu_o[5], demod_done[5]);
    
    ask_modulator a_6(clk, rst, noise_o[6], mod_start[6], freq,ask_out6, mod_done[6]);
    ask_demodulator b_6(clk, rst, ask_out6, demod_start[6], demodu_o[6], demod_done[6]);
    
    ask_modulator a_7(clk, rst, noise_o[7], mod_start[7], freq,ask_out7, mod_done[7]);
    ask_demodulator b_7(clk, rst, ask_out7, demod_start[7], demodu_o[7], demod_done[7]);
    
    // Control signals
    assign mod_start = mod_start_reg;
    assign demod_start = demod_start_reg;
    assign done = done_reg;
    
    // State machine for pipeline control
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            mod_start_reg <= 8'h00;
            demod_start_reg <= 8'h00;
            done_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 0;  // Clear done immediately when idle
                    if (start) begin
                        state <= ENCODE;
                    end
                end
                
                ENCODE: begin
                    // Encoding is combinational, move to modulation
                    state <= MODULATE;
                    mod_start_reg <= 8'hFF;  // Start all modulators
                end
                
                MODULATE: begin
                    if (mod_start_reg != 8'h00) begin
                        mod_start_reg <= 8'h00;  // Clear start signals after one cycle
                    end else if (&mod_done) begin  // All modulators done
                        state <= DEMODULATE;
                        demod_start_reg <= 8'hFF;  // Start all demodulators
                    end
                end
                
                DEMODULATE: begin
                    if (demod_start_reg != 8'h00) begin
                        demod_start_reg <= 8'h00;  // Clear start signals after one cycle
                    end else if (&demod_done) begin  // All demodulators done
                        state <= DECODE;
                    end
                end
                
                DECODE: begin
                    // Give one cycle for decoding to settle
                    state <= DONE;
                    done_reg <= 1;
                end
                
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done_reg <= 0;
                    end
                end
            endcase
        end
    end
    
    // Hamming decoder
    hamming74dec dec(demodu_o[6:0], demodu_o[7], data_o, error1bit, error2bit, errorparity);
    
endmodule