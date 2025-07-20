# DE1-SOC Audio Output Using WM8731 Audio Codec (Verilog)
## i2c.v
This module implements an I2C (Inter-Integrated Circuit) communication protocol in Verilog for configuring the WM8731 audio codec on the DE1-SoC FPGA board. It handles serial data transmission and acknowledgment using a Mealy FSM, tristate SDA line, and clock synchronization.

⚙️ Features:
* Supports 7-bit device addressing + write bit
* Configures 16-bit registers (7-bit address + 9-bit data)
* Mealy-style FSM with 9 states (ST0 to ST8)
* Generates I2C-compatible SCL clock via a divider from the 50 MHz system clock
* Tristate buffer logic for bidirectional SDA line (driven or high-Z for ACK reception)
* ACK handling after each byte to ensure reliable communication

## Audio_Gen.v 
This module implements the DSP/PCM audio interface between the DE1-SoC FPGA and the WM8731 audio codec. It generates serial audio data output at a sampling rate of 48 kSps, using a 12 MHz master clock and outputs 16-bit stereo samples (L/R) over the DACDAT line in compliance with the codec's timing protocol.

⚙️ Features:
* Generates audio stream using a left-right clock (DACLRC) and bit clock (BCLK)
* Supports 32-bit frame: 16-bit left + 16-bit right sample format
* Sample rate: 48,000 samples per second
* Bit-serial output sent on falling edge of 12 MHz clock
* aud_dalr is pulled HIGH to indicate the start of a sample frame

## Audio_Output_Top.v
This is the top-level module that orchestrates audio output from an FPGA to the WM8731 audio codec on the DE1-SoC board. It integrates:
* A 12 MHz PLL clock generator
* A DSP/PCM audio data streamer (Audio_Gen)
* An I2C configuration interface (i2c)
* On-chip ROM for audio sample storage

⚙️ Features:
* Fully synthesizable top-level audio pipeline for WM8731
* Controls I2C configuration for audio codec startup
* Generates 48 kSps mono audio stream using DSP protocol
* Reads 16-bit MIF-encoded samples from ROM and mirrors them to stereo (Left & Right)
* Supports external audio_en signal to trigger/disable codec configuration
