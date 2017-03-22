/*
	*	Miller Encoder
	*
	*	By our algorithm, Miller Encoder can operate in the lowest frequency
	*	to save the power dissipation
	*
	*	This algorithm is also applied to FMo Encoder
	*
	*	If enable Miller Encoder, disable FM0 Encoder and vice versa
*/


`timescale 1us / 1ns


module miller_enc
(
output miller_data,
output mil_complete,
input clk_mil,
input rst_for_new_package,
input clk_blf,
input send_data,
input en_fm0,		// if en_fm0 = 0, enable miller encoder 
input trext,
input st_enc,
input fg_complete
);


parameter GetData  	= 2'b00;
parameter DataP   	= 2'b01;
parameter DataN   	= 2'b10;


reg [1:0]ps;
reg [1:0]ns;

wire clk_blf_n;
wire en_mil_out;
wire m2o;
wire mp_complete;
wire me_start;

reg [5:0]mp_end;
reg [5:0]mp_cnt;
reg m_cnt;
reg m1o;
reg [1:0]data_select;
reg [1:0]fg_comp_cnt;


assign clk_blf_n = ~clk_blf;

assign en_mil_out = (mp_cnt > 6'h0)? 1'b1 : 1'b0;

assign miller_data = (en_mil_out & ~mil_complete)? m2o : 1'b0;

assign m2o = mp_complete? m1o : clk_blf;

assign mp_complete = (mp_cnt == mp_end)? 1'b1 : 1'b0;

assign me_start = (mp_cnt > mp_end - 6'h2)? 1'b1 : 1'b0; 

always@(*) begin
	if(~trext) mp_end = 6'h9;
	else mp_end = 6'h21;
end

always@(posedge clk_mil or negedge rst_for_new_package) begin
	if(~rst_for_new_package) mp_cnt <= 6'h0;
	else begin
		if(mp_cnt == mp_end) mp_cnt <= mp_cnt;
		else if(~en_fm0 & st_enc) mp_cnt <= mp_cnt + 6'h1;
	end
end

always@(posedge clk_mil or negedge rst_for_new_package) begin
	if(~rst_for_new_package) m_cnt <= 1'b0;
	else if(me_start) m_cnt <= m_cnt + 1'b1;
end

always@(posedge clk_mil or negedge rst_for_new_package) begin
	if(~rst_for_new_package) ps <= GetData;
	else if(st_enc) ps <= ns;
end

always@(*) begin
	case(ps)
		GetData : if(~en_fm0 & me_start) ns = DataP;
			  else ns = GetData;
		DataP	: if(~send_data) ns = DataP;
			  else begin
			  	if(~m_cnt) ns = DataP;
				else ns = DataN;
			  end
		DataN	: if(~send_data) ns = DataN;
			  else begin
			  	if(~m_cnt) ns = DataN;
				else ns = DataP;
			  end
		default : ns = GetData;
	endcase
end

always@(*) begin
	case(ps)
		GetData : data_select = 2'h0;
		DataP	: data_select = 2'h1;
		DataN	: data_select = 2'h2;
		default : data_select = 2'h0;
	endcase
end

always@(*) begin
	case(data_select)
		2'h0	: m1o = 1'b0;
		2'h1	: m1o = clk_blf;
		2'h2	: m1o = clk_blf_n;
		default : m1o = 1'b0;
	endcase
end

always@(posedge clk_mil or negedge rst_for_new_package) begin
	if(~rst_for_new_package) fg_comp_cnt <= 2'b0;
	else begin
		if(fg_comp_cnt == 2'b11) fg_comp_cnt <= fg_comp_cnt;
		else if(~en_fm0 & fg_complete) fg_comp_cnt <= fg_comp_cnt + 2'b1;
	end
end

assign mil_complete = (fg_comp_cnt == 2'b11)? 1'b1 : 1'b0;


endmodule
