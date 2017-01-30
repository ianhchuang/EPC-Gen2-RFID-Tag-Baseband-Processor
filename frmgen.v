/*
	*	Frame Generator
	*
	*	Generate the replied package from Tag to Reader
	*	including Preamle, Replied Data, End-of-Signaling
	*
	*	Support FM0 Encoder and Miller Encoder in M = 2, 4, 8
	*	the forms of encoding is depends on M
	*
	*	Two forms of preamble, which is depends on Trext
*/


`timescale 1us / 1ns


module frmgen
(
output reg send_data,
output en_fm0,
output reg st_enc,
output pre_p_complete,
output p_complete,
output reg fg_complete,
input clk_frm,
input rst_for_new_package,
input reply_data,
input [15:0]crc_16,
input [1:0]m,
input trext,
input reply_complete,
input en_crc16_for_rpy
);


reg reply_complete_d;
reg [4:0]cnt_end;
reg [4:0]p_cnt;
reg [3:0]crc_cnt;
reg crc_complete;


assign en_fm0 = (m == 2'b00)? 1'b1 : 1'b0;

assign pre_p_complete = (p_cnt > (cnt_end - 5'h2))? 1'b1 : 1'b0;

assign p_complete = (p_cnt == cnt_end)? 1'b1 : 1'b0;

always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) st_enc <= 1'b0;
	else st_enc <= 1'b1;
end

always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) reply_complete_d <= 1'b0;
	else reply_complete_d <= reply_complete;
end

always@(*) begin
	case({m, trext})
		3'b000 : cnt_end = 5'h6;
		3'b001 : cnt_end = 5'h12;
		3'b010 : cnt_end = 5'ha;
		3'b011 : cnt_end = 5'h16;
		3'b100 : cnt_end = 5'ha;
		3'b101 : cnt_end = 5'h16;
		3'b110 : cnt_end = 5'ha;
		3'b111 : cnt_end = 5'h16;
	endcase
end

always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) p_cnt <= 5'h0;
	else begin
		if(p_cnt == cnt_end) p_cnt <= p_cnt;
		else p_cnt <= p_cnt + 5'h1;
	end
end

always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) send_data <= 1'b0;
	else if(~en_crc16_for_rpy & reply_complete_d) send_data <= 1'b1;
	else if(en_crc16_for_rpy &  crc_complete) send_data <= 1'b1;
	else if(reply_complete_d & en_crc16_for_rpy & ~crc_complete) send_data <= crc_16[crc_cnt];
	else begin
		if(p_cnt != cnt_end) begin
			if(m == 2'b00) begin
				if(~trext) begin
					case(p_cnt)
						5'h0 : send_data <= 1'b1;
						5'h1 : send_data <= 1'b0;
						5'h2 : send_data <= 1'b1;
						5'h3 : send_data <= 1'b0;
						5'h4 : send_data <= 1'b0;
						5'h5 : send_data <= 1'b1;
					endcase
				end
				else begin
					case(p_cnt)	
						5'h0, 5'h1, 5'h2, 5'h3, 5'h4, 5'h5, 5'h6, 5'h7, 5'h8, 5'h9, 5'ha, 5'hb : send_data <= 1'b0;
						5'hc : send_data <= 1'b1;
						5'hd : send_data <= 1'b0;
						5'he : send_data <= 1'b1;
						5'hf : send_data <= 1'b0;
						5'h10 : send_data <= 1'b0;
						5'h11 : send_data <= 1'b1;
					endcase
				end
			end
			else begin
				if(~trext) begin
					case(p_cnt)
						5'h0, 5'h1, 5'h2, 5'h3 : send_data <= 1'b0;
						5'h4 : send_data <= 1'b0;
						5'h5 : send_data <= 1'b1;
						5'h6 : send_data <= 1'b0;
						5'h7 : send_data <= 1'b1;
						5'h8 : send_data <= 1'b1;
						5'h9 : send_data <= 1'b1;
					endcase
				end
				else begin
					case(p_cnt)
						5'h0, 5'h1, 5'h2, 5'h3, 5'h4, 5'h5, 5'h6, 5'h7, 5'h8, 5'h9, 5'ha, 5'hb, 5'hc, 5'hd, 5'he, 5'hf : send_data <= 1'b0;
						5'h10 : send_data <= 1'b0;
						5'h11 : send_data <= 1'b1;
						5'h12 : send_data <= 1'b0;
						5'h13 : send_data <= 1'b1;
						5'h14 : send_data <= 1'b1;
						5'h15 : send_data <= 1'b1;
					endcase
				end
			end
		end
		else send_data <= reply_data;
	end
end

always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) crc_cnt <= 4'hf;
	else begin
		if(crc_cnt == 4'h0) crc_cnt <= crc_cnt;
		else if(reply_complete_d & en_crc16_for_rpy) crc_cnt <= crc_cnt - 4'h1;
	end
end

always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) crc_complete <= 1'b0;
	else if(crc_cnt == 4'h0) crc_complete <= 1'b1;
end

always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) fg_complete <= 1'b0;
	else begin
		if(reply_complete_d & ~en_crc16_for_rpy) fg_complete <= 1'b1;
		else if(crc_complete & en_crc16_for_rpy) fg_complete <= 1'b1;
	end
end


endmodule
