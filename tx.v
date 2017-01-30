/*
	*	TX (Transmit)
	*
	*	Including Frame Generator, FM0 Encoder, Miller Encoder
	*
	*	bs_data is connected to Gate of NMOS in BACKSCATTER circuit which is the part of Analog front-end circuit
*/


`timescale 1us / 1ns


module tx
(
output bs_data,
output pre_p_complete,
output p_complete,
output bs_complete,
input clk_blf,
input clk_frm,
input clk_fm0,
input clk_mil,
input rst_for_new_package,
input reply_data,
input [15:0]crc_16,
input [1:0]m,
input trext,
input reply_complete,
input en_crc16_for_rpy,
input start_working
);


frmgen frmgen_1
(
.send_data(send_data),
.en_fm0(en_fm0),
.st_enc(st_enc),
.pre_p_complete(pre_p_complete),
.p_complete(p_complete),
.fg_complete(fg_complete),
.clk_frm(clk_frm),
.rst_for_new_package(rst_for_new_package),
.reply_data(reply_data),
.crc_16(crc_16),
.m(m),
.trext(trext),
.reply_complete(reply_complete),
.en_crc16_for_rpy(en_crc16_for_rpy)
);


fm0_enc fm0_enc_1
(
.fm0_data(fm0_data),
.fm0_complete(fm0_complete),
.clk_fm0(clk_fm0),
.rst_for_new_package(rst_for_new_package),
.send_data(send_data),
.en_fm0(en_fm0),
.trext(trext),
.st_enc(st_enc),
.fg_complete(fg_complete)
);


miller_enc miller_enc_1
(
.miller_data(miller_data),
.mil_complete(mil_complete),
.clk_mil(clk_mil),
.rst_for_new_package(rst_for_new_package),
.clk_blf(clk_blf),
.send_data(send_data),
.en_fm0(en_fm0),
.trext(trext),
.st_enc(st_enc),
.fg_complete(fg_complete)
);


// --- Backscattered Data ---
assign bs_data = (start_working)? fm0_data | miller_data : 1'b0;


assign bs_complete = fm0_complete | mil_complete;
	
	
endmodule
