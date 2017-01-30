/*
	*	Synchronizer
	*
	*	Architechture of conventional two flip-flop
	*
	*	There are two clock domain in this baseband processor
	*	one is in backscatter link frequency, another is delayed PIE code for decoding received PIE code
	*
	*	Have synchronizer to avoid metastable
*/


`timescale 1us / 1ns


module two_dff_sync
(
output data_out,
input clk_ad,			// clock in A domain
input clk_bd,			// clock in B domain
input rst_n,
input data_in
);


reg qa;
reg qb_1;
reg qb_2;


assign data_out = qb_2;

always@(posedge clk_ad or negedge rst_n) begin
	if(~rst_n) qa <= 1'b0;
	else qa <= data_in;
end

always@(posedge clk_bd or negedge rst_n) begin
	if(~rst_n) qb_1 <= 1'b0;
	else qb_1 <= qa;
end

always@(posedge clk_bd or negedge rst_n) begin
	if(~rst_n) qb_2 <= 1'b0;
	else qb_2 <= qb_1;
end


endmodule
