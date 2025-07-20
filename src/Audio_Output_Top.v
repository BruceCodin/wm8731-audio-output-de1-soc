/*
 * Audio_Output_Top
 * ----------------
 * Bruce Chen ( Student ID: 201413670 )
 * ----------------
 * Description: 
 * This module provides the Top Level file for audio output functionality 
 * ----------------
 * Referenes: This module is heavily adapted from the VHDL code referenced below
 * AntonZero, AntonZero/WM8731-Audio-codec-on-DE10Standard-FPGA-board. VHDL. Accessed: Apr. 30, 2025. [Online]. Available: https://github.com/AntonZero/WM8731-Audio-codec-on-DE10Standard-FPGA-board
 * ‘Tutorial: Playing audio through WM8731 using Terasic DE10-Standard FPGA development board - YouTube’. Accessed: Apr. 30, 2025. [Online]. Available: https://www.youtube.com/watch?v=zzIi7ErWhAA&t=251s&ab_channel=Toni
 */
 
 
 module Audio_Output_Top (
 // Declare Input and Output Ports
 input wire audio_en, // enable audio output 
 
 // WM8731 Pins 
 output wire MCLK, // Master Clock 
 output wire BCLK, // BCLK
 output wire DACLRC, // DA Syn Clock
 output wire DACDAT, // DA Data line
 
 // FPGA Inputs and Outputs
 input wire clk_50, // 50 MHz FPGA Clock
 input wire rst, // reset 
 output wire i2c_scl, // i2c clock 
 inout wire i2c_sda // i2c data line
 );
 
 // Counters, Regs, Signals and Wires
 reg [2:0] bitprsc;
 reg [31:0] aud_mono; 
 reg [17:0] read_addr;
 wire [17:0] rom_addr;
 wire [15:0] rom_out;
 wire clock_12pll;
 wire i2c_busy;
 wire i2c_done;
 reg i2c_send;
 reg [15:0] i2c_data;
 wire da_clr;
 
 // States to define i2c instructions
 localparam RESET=3'd0, DIG_INT=3'd1, VOL=3'd2,  POW=3'd3, SAMP=3'd4, ACTIVE=3'd5, ANALOG=3'd6, DIGITAL=3'd7;
 reg [3:0] cur_i2c; // Store current i2c Instruction
 
 /* Instantiate pll 
  qsys builder contains the PLL that generates the 12MHz clock for the WM8731, and on chip memory for audio storage
 */
 pll p_ll (
     .clk_clk (clk_50),
	  .reset_reset_n(1'b1),
	  .clock_12_clk(clock_12pll),
	  .onchip_memory2_0_s1_address(rom_addr),
	  .onchip_memory2_0_s1_debugaccess(1'b0),
	  .onchip_memory2_0_s1_clken(1'b1),
	  .onchip_memory2_0_s1_chipselect(1'b1),
	  .onchip_memory2_0_s1_write(1'b0),
	  .onchip_memory2_0_s1_readdata(rom_out),
	  .onchip_memory2_0_s1_writedata(16'b0), // What is this one 16 or 32?
	  .onchip_memory2_0_s1_byteenable(2'b11),
	  .onchip_memory2_0_reset1_reset(1'b0)
 );
 
  /* Instantiate audio generation Module
   DSP Audio Interface
 */
 Audio_Gen aud_gen(
    .clk_12(clock_12pll),
	 .rst(rst),
	 .aud_data(aud_mono),
	 .aud_bk(BCLK),
	 .aud_dalr(da_clr),
	 .aud_dadat(DACDAT)
 );
 
 /* Instantiate i2c Module
  This module provides the Inter-Integrated Circuit (I2C) interface which defines the 
 Serial Communication Protocol between the FPGA and WM7831 Audio Codec */
 i2c i2c(
    .clk_50(clk_50),
	 .rst(rst),
	 .scl(i2c_scl),
	 .sda (i2c_sda),
	 .addr (8'b00110100), // CSB Address: 0011010 + R/W Bit: 0 (Write Bit)
	 .data (i2c_data),
	 .send (i2c_send),
	 .stop(i2c_done),
	 .busy(i2c_busy)
 );
 
 // Master Clock and DSP data Assignment 
 assign MCLK = clock_12pll;
 assign DACLRC = da_clr;
 assign rom_addr = read_addr;
 
 /* Loading Data to Mememory using 12MHz clock 
 Sample rate can also be editted here too*/
  always @(posedge clock_12pll or posedge rst) begin
      if (rst) begin 
		    read_addr <= 0;
			 bitprsc <= 0;
			 aud_mono <= 32'b00000000000000000000000000000000;
		end else begin 
		    aud_mono[15:0] <=rom_out; // mono sound for right / left
			 aud_mono[31:16] <=rom_out; // mono sound for right / left
			 if (da_clr) begin 
			     if (bitprsc < 5) begin // 8 ksps
				      bitprsc <= bitprsc + 1;
				  end else begin 
				      bitprsc <= 0;
						if (read_addr < 240254) begin 
				      read_addr <= read_addr + 1;     
				      end else begin 
			             read_addr <= 0;
			         end 			
				  end 
			 end
		end
  end 
 
 
 
 // i2c instructions and reset logic 
 always @(posedge clk_50 or posedge rst) begin
 // Reset block needed Here
 if (rst) begin 
     i2c_data <= 16'd0;
	  i2c_send <= 0;
	  cur_i2c <= RESET;
 end else begin
	 // i2c instructions ( need to add if audio output enable to this too ) 
		if (i2c_send) begin 
			 i2c_send <= 0; // Reset i2c back to 0
		end else if (audio_en && i2c_busy==0) begin // If audio output enabled and i2c currently NOT processing an instruction
			 case (cur_i2c) // current i2c Instruction
				 RESET:begin // Reset State
					  i2c_data [15:9] <= 7'b0001111; // Reset Register
					  i2c_data [8:0] <= 9'b000000000; // Set to Reset 
					  i2c_send <= 1;
					  cur_i2c <= DIG_INT;
				 end
				 
				 DIG_INT: begin // Digital Audio Interface Format
					  i2c_data [15:9] <= 7'b0000111; // Digital Audio Interface Format Register Address
					  i2c_data [8:0] <= 9'b000010011; // Set to DSP Mode with LRP = 1
					  i2c_send <= 1;
					  cur_i2c <= VOL;  
				 end
				 
				 VOL: begin // Headphone Out
					  i2c_data [15:9] <= 7'b0000010; // Headphone Out Register Address
					  i2c_data [8:0] <= 9'b101111001; // Set to Headphone Out Volume ( For both Right and Left )
					  i2c_send <= 1;
					  cur_i2c <= POW; 
				 end
				 
				 POW: begin // Power Down Control
					  i2c_data [15:9] <= 7'b0000110; // Power Down Control Register Address
					  i2c_data [8:0] <= 9'b000000111	; // Power Down Everything but DAC
					  i2c_send <= 1;
					  cur_i2c <= SAMP; 
				 end
				 
				 SAMP: begin // Sampling Control
					  i2c_data [15:9] <= 7'b0001000; // Sampling Control Register Address
					  i2c_data [8:0] <= 9'b000000001; // Enable USB Mode, disable everything else
					  i2c_send <= 1;
					  cur_i2c <= ACTIVE;  
				 end
				 
				 ACTIVE: begin // Active Control
					  i2c_data [15:9] <= 7'b0001001; // Active Control Register Address
					  i2c_data [8:0] <= 9'b111111111; // Activate DSP and Digital Audio Interface Mode
					  i2c_send <= 1;
					  cur_i2c <= ANALOG; 
				 end
				 
				 ANALOG: begin // Analogue Audio Path Control
					  i2c_data [15:9] <= 7'b0000100; // Analogue Audio Path Control Register Address
					  i2c_data [8:0] <= 9'b000010010; // Enable DAC, disable everything else
					  i2c_send <= 1;
					  cur_i2c <= DIGITAL;   
				 end
				 
				 DIGITAL: begin // Digital Audio Path Control
					  i2c_data [15:9] <= 7'b0000101; // Digital Audio Path Control Register Address
					  i2c_data [8:0] <= 9'b000000000; // Disable Soft Mute Control On DAC 
					  i2c_send <= 1;
					  cur_i2c <= DIGITAL; 
				 end 
			 endcase 
		 end else if (!audio_en && (i2c_busy==0)) begin // If audio mode is disabled, we want the FPGA stop outputting sound and for codec to go into reset
		     i2c_data [15:9] <= 7'b0001111; // Reset Register
			  i2c_data [8:0] <= 9'b000000000; // Set to Reset 
			  i2c_send <= 1;
			  cur_i2c <= RESET;
		 end
	end
 end
 
 
 
 endmodule