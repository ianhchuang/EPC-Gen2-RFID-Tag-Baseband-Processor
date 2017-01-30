/*
	*	CRC-16 Encoder/Decoder
	*
	*	Calculation of 16-bit cyclic redundancy checks
	*
	*	For more detailed information about CRC-16 for EPC Gen2, refer to annex F of the protocol
*/


`timescale 1us / 1ns


module crc16
(
output reg crc16_check_pass_reg,
output [15:0]crc_16,
input clk_crc16,
input rst_crc16,
input data,
input reply_data,
input sync,
input package_complete,
input en_crc16_for_rpy
);


wire d_in;

reg crc16_check_pass;
reg [15:0]reg_crc;


assign d_in = en_crc16_for_rpy? reply_data : data;

assign crc_16 = ~reg_crc;


always@(*) begin
	if(reg_crc == 16'h1d0f) crc16_check_pass = 1'b1;
	else crc16_check_pass = 1'b0;
end


always@(posedge clk_crc16 or negedge rst_crc16) begin
	if(~rst_crc16) crc16_check_pass_reg <= 1'b0;
	else if(package_complete) crc16_check_pass_reg <= crc16_check_pass;
end


always@(posedge clk_crc16 or negedge rst_crc16) begin
	if(~rst_crc16) reg_crc <= 16'hffff;
	else if(sync | en_crc16_for_rpy) begin
		reg_crc[15] <= reg_crc[14];
		reg_crc[14] <= reg_crc[13];
		reg_crc[13] <= reg_crc[12];
		reg_crc[12] <= reg_crc[11] ^ (d_in ^ reg_crc[15]);
		reg_crc[11] <= reg_crc[10];
		reg_crc[10] <= reg_crc[9];
		reg_crc[9] <= reg_crc[8];
		reg_crc[8] <= reg_crc[7];
		reg_crc[7] <= reg_crc[6];
		reg_crc[6] <= reg_crc[5];
		reg_crc[5] <= reg_crc[4] ^ (d_in ^ reg_crc[15]);
		reg_crc[4] <= reg_crc[3];
		reg_crc[3] <= reg_crc[2];
		reg_crc[2] <= reg_crc[1];
		reg_crc[1] <= reg_crc[0];
		reg_crc[0] <= d_in ^ reg_crc[15];
	end
end


endmodule
