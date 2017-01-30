/*
	*	Frame-Sync Detector
	*
	*	Every package sent from Reader must have Frame-Sync
	*
	*	This module determine if Tag receive valid Frame-Sync
	*	and send sync to enable other RX module
*/


`timescale 1us / 1ns


module fs_detector
(
output reg sync,			// if sync is high, means that receiving the valid Frame-Sync
input pie_code,
input clk_fsd,
input rst_n,
input package_complete
);


parameter idle = 2'b00;
parameter got0 = 2'b01;		// got valid Frame-Sync
parameter got1 = 2'b10;


reg [1:0]ps;
reg [1:0]ns;


always@(posedge clk_fsd or negedge rst_n) begin
	if(~rst_n) ps <= idle;
	else ps <= ns;
end

always@(*) begin
	case(ps)
		idle	: if(~pie_code) ns = got0;
				  else ns = idle;
		got0	: if(~pie_code) ns = got0;
				  else ns = got1;
		got1	: if(package_complete) ns = idle;
				  else ns = got1;
		default : ns = idle;
	endcase
end

always@(*) begin
	case(ps)
		idle	: sync = 1'b0;
		got0	: sync = 1'b0;
		got1	: sync = 1'b1;
		default : sync = 1'b0;
	endcase
end


endmodule
