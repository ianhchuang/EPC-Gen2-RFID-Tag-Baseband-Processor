/*
	*	CRC-5 Encoder/Decoder
	*
	*	Calculation of 5-bit cyclic redundancy checks
	*
	*	For more detailed information about CRC-5 for EPC Gen2, refer to annex F of the protocol
*/


`timescale 1us / 1ns


module crc5
(
output crc5_check_pass,
input clk_crc5,
input rst_for_new_package,
input data,
input sync,
input package_complete
);


reg [4:0]reg_crc;


assign crc5_check_pass = ~(|reg_crc);


always@(posedge clk_crc5 or negedge rst_for_new_package) begin
	if(~rst_for_new_package) reg_crc <= 5'b01001;
	else if(sync & ~package_complete) begin
		reg_crc[4] <= reg_crc[3];
		reg_crc[3] <= reg_crc[2] ^ (data ^ reg_crc[4]);
		reg_crc[2] <= reg_crc[1];
		reg_crc[1] <= reg_crc[0];
		reg_crc[0] <= data ^ reg_crc[4];
	end
end


endmodule
