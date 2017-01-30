/*
	*	FM0 Encoder
	*
	*	By our algorithm, FM0 Encoder can operate in the lowest frequency
	*
	*	The common way to encode FM0 is using clock in double BLF to determine the output sigal of each period
	*	Our Algorithm does not use the double-BLF clock, it only needs the clock in BLF
	*
	*	The same concept is applied to design Miller Encoder
	*	The lowest operation frequency makes the Encoding save power dissipation
	*
	*	If enable FM0 Encoder, disable Miller Encoder and vice versa
*/


`timescale 1us / 1ns


module fm0_enc
(
output fm0_data,
output fm0_complete,
input clk_fm0,
input rst_for_new_package,
input send_data,
input en_fm0,
input trext,
input st_enc,
input fg_complete
);


parameter GetData = 3'b000;
parameter Data0p  = 3'b001;
parameter Data0n  = 3'b010;
parameter Data1p  = 3'b011;
parameter Data1n  = 3'b100;


reg [2:0]ps;		// present state
reg [2:0]ns;		// next state

wire clk_fm0_n;
wire en_vcnt;		// enable V counter
wire start_enc;		// start FM0 encoding
wire send_v;		// send V
wire m2o;		// output of MUX 2

reg [1:0]data_select;
reg m1o;		// output of MUX 1
reg [4:0]v_cnt;		// V coumter
reg [1:0]fg_comp_cnt;


assign clk_fm0_n = ~clk_fm0;

assign start_enc = (ps != GetData)? 1'b1 : 1'b0;

assign en_vcnt = (start_enc & (v_cnt != 5'h11))? 1'b1 : 1'b0;

assign send_v = (~trext & (v_cnt == 5'h04))? 1'b1 :
			   (trext & (v_cnt == 5'h10))? 1'b1 : 1'b0;
			   
assign m2o = send_v? 1'b0 : m1o;

assign fm0_data = (en_fm0 & ~fm0_complete)? m2o : 1'b0;


always@(posedge clk_fm0 or negedge rst_for_new_package) begin
	if(~rst_for_new_package) ps <= GetData;
	else if(st_enc) ps <= ns;
end

always@(*) begin
	case(ps)
		GetData : if(~en_fm0) ns = GetData;
				  else if(en_fm0 & (~send_data)) ns = Data0p;
				  else ns = Data1p;
		Data0p  : if(~send_data) ns = Data0p;
				  else ns = Data1p;
		Data0n	: if(~send_data) ns = Data0n;
				  else ns = Data1n;
		Data1p	: if(~send_data) ns = Data0n;
				  else ns = Data1n;
		Data1n	: if(~send_data) ns = Data0p;
				  else ns = Data1p;
		default : ns = GetData;
	endcase
end

always@(*) begin
	case(ps)
		GetData : data_select = 2'h0;
		Data0p	: data_select = 2'h3;
		Data0n	: data_select = 2'h2;
		Data1p	: data_select = 2'h1;
		Data1n	: data_select = 2'h0;
		default : data_select = 2'h0;
	endcase
end

always@(*) begin
	case(data_select)
		2'h0 : m1o = 1'b0;
		2'h1 : m1o = 1'b1;
		2'h2 : m1o = clk_fm0_n;
		2'h3 : m1o = clk_fm0;
	endcase
end

always@(posedge clk_fm0 or negedge rst_for_new_package) begin
	if(~rst_for_new_package) v_cnt <= 5'h00;
	else begin
		if(st_enc & en_vcnt) v_cnt <= v_cnt + 5'h01;
	end
end

always@(posedge clk_fm0 or negedge rst_for_new_package) begin
	if(~rst_for_new_package) fg_comp_cnt <= 2'b0;
	else begin
		if(fg_comp_cnt == 2'b10) fg_comp_cnt <= fg_comp_cnt;
		else if(en_fm0 & fg_complete) fg_comp_cnt <= fg_comp_cnt + 2'b1;
	end
end

assign fm0_complete = (fg_comp_cnt == 2'b10)? 1'b1 : 1'b0;


endmodule
