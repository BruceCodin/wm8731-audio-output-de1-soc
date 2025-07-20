/*
 * Audio_Gen
 * ----------------
 * Description: 
 * This module provides the DSP / PCM Audio Interface 
 * Receives 12MHz clock and generates sample rate 48kSps 
 * ----------------
 * Referenes: This module is heavily adapted from the VHDL code referenced below
 * AntonZero, AntonZero/WM8731-Audio-codec-on-DE10Standard-FPGA-board. VHDL. Accessed: Apr. 30, 2025. [Online]. Available: https://github.com/AntonZero/WM8731-Audio-codec-on-DE10Standard-FPGA-board
 * ‘Tutorial: Playing audio through WM8731 using Terasic DE10-Standard FPGA development board - YouTube’. Accessed: Apr. 30, 2025. [Online]. Available: https://www.youtube.com/watch?v=zzIi7ErWhAA&t=251s&ab_channel=Toni
 */

 
 module Audio_Gen ( // DSP Audio Interface module
  // Declare Input and Output Ports
  input wire clk_12, // 12MHz clock required for WM8731
  input wire rst,
  input wire [31:0] aud_data, // Audio data Input
  output wire aud_bk, // Interface Clock 
  output reg aud_dalr, // DAC Syn clock
  output reg aud_dadat // DAC data Output, 32bit Total (16 bit for Right and 16 bit for Left audio channels) 
 );

 // Counters, Regs, Signals and Wires
 reg sample_flag; // Sample flag 
 reg [5:0] data_index;
 reg [15:0] da_data;
 reg [8:0] aud_prscl;  // Counter for 48K sample rate
 reg [31:0] da_data_out; // Holds 32bit sampled audio data
 reg clk_en; 
 
 assign aud_bk = clk_12; // 12MHz clock assigned to the Interface clock for WM8731
 
 always @(negedge clk_12 or posedge rst) begin 
     if (rst) begin
	       sample_flag <= 0;
			 data_index <= 0;
			 da_data <= 0; 
			 aud_prscl <= 0;
			 da_data_out <= 0;
			 clk_en <= 0;
			 aud_dalr <= 0;
			 aud_dadat <= 0;
	  end else begin 
	      aud_dalr <= clk_en; // will flag new sample start
			
	      if (aud_prscl<250) begin // 48k sample rate 
			    aud_prscl <= aud_prscl + 1;
				 clk_en <= 0;
			end else begin 
			    aud_prscl <= 0;
				 clk_en <= 1;
				 da_data_out <= aud_data; // gets the sample
			end
			
			if (clk_en) begin // send new sample
			    sample_flag <= 1;
				 data_index <= 6'd31; 
			end
			
			if (sample_flag) begin 
			    if (data_index > 0) begin 
			        aud_dadat <= da_data_out[data_index]; // Start with MSB
					  data_index <= data_index - 1;
				 end else begin 
				     aud_dadat <= da_data_out[data_index];
				     sample_flag <= 0;
				 end
			end
	  end
 end // always block end
 
 endmodule 
