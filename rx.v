/*
	*	RX (Receive)
	*
	*	Including Frame-Sync Detector, CRC-5, CRC-16, Command Buffer
	*
	*	The clock signal in RX is delayed PIE code from Analog front-end circuit
	*	so we can directly transfer to binary code by clocking PIE code without decoder
*/


`timescale 1us / 1ns


module rx
(
output [7:0]cmd,
output [51:0]param,
output package_complete,
output crc_check_pass,
output [15:0]crc_16,
output en_crc5,
output en_crc16,
input pie_code,
input clk_dpie,
input clk_crc5,
input clk_crc16,
input rst_n,
input rst_for_new_package,
input rst_crc16,
input reply_data,
input en_crc16_for_rpy
);


fs_detector fs_detector_1
(
.sync(sync),
.pie_code(pie_code),
.clk_fsd(clk_dpie),
.rst_n(rst_n),
.package_complete(package_complete)
);


crc5 crc5_1
(
.crc5_check_pass(crc5_check_pass),
.clk_crc5(clk_crc5),
.rst_for_new_package(rst_for_new_package),
.data(pie_code),
.sync(sync),
.package_complete(package_complete)
);


crc16 crc16_1
(
.crc16_check_pass_reg(crc16_check_pass_reg),
.crc_16(crc_16),
.clk_crc16(clk_crc16),
.rst_crc16(rst_crc16),
.data(pie_code),
.reply_data(reply_data),
.sync(sync),
.package_complete(package_complete),
.en_crc16_for_rpy(en_crc16_for_rpy)
);


cmd_buf cmd_buf_1
(
.cmd(cmd),
.param(param),
.package_complete(package_complete),
.en_crc5(en_crc5),
.en_crc16(en_crc16),
.clk_cmd(clk_dpie),
.rst_for_new_package(rst_for_new_package),
.bits_in(pie_code),
.sync(sync)
);


assign crc_check_pass = crc5_check_pass | crc16_check_pass_reg;


endmodule
