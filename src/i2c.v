/*
 * i2c Interface
 * ----------------
 * Bruce Chen ( Student ID: 201413670 )
 * ----------------
 * Description: 
 * This module provides the Inter-Integrated Circuit (I2C) interface which defines the 
 * Serial Communication Protocol between the FPGA and WM7831 Audio Codec
 * ----------------
 * Referenes: This module is heavily adapted from the VHDL code referenced below
 * AntonZero, AntonZero/WM8731-Audio-codec-on-DE10Standard-FPGA-board. VHDL. Accessed: Apr. 30, 2025. [Online]. Available: https://github.com/AntonZero/WM8731-Audio-codec-on-DE10Standard-FPGA-board
 * ‘Tutorial: Playing audio through WM8731 using Terasic DE10-Standard FPGA development board - YouTube’. Accessed: Apr. 30, 2025. [Online]. Available: https://www.youtube.com/watch?v=zzIi7ErWhAA&t=251s&ab_channel=Toni
 */
 
 module i2c (
     input wire clk_50, // 50MHz FPGA Clock
	  input wire rst, // reset line
	  output reg scl, // SCLK line
	  inout wire sda, // SDA line ( is bidirectional, inout tristate signal)
	  input wire [7:0] addr, // 7 Bit Device Address (CSB) + R/W Bit (0)
	  input wire [15:0] data, // 7 Bit Register Address + 9 Bits Data
	  input wire send, // Send flag
	  output reg stop, // Goes high when i2c completed
	  output reg busy // Busy flag
 );
 
 // Counters, Regs, Signals and Wires
 reg [8:0] clk_count; // Counter for clock divider
 reg i2c_clk_en;
 reg clk_en; 
 reg ack_en;
 reg clk_i2c; 
 reg get_ack; 
 reg [3:0] data_index; // So that correct bit is sent
 reg sda_en;// For Tristate, if this 1, sda will output, else sda is held high Z or isolated
 reg sda_o; // Should be 1 to enable sda output, 0 for Idle state
 
 /* FSM Set Up and Tristate Buffer 
 *  States for the FSM are declared using localparam 
 *  Each of the states represent a stage in the I2C configuration
 *  A reg fsm is then used to store the state
 */
 localparam ST0=4'd0, ST1=4'd1, ST2=4'd2, ST3=4'd3, ST4=4'd4, ST5=4'd5, ST6=4'd6, ST7=4'd7, ST8=4'd8;
 reg [3:0] fsm;
 
 // Tristate Buffer still may need to be implemented
 assign sda = (sda_en) ? sda_o : 1'bz; // if sda_en is high, sda is sda_o, else sda is high-z
 
 always @(posedge clk_50 or posedge rst) begin
     if (rst) begin 
	  /* Will need to include a reset section and set everything else to else of this section
	  Initial vlaues for the Counters, Regs and Signals and Wires all need to be set here */
	  stop <= 0;
	  busy <= 0;
     clk_count <= 0; // Counter for clock divider
     i2c_clk_en <= 0;
     clk_en <= 0;
     ack_en <= 0;
     clk_i2c <= 0;
     get_ack <= 0;
	  data_index <= 0;
	  sda_en <= 1;
	  sda_o <= 1;
	  fsm <= ST0; // Initial state of fsm also needs to be declared
	 end else begin
		 // Generating Clocks for Signal 
		 if (clk_count < 250) begin 
			  clk_count <= clk_count + 1;
		 end else begin 
			  clk_count <= 0;
		 end 
		 // Clock for clk_i2c
		 if (clk_count < 125) begin 
			  clk_i2c <= 1;
		 end else begin 
			  clk_i2c <= 0;
		 end 
		 // Clock for ack on scl = HIGH
		 if (clk_count == 62) begin 
			  ack_en <= 1;
		 end else begin 
			  ack_en <= 0;
		 end 
		  // Clock for data on scl = LOW
		 if (clk_count == 187) begin 
			  clk_en <= 1;
		 end else begin 
			  clk_en <= 0;
		 end 
		 
		 // Enable or Idle
		 if (i2c_clk_en==1) begin 
			  scl <= clk_i2c;
		 end else begin 
			  scl <= 1'b1;
		 end
		 
		 // ACK States
		 if (ack_en==1) begin
			  case (fsm) 
				  ST3: begin // First ACK
						if (sda==0) begin 
							fsm <= ST4; // Can Move to Next State
							data_index <= 15; // Next Data Index would be First bit of 16 Bit Data
						end else begin // No ACK recieved means something gone wrong, reset to idle
							fsm <= ST0;
							i2c_clk_en <= 0;
						end
				  end
				  
				  ST5: begin // Second ACK
						if (sda==0) begin 
							fsm <= ST6;
							data_index <= 7; // Next Data Index would be First bit second data byte (8bits)
						end else begin 
							fsm <= ST0;
							i2c_clk_en <= 0;
						end
				  end
				  
				  ST7: begin // Third ACK
						if (sda==0) begin 
							fsm <= ST8; // Next State is Stop State (No Dataindex)
						end else begin 
							fsm <= ST0;
							i2c_clk_en <= 0;
						end
				  end
				  
				  default: begin
					  fsm <= ST0; // default should never be triggered but if it does, keep IDLE state
				  end
				  
			  endcase // endcase for if (ack_en==1) begin   
		 end // end for if (ack_en==1) begin
		 
		 
		 // Data Tranmission States
		 if (clk_en==1) begin 
			  case (fsm) 
				  ST0: begin // Idle condition
					  sda_en <= 1;
					  sda_o <= 1;
					  busy <= 0;
					  stop <= 0;
					  if (send==1) begin 
					  fsm <= ST1;
					  busy <= 1;
					  end
				  end
				  
				  ST1: begin // Start condition
					  sda_o <= 0; // sda set low for Start condition
					  fsm <= ST2; // Next fsm state
					  data_index <= 7; // First bit of the device address
				  end 
				  
				  ST2: begin // Send device address
					  i2c_clk_en <= 1; // enable clocking
					  if (data_index>0) begin 
						  sda_o <= addr[data_index];
						  data_index <= data_index-1;
					  end else begin 
						  sda_o <= addr[data_index];
						  sda_en <= 0; // ACK sent from WM8731, sda needs to be set high Z
						  get_ack <= 1;
					  end
					  
					  if (get_ack==1) begin
						  get_ack <= 0;
						  fsm <= ST3;
					  end
				  end 
				  
				  ST4: begin // Send Register Address + R/W bit (First Data Byte of 16 Bit Data)
				     sda_en <= 1; // Enable sda output
					  if (data_index>8) begin 
						  sda_o <= data[data_index];
						  data_index <= data_index-1;
					  end else begin
						  sda_o <= data[data_index];
						  get_ack <= 1; 
						  sda_en <= 0; // ACK sent from WM8731, sda needs to be set high Z
					  end
					  
					  if (get_ack==1) begin
						  get_ack <= 0;
						  fsm <= ST5;
					  end
				  end
				  
				  ST6: begin // Send Second Data Byte (7:0 bits of Data)
				     sda_en <= 1; // Enable sda output
					  if (data_index>0) begin 
						  sda_o <= data[data_index];
						  data_index <= data_index-1;				  
					  end else begin 
						  sda_o <= data[data_index];
						  get_ack <= 1;
						  sda_en <= 0; // ACK sent from WM8731, sda needs to be set high Z  
					  end
	
					  if (get_ack==1) begin
						  get_ack <= 0;
						  fsm <= ST7;
					  end  
				  end
				  
				  ST8: begin // Stop Condition
					  i2c_clk_en <= 0;
					  sda_en <= 1;
					  sda_o <= 0;
					  stop <= 1;
					  fsm <= ST0;
				  end	
				  
				  default: begin
					  fsm <= ST0; // default should never be triggered but if it does, keep IDLE state
				  end
			  endcase // endcase for if (clk_en==1) begin
		 end // end for if (clk_en==1) begin
	 end // end for if(rst begin)
 end // end for always block 
	 
 endmodule
