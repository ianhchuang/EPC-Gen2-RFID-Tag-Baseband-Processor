/*
	*	Pseudo Random Number Generator
	*
	*	EPC Gen2 protocol requests baseband processor should have a Random Number Generator comformed to it's spec
	*
	*	In this design, we chose the following polynimial to implement our PRNG
	*	1 + x^3 + x^4 + x^5 + x^16
*/


`timescale 1us / 1ns


module prng
(
output reg [15:0]prn,	// pseudo random number
input clk_prng,
input rst_n
);


always@(posedge clk_prng or negedge rst_n) begin
	if(~rst_n) prn <= 16'h2a6c;
	else begin
		prn[0] <= prn[15];
		prn[1] <= prn[0];
		prn[2] <= prn[1];
		prn[3] <= prn[2] ^ prn[15];
		prn[4] <= prn[3] ^ prn[15];
		prn[5] <= prn[4] ^ prn[15];
		prn[15:6] <= prn[14:5];
	end
end


endmodule
