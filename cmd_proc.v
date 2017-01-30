/*
	*	Command Processor
	*
	*	Process the received command and then do the action corresponding to the command and present state
	*
	*	Control almost all enable signals of the baseband processor
	*
	*	This module has the greatest immediate power dissipation, because of the huge computing of combinational logic
	*	
	*	By Operand Isolation technique save the power dissipation and reduce the max. immediate power
	*
	*	This design of baseband processor is improved by TSMC 0.18 um CMOS standard process
	*	it does not support EEPROM, so we chose ROM to be the baseband processor's memory
	*	because we use ROM to be the memory, we are not able to verify the Write command
*/


`timescale 1us / 1ns


module cmd_proc
(
output reg reply_data,
output reg reply_complete,
output reg dr,
output reg [1:0]m,
output reg trext,
output reg en_2nd_clk_cp,
output reg en_tx,
output reg en_prng_idol,
output reg en_prng_act,
output reg en_crc16_for_rpy,
output reg en_if,
output reg [18:0]addr,
input clk_cp,
input clk_frm,
input rst_n,
input rst_for_new_package,
input [7:0]cmd,
input [51:0]param,
input crc_check_pass,
input [15:0]prn,
input pre_p_complete,
input p_complete,
input rd_data,
input rd_complete
);


// --- mandatory commands of EPC Gen2 protocol ---
parameter QueryRep		= 8'b0000_1100;
parameter ACK			= 8'b0000_1101;
parameter Query			= 8'b0011_1000;
parameter QueryAdjust		= 8'b0011_1001;
parameter Select		= 8'b0011_1010;
parameter NAK			= 8'b1100_0000;
parameter Req_RN		= 8'b1100_0001;
parameter Read			= 8'b1100_0010;
//parameter Write		= 8'b1100_0011;
parameter Kill			= 8'b1100_0100;
parameter Lock			= 8'b1100_0101;


// --- working states ---
parameter Ready			= 4'h0;
parameter Sloting		= 4'h1;
parameter Arbitrate		= 4'h2;
parameter Reply			= 4'h3;
parameter Acknowledged		= 4'h4;
parameter SlotTran		= 4'h5;
parameter Open			= 4'h6;
parameter Secured		= 4'h7;
parameter Killing		= 4'h8;
parameter Killed		= 4'h9;


// --- actions ---
parameter do_nothing			= 5'h00;
parameter set_sl_or_if			= 5'h01;
parameter init_inventory		= 5'h02;
parameter adj_q				= 5'h03;
parameter dec_slot			= 5'h04;
parameter bs_new_rn16			= 5'h05;
parameter reply_ack			= 5'h06;
parameter bs_new_rn16_tran_if		= 5'h07;
parameter adj_q_tran_if			= 5'h08;
parameter dec_slot_tran_if		= 5'h09;
parameter tran_if			= 5'h0a;
parameter gen_and_bs_new_handle		= 5'h0b;
parameter bs_new_rn16_crc16		= 5'h0c;
parameter bs_read_data			= 5'h0d;
parameter bs_handle			= 5'h0e;
parameter bs_header_kill		= 5'h0f;
parameter bs_header_lock		= 5'h10;
parameter bs_error_code			= 5'h11;


wire clk_cp_n;

reg [7:0]cmd_checked;		// checked command
reg [3:0]ps;			// present state
reg [3:0]ns;			// next state
reg [4:0]act;			// action
reg mch;			// matching/not-matching
reg [7:0]ptr;			// pointer of Select command (bit addressing)
reg trct;			// parameter Truncate of Select command
reg [1:0]sl;			// SL flag
reg if_s0;			// inventoried flag of session 0
reg if_s1;			// inventoried flag of session 1
reg if_s2;			// inventoried flag of session 2
reg if_s3;			// inventoried flag of session 3
//reg dr;			// divide ratio
//reg [1:0]m;			// cycles per symbol
//reg trext;			// pilot tone
reg [1:0]session;		// tag's 4 sessions
reg [3:0]q;			// # of bits of slot
reg [14:0]slot;			// slot counter
reg [9:0]lock_act;		// action of Lock command
reg tid_lock;
reg epc_lock;
reg accs_lock;
reg kill_lock;
reg [4:0]act_reg;
reg [15:0]rn16;		// 16-bit random number for backscattering new RN16
reg [15:0]handle;	// 16-bit random number for backscattering "handle"
reg en_if_d;
reg [4:0]r_cnt;		// reply counter
reg [4:0]r_end;		// end point of reply counter


// --- check the receieved command ---
always@(*) begin
	if(cmd == Query | cmd == Select | cmd == Req_RN | cmd == Read | cmd == Kill | cmd == Lock) begin
		if(crc_check_pass) cmd_checked = cmd;
		else cmd_checked = 8'h00;
	end
	else cmd_checked = cmd;
end


// --- state register ---
always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) ps <= Ready;
	else ps <= ns;
end


// --- next state logic ---
always@(*) begin
	case(ps)
		Ready			:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) ns = Sloting;
								else ns = Ready;
							end
							else ns = Ready;
							
		Sloting		 	:	if(slot == 15'b0) ns = Reply;
							else ns = Arbitrate;
							
		Arbitrate	 	:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) ns = Sloting;
								else ns = Ready;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) ns = Sloting;
								else ns = Arbitrate;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) ns = Sloting;
								else ns = Arbitrate;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) ns = Arbitrate;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) ns = Arbitrate;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) ns = Arbitrate;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) ns = Arbitrate;
								else ns = Ready;
							end
							else ns = Arbitrate;
					   
		Reply		 	: 	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) ns = Sloting;
								else ns = Ready;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) ns = Arbitrate;
								else ns = Reply;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) ns = Sloting;
								else ns = Reply;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == rn16) ns = Acknowledged;
								else ns = Arbitrate;
							end
							else if(cmd_checked == NAK) ns = Arbitrate;
							else if(cmd_checked == Req_RN) ns = Arbitrate;
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) ns = Reply;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) ns = Reply;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) ns = Reply;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) ns = Reply;
								else ns = Ready;
							end
							else if(cmd_checked == Read) ns = Arbitrate;
							else if(cmd_checked == Kill) ns = Arbitrate;
							else if(cmd_checked == Lock) ns = Arbitrate;
							else ns = Reply;
					   
		Acknowledged 	: 	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) ns = SlotTran;
								else ns = Ready;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) ns = Ready;
								else ns = Acknowledged;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) ns = Ready;
								else ns = Acknowledged;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == rn16) ns = Acknowledged;
								else ns = Arbitrate;
							end
							else if(cmd_checked == NAK) ns = Arbitrate;
							else if(cmd_checked == Req_RN) begin
								if(param[31:16] == rn16) ns = Secured;
								else ns = Acknowledged;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) ns = Acknowledged;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) ns = Acknowledged;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) ns = Acknowledged;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) ns = Acknowledged;
								else ns = Ready;
							end
							else if(cmd_checked == Read) ns = Arbitrate;
							else if(cmd_checked == Kill) ns = Arbitrate;
							else if(cmd_checked == Lock) ns = Arbitrate;					   
							else ns = Acknowledged;
		
		SlotTran		:	if(slot == 15'b0) ns = Reply;
							else ns = Arbitrate;
		
		Open		 	:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) ns = SlotTran;
								else ns = Ready;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) ns = Ready;
								else ns = Open;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) ns = Ready;
								else ns = Open;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == handle) ns = Open;
								else ns = Arbitrate;
							end
							else if(cmd_checked == NAK) ns = Arbitrate;
							else if(cmd_checked == Req_RN) ns = Open;
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) ns = Open;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) ns = Open;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) ns = Open;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) ns = Open;
								else ns = Ready;
							end
							else if(cmd_checked == Read) ns = Open;
							else if(cmd_checked == Kill) begin
								// the first 16 bits kill password is d357
								if((param[50:35] ^ rn16) == 16'hd357 & param[31:16] == handle) ns = Killing;
								else ns = Arbitrate;
							end
							else if(cmd_checked == Lock) ns = Open;
							else ns = Open;
					   
		Secured		 	: 	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) ns = SlotTran;
								else ns = Ready;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) ns = Ready;
								else ns = Secured;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) ns = Ready;
								else ns = Secured;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == handle) ns = Secured;
								else ns = Arbitrate;
							end
							else if(cmd_checked == NAK) ns = Arbitrate;
							else if(cmd_checked == Req_RN) ns = Secured;
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) ns = Secured;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) ns = Secured;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) ns = Secured;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) ns = Secured;
								else ns = Ready;
							end
							else if(cmd_checked == Read) ns = Secured;
							else if(cmd_checked == Kill) begin
								if((param[50:35] ^ rn16) == 16'hd357 & param[31:16] == handle) ns = Killing;
								else ns = Arbitrate;
							end
							else if(cmd_checked == Lock) ns = Secured;
							else ns = Secured;
					   
		Killing		 	: 	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) ns = SlotTran;
								else ns = Ready;
							end
							else if(cmd_checked == Req_RN) ns = Killing;
							else if(cmd_checked == Kill) begin
								if((param[50:35] ^ rn16) == 16'h06cc & param[31:16] == handle) ns = Killed;
								else ns = Arbitrate;
							end
							else ns = Arbitrate;
					   
		Killed		 :		ns = Killed;
		
		default		 :		ns = Arbitrate;
	endcase
end


// --- output logic ---
always@(*) begin
	case(ps)
		Ready			:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) act = init_inventory;
								else act = do_nothing;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) act = do_nothing;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) act = do_nothing;
								else act = set_sl_or_if;
							end
							else act = do_nothing;
		
		Sloting			:	if(slot == 15'b0) act = bs_new_rn16;
							else act = do_nothing;
		
		Arbitrate		:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) act = init_inventory;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) act = dec_slot;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) act = adj_q;
								else act = do_nothing;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) act = do_nothing;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) act = do_nothing;
								else act = set_sl_or_if;
							end
							else act = do_nothing;
					   
		Reply			:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) act = init_inventory;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) act = dec_slot;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) act = adj_q;
								else act = do_nothing;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == rn16) act = reply_ack;
								else act = do_nothing;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) act = do_nothing;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) act = do_nothing;
								else act = set_sl_or_if;
							end
							else act = do_nothing;
					   
		Acknowledged	:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) act = init_inventory;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) act = dec_slot_tran_if;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) act = adj_q_tran_if;
								else act = do_nothing;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == rn16) act = reply_ack;
								else act = do_nothing;
							end
							else if(cmd_checked == Req_RN) begin
								if(param[31:16] == rn16) act = gen_and_bs_new_handle;
								else act = do_nothing;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) act = do_nothing;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) act = do_nothing;
								else act = set_sl_or_if;
							end
							else act = do_nothing;

		SlotTran		:	if(param[11:10] == session) begin
								if(slot == 15'b0) act = bs_new_rn16_tran_if;
								else act = tran_if;
							end
							else act = do_nothing;
			
		Open			:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) act = init_inventory;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) act = dec_slot_tran_if;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) act = adj_q_tran_if;
								else act = do_nothing;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == rn16) act = reply_ack;
								else act = do_nothing;
							end
							else if(cmd_checked == Req_RN) begin
								if(param[31:16] == handle) act = bs_new_rn16_crc16;
								else act = do_nothing;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) act = do_nothing;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) act = do_nothing;
								else act = set_sl_or_if;
							end
							else if(cmd_checked == Read) begin
								case(param[49:48])
									2'b00 :	if(param[39:32] == 8'h0) begin
												if(~kill_lock & ~accs_lock & param[47:40] < 8'h3) act = bs_read_data;
												else act = bs_error_code;
											end
											else begin
												if((~kill_lock & param[47:40] < 8'h2 & (param[47:40] + param[39:32] < 8'h3)) |
												   (~accs_lock & param[47:40] < 8'h4 & param[47:40] > 8'h1 & (param[47:40] + param[39:32] < 8'h5)) |
												   (~kill_lock & ~accs_lock & (param[47:40] + param[39:32] < 8'h5))) act = bs_read_data;
												else act = bs_error_code;
											end
									2'b01 : if(param[39:32] == 8'h0) begin
												if(~epc_lock & (param[47:40] < 8'h15)) act = bs_read_data;
												else act = bs_error_code;
											end
											else begin
												if(~epc_lock & ((param[47:40] + param[39:32]) < 8'hf)) act = bs_read_data;
												else act = bs_error_code;
											end
									2'b10 : if(param[39:32] == 8'h0) begin
												if(~tid_lock & param[47:40] < 8'h2) act = bs_read_data;
												else act = bs_error_code;
											end
											else begin
												if(~tid_lock & ((param[47:40] + param[39:32]) < 8'h3)) act = bs_read_data;
												else act = bs_error_code;
											end
									2'b11 : act = bs_error_code;
								endcase
							end
							else if(cmd_checked == Kill) begin
								if((param[50:35] ^ rn16) == 16'hd357 & param[31:16] == handle) act = bs_handle;
								else act = do_nothing;
							end
							else act = do_nothing;
						
		Secured			:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) act = init_inventory;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryRep) begin
								if(param[1:0] == session) act = dec_slot_tran_if;
								else act = do_nothing;
							end
							else if(cmd_checked == QueryAdjust) begin
								if(param[4:3] == session) act = adj_q_tran_if;
								else act = do_nothing;
							end
							else if(cmd_checked == ACK) begin
								if(param[15:0] == rn16) act = reply_ack;
								else act = do_nothing;
							end
							else if(cmd_checked == Req_RN) begin
								if(param[31:16] == handle) act = bs_new_rn16_crc16;
								else act = do_nothing;
							end
							else if(cmd_checked == Select) begin
								if(param[51:49] == 3'b101 | param[51:49] == 3'b110 | param[51:49] == 3'b111) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[43:36] != 8'b0) act = do_nothing;
								else if(param[45:44] == 2'b00 & param[35:28] != 8'b0000_1000) act = do_nothing;
								else if(param[16] & (param[51:49] != 3'b100 | param[45:44] != 2'b01)) act = do_nothing;
								else act = set_sl_or_if;
							end
							else if(cmd_checked == Read) begin
								case(param[49:48])
									2'b00 :	if(param[39:32] == 8'h0) begin
												if(~kill_lock & ~accs_lock & param[47:40] < 8'h3) act = bs_read_data;
												else act = bs_error_code;
											end
											else begin
												if((~kill_lock & param[47:40] < 8'h2 & (param[47:40] + param[39:32] < 8'h3)) |
												   (~accs_lock & param[47:40] < 8'h4 & param[47:40] > 8'h1 & (param[47:40] + param[39:32] < 8'h5)) |
												   (~kill_lock & ~accs_lock & (param[47:40] + param[39:32] < 8'h5))) act = bs_read_data;
												else act = bs_error_code;
											end
									2'b01 : if(param[39:32] == 8'h0) begin
												if(~epc_lock & (param[47:40] < 8'h15)) act = bs_read_data;
												else act = bs_error_code;
											end
											else begin
												if(~epc_lock & ((param[47:40] + param[39:32]) < 8'hf)) act = bs_read_data;
												else act = bs_error_code;
											end
									2'b10 : if(param[39:32] == 8'h0) begin
												if(~tid_lock & param[47:40] < 8'h2) act = bs_read_data;
												else act = bs_error_code;
											end
											else begin
												if(~tid_lock & ((param[47:40] + param[39:32]) < 8'h3)) act = bs_read_data;
												else act = bs_error_code;
											end
									2'b11 : act = bs_error_code;
								endcase
							end
							else if(cmd_checked == Kill) begin
								if((param[50:35] ^ rn16) == 16'hd357 & param[31:16] == handle) act = bs_handle;
								else act = do_nothing;
							end
							else if(cmd_checked == Lock) begin
								if(param[43:42] != 2'b00 | (({param[50], param[40]} == 2'b10) & lock_act[8]) | (({param[48], param[38]} == 2'b10) & lock_act[6]) | (({param[46], param[36]} == 2'b10) & lock_act[4]) | (({param[44], param[34]} == 2'b10) & lock_act[2])) act = bs_error_code;
								else act = bs_header_lock;
							end
							else act = do_nothing;
					   
		Killing			:	if(cmd_checked == Query) begin
								if((param[11:9] == {2'b00, if_s0} | param[11:9] == {2'b01, if_s1} | param[11:9] == {2'b10, if_s2} | param[11:9] == {2'b11, if_s3}) & (~param[13] | param[13:12] == sl)) act = init_inventory;
								else act = do_nothing;
							end
							else if(cmd_checked == Req_RN) begin
								if(param[31:16] == handle) act = bs_new_rn16_crc16;
								else act = do_nothing;
							end
							else if(cmd_checked == Kill) begin
								if((param[50:35] ^ rn16) == 16'h06cc & param[31:16] == handle) act = bs_header_kill;
								else act = do_nothing;
							end
							else act = do_nothing;
					   
		Killed			:	act = do_nothing;
		
		default		 	:	act = do_nothing;
	endcase
end


// --- define matching/not-matching from Select command ---
always@(*) begin
	if(act == set_sl_or_if) begin
		if(param[45:44] == 2'b01 & param[43:36] < 8'b1100_0000 & ((param[43:36] - param[35:28]) > 8'b0)) mch = 1'b1;
		else if(param[45:44] == 2'b10 & param[43:36] < 8'b0010_0000 & ((param[43:36] - param[35:28]) > 8'b0)) mch = 1'b1;
	end
	else mch = 1'b0;
end


// --- execute the actions ---
always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) ptr <= 8'b0;
	else if(act == set_sl_or_if) ptr <= param[43:36] - param[35:28];
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) trct <= 1'b0;
	else if(act == set_sl_or_if) trct <= param[16];
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) sl <= 2'b10;
	else if(act == set_sl_or_if & param[51:49] == 3'b100) begin
		if(mch) begin
			case(param[48:46])
				3'b000 : sl <= 2'b11;
				3'b001 : sl <= 2'b11;
				3'b011 : sl <= ~sl;
				3'b100 : sl <= 2'b10;
				3'b101 : sl <= 2'b10;
			endcase
		end
		else begin
			case(param[48:46])
				3'b000 : sl <= 2'b10;
				3'b010 : sl <= 2'b10;
				3'b100 : sl <= 2'b11;
				3'b110 : sl <= 2'b11;
				3'b111 : sl <= ~sl;
			endcase
		end
	end
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) if_s0 <= 1'b0;
	else if(act == set_sl_or_if & param[51:49] == 3'b000) begin
		if(mch) begin
			case(param[48:46])
				3'b000 : if_s0 <= 1'b0;
				3'b001 : if_s0 <= 1'b0;
				3'b011 : if_s0 <= ~if_s0;
				3'b100 : if_s0 <= 1'b0;
				3'b101 : if_s0 <= 1'b0;
			endcase
		end
		else begin
			case(param[48:46])
				3'b000 : if_s0 <= 1'b1;
				3'b010 : if_s0 <= 1'b1;
				3'b100 : if_s0 <= 1'b0;
				3'b110 : if_s0 <= 1'b0;
				3'b111 : if_s0 <= ~if_s0;
			endcase
		end
	end
	else if(act == bs_new_rn16_tran_if & session == 2'b00) if_s0 <= ~if_s0;
	else if(act == tran_if & session == 2'b00) if_s0 <= ~if_s0;
	else if(act == dec_slot_tran_if & session == 2'b00) if_s0 <= ~if_s0;
	else if(act == adj_q_tran_if & session == 2'b00) if_s0 <= ~if_s0;
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) if_s1 <= 1'b0;
	else if(act == set_sl_or_if & param[51:49] == 3'b001) begin
		if(mch) begin
			case(param[48:46])
				3'b000 : if_s1 <= 1'b0;
				3'b001 : if_s1 <= 1'b0;
				3'b011 : if_s1 <= ~if_s1;
				3'b100 : if_s1 <= 1'b1;
				3'b101 : if_s1 <= 1'b1;
			endcase
		end
		else begin
			case(param[48:46])
				3'b000 : if_s1 <= 1'b1;
				3'b010 : if_s1 <= 1'b1;
				3'b100 : if_s1 <= 1'b0;
				3'b110 : if_s1 <= 1'b0;
				3'b111 : if_s1 <= ~if_s1;
			endcase
		end
	end
	else if(act == bs_new_rn16_tran_if & session == 2'b01) if_s1 <= ~if_s1;
	else if(act == tran_if & session == 2'b01) if_s1 <= ~if_s1;
	else if(act == dec_slot_tran_if & session == 2'b01) if_s1 <= ~if_s1;
	else if(act == adj_q_tran_if & session == 2'b01) if_s1 <= ~if_s1;
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) if_s2 <= 1'b0;
	else if(act == set_sl_or_if & param[51:49] == 3'b010) begin
		if(mch) begin
			case(param[48:46])
				3'b000 : if_s2 <= 1'b0;
				3'b001 : if_s2 <= 1'b0;
				3'b011 : if_s2 <= ~if_s2;
				3'b100 : if_s2 <= 1'b1;
				3'b101 : if_s2 <= 1'b1;
			endcase
		end
		else begin
			case(param[48:46])
				3'b000 : if_s2 <= 1'b1;
				3'b010 : if_s2 <= 1'b1;
				3'b100 : if_s2 <= 1'b0;
				3'b110 : if_s2 <= 1'b0;
				3'b111 : if_s2 <= ~if_s2;
			endcase
		end
	end
	else if(act == bs_new_rn16_tran_if & session == 2'b10) if_s2 <= ~if_s2;
	else if(act == tran_if & session == 2'b10) if_s2 <= ~if_s2;
	else if(act == dec_slot_tran_if & session == 2'b10) if_s2 <= ~if_s2;
	else if(act == adj_q_tran_if & session == 2'b10) if_s2 <= ~if_s2;
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) if_s3 <= 1'b0;
	else if(act == set_sl_or_if & param[51:49] == 3'b011) begin
		if(mch) begin
			case(param[48:46])
				3'b000 : if_s3 <= 1'b0;
				3'b001 : if_s3 <= 1'b0;
				3'b011 : if_s3 <= ~if_s3;
				3'b100 : if_s3 <= 1'b1;
				3'b101 : if_s3 <= 1'b1;
			endcase
		end
		else begin
			case(param[48:46])
				3'b000 : if_s3 <= 1'b1;
				3'b010 : if_s3 <= 1'b1;
				3'b100 : if_s3 <= 1'b0;
				3'b110 : if_s3 <= 1'b0;
				3'b111 : if_s3 <= ~if_s3;
			endcase
		end
	end
	else if(act == bs_new_rn16_tran_if & session == 2'b11) if_s3 <= ~if_s3;
	else if(act == tran_if & session == 2'b11) if_s3 <= ~if_s3;
	else if(act == dec_slot_tran_if & session == 2'b11) if_s3 <= ~if_s3;
	else if(act == adj_q_tran_if & session == 2'b11) if_s3 <= ~if_s3;
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) dr <= 1'b0;
	else if(act == init_inventory) dr <= param[17];
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) m <= 2'b00;
	else if(act == init_inventory) m <= param[16:15];
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) trext <= 1'b0;
	else if(act == init_inventory) trext <= param[14];
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) session <= 2'b00;
	else if(act == init_inventory) session <= param[11:10];
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) q <= 4'b0;
	else if(act == init_inventory) q <= param[8:5];
	else if(act == adj_q | act == adj_q_tran_if) begin
		if(param[2:0] == 3'b110) q <= q + 4'b1;
		else if(param[2:0] == 3'b011) q <= q - 4'b1;
	end
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) slot <= 15'h2ac7;
	else if(act == init_inventory) begin
		case(param[8:5])
		    4'h0 : slot <= 15'b0;
			4'h1 : slot <= {14'b0, prn[0]};
			4'h2 : slot <= {13'b0, prn[1:0]};
			4'h3 : slot <= {12'b0, prn[2:0]};
			4'h4 : slot <= {11'b0, prn[3:0]};
			4'h5 : slot <= {10'b0, prn[4:0]};
			4'h6 : slot <= {9'b0, prn[5:0]};
			4'h7 : slot <= {8'b0, prn[6:0]};
			4'h8 : slot <= {7'b0, prn[7:0]};
			4'h9 : slot <= {6'b0, prn[8:0]};
			4'ha : slot <= {5'b0, prn[9:0]};
			4'hb : slot <= {4'b0, prn[10:0]};
			4'hc : slot <= {3'b0, prn[11:0]};
			4'hd : slot <= {2'b0, prn[12:0]};
			4'he : slot <= {1'b0, prn[13:0]};
			4'hf : slot <= prn[14:0];
		endcase
	end
	else if(act == adj_q | act == adj_q_tran_if) begin
		if(param[2:0] == 3'b110) begin
			case(q)
				4'hf : slot <= 15'b0;
				4'h0 : slot <= {14'b0, prn[0]};
				4'h1 : slot <= {13'b0, prn[1:0]};
				4'h2 : slot <= {12'b0, prn[2:0]};
				4'h3 : slot <= {11'b0, prn[3:0]};
				4'h4 : slot <= {10'b0, prn[4:0]};
				4'h5 : slot <= {9'b0, prn[5:0]};
				4'h6 : slot <= {8'b0, prn[6:0]};
				4'h7 : slot <= {7'b0, prn[7:0]};
				4'h8 : slot <= {6'b0, prn[8:0]};
				4'h9 : slot <= {5'b0, prn[9:0]};
				4'ha : slot <= {4'b0, prn[10:0]};
				4'hb : slot <= {3'b0, prn[11:0]};
				4'hc : slot <= {2'b0, prn[12:0]};
				4'hd : slot <= {1'b0, prn[13:0]};
				4'he : slot <= prn[14:0];
			endcase
		end
		else if(param[2:0] == 3'b011) begin
			case(q)
				4'h1 : slot <= 15'b0;
				4'h2 : slot <= {14'b0, prn[0]};
				4'h3 : slot <= {13'b0, prn[1:0]};
				4'h4 : slot <= {12'b0, prn[2:0]};
				4'h5 : slot <= {11'b0, prn[3:0]};
				4'h6 : slot <= {10'b0, prn[4:0]};
				4'h7 : slot <= {9'b0, prn[5:0]};
				4'h8 : slot <= {8'b0, prn[6:0]};
				4'h9 : slot <= {7'b0, prn[7:0]};
				4'ha : slot <= {6'b0, prn[8:0]};
				4'hb : slot <= {5'b0, prn[9:0]};
				4'hc : slot <= {4'b0, prn[10:0]};
				4'hd : slot <= {3'b0, prn[11:0]};
				4'he : slot <= {2'b0, prn[12:0]};
				4'hf : slot <= {1'b0, prn[13:0]};
				4'h0 : slot <= prn[14:0];
			endcase
		end
	end
	else if(act == dec_slot | act == dec_slot_tran_if) slot <= slot - 15'b1;
end

always@(posedge clk_cp or negedge rst_n) begin
	if(~rst_n) lock_act <= 10'b00_0000_0011;
	else begin
		if(act == bs_header_lock) begin
			if(param[43:42] != 2'b00) lock_act <= lock_act;
			else if(({param[50], param[40]} == 2'b10) & lock_act[8]) lock_act <= lock_act;
			else if(({param[48], param[38]} == 2'b10) & lock_act[6]) lock_act <= lock_act;
			else if(({param[46], param[36]} == 2'b10) & lock_act[4]) lock_act <= lock_act;
			else if(({param[44], param[34]} == 2'b10) & lock_act[2]) lock_act <= lock_act;
			else begin
				if(param[51]) lock_act[9] <= param[41];
				if(param[50]) lock_act[8] <= param[40];
				if(param[49]) lock_act[7] <= param[39];
				if(param[48]) lock_act[6] <= param[38];
				if(param[47]) lock_act[5] <= param[37];
				if(param[46]) lock_act[4] <= param[36];
				if(param[45]) lock_act[3] <= param[35];
				if(param[44]) lock_act[2] <= param[34];
//				if(param[43]) lock_act[1] <= param[33];
//				if(param[42]) lock_act[0] <= param[32];
			end
		end
	end
end


// --- Lcok action-field functionality ---
always@(*) begin
	case(lock_act[3:2])
		2'b00 : if((ps == Open) | (ps == Secured)) tid_lock = 0;
				else tid_lock = 1;
		2'b01 : if((ps == Open) | (ps == Secured)) tid_lock = 0;
				else tid_lock = 1;
		2'b10 : if(ps == Secured) tid_lock = 0;
				else tid_lock = 1;
		2'b11 : tid_lock = 1;
	endcase
end

always@(*) begin
	case(lock_act[5:4])
		2'b00 : if((ps == Open) | (ps == Secured)) epc_lock = 0;
				else epc_lock = 1;
		2'b01 : if((ps == Open) | (ps == Secured)) epc_lock = 0;
				else epc_lock = 1;
		2'b10 : if(ps == Secured) epc_lock = 0;
				else epc_lock = 1;
		2'b11 : epc_lock = 1;
	endcase
end

always@(*) begin
	case(lock_act[7:6])
		2'b00 : if((ps == Open) | (ps == Secured)) accs_lock = 0;
				else accs_lock = 1;
		2'b01 : if((ps == Open) | (ps == Secured)) accs_lock = 0;
				else accs_lock = 1;
		2'b10 : if(ps == Secured) accs_lock = 0;
				else accs_lock = 1;
		2'b11 : accs_lock = 1;
	endcase
end

always@(*) begin
	case(lock_act[9:8])
		2'b00 : if((ps == Open) | (ps == Secured)) kill_lock = 0;
				else kill_lock = 1;
		2'b01 : if((ps == Open) | (ps == Secured)) kill_lock = 0;
				else kill_lock = 1;
		2'b10 : if(ps == Secured) kill_lock = 0;
				else kill_lock = 1;
		2'b11 : kill_lock = 1;
	endcase
end


// --- action register for operand isolation ---
always@(posedge clk_cp or negedge rst_for_new_package) begin
	if(~rst_for_new_package) act_reg <= 5'h0;
	else act_reg <= act;
end


// --- clk_cp control ---
always@(*) begin
	if(act_reg == init_inventory | act_reg == adj_q | act_reg == dec_slot | act_reg == adj_q_tran_if | act_reg == dec_slot_tran_if) en_2nd_clk_cp = 1'b1;
	else en_2nd_clk_cp = 1'b0;
end


// --- enable PRNG ---
always@(*) begin
	if(ps == Ready) en_prng_idol = 1'b1;
	else en_prng_idol = 1'b0;
end

always@(*) begin
	if(act_reg == bs_new_rn16 | act_reg == bs_new_rn16_tran_if | act_reg == gen_and_bs_new_handle | act_reg == bs_new_rn16_crc16) en_prng_act = 1'b1;
	else en_prng_act = 1'b0;
end


// --- enable TX ---
always@(*) begin
	case(act_reg)
		bs_new_rn16				: en_tx = 1'b1;
		reply_ack				: en_tx = 1'b1;
		bs_new_rn16_tran_if		: en_tx = 1'b1;
		gen_and_bs_new_handle	: en_tx = 1'b1;
		bs_new_rn16_crc16		: en_tx = 1'b1;
		bs_read_data			: en_tx = 1'b1;
		bs_handle				: en_tx = 1'b1;
		bs_header_kill			: en_tx = 1'b1;
		bs_header_lock			: en_tx = 1'b1;
		bs_error_code			: en_tx = 1'b1;
		default					: en_tx = 1'b0;
	endcase
end


// --- enable memory interface and ROM --- 
always@(*) begin
	if(act_reg == reply_ack) begin
		if(~trct & pre_p_complete) en_if = 1'b1;
		else if(trct & p_complete & (r_cnt < r_end + 5'h02)) en_if = 1'b1;
		else en_if = 1'b0;
	end
	else if(act_reg == bs_read_data) begin
		if(p_complete) en_if = 1'b1;
		else en_if = 1'b0;
	end
	else en_if = 1'b0;
end


// --- enable CRC-16 for replying data ---
always@(*) begin
	if(p_complete & (act_reg == reply_ack | act_reg == gen_and_bs_new_handle | act_reg == bs_new_rn16_crc16 | act_reg == bs_read_data |
	   act_reg == bs_handle | act_reg == bs_header_kill | act_reg == bs_header_lock)) en_crc16_for_rpy = 1'b1;
	else en_crc16_for_rpy = 1'b0;
end


// --- deliver address to memory interface ---
always@(*) begin
	if(act_reg == reply_ack) begin
		if(~trct) addr = {1'b0, 2'b01, 8'b0, 8'b0};
		else addr = {1'b0, 2'b01, ptr, 8'b0};
	end
	else if(act_reg == bs_read_data) addr = {1'b1, param[49:32]};
	else addr = 19'b0;
end


// --- load a new RN16 or handle ---
assign clk_cp_n = ~clk_cp;

always@(posedge clk_cp_n or negedge rst_n) begin
	if(~rst_n) rn16 <= 16'hac70;
	else if(act_reg == bs_new_rn16 | act_reg == bs_new_rn16_tran_if | act_reg == bs_new_rn16_crc16) rn16 <= prn[15:0];
end

always@(posedge clk_cp_n or negedge rst_n) begin
	if(~rst_n) handle <= 16'hff31;
	else if(act_reg == gen_and_bs_new_handle) handle <= prn[15:0];
end


// --- enable/disable reply counter ---
always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) en_if_d <= 1'b0;
	else en_if_d <= en_if;
end

wire en_r_cnt;

assign en_r_cnt = ~en_if_d | rd_complete;


// --- control reply counter ---
always@(posedge clk_frm or negedge rst_for_new_package) begin
	if(~rst_for_new_package) r_cnt <= 5'h17;
	else if(p_complete & en_r_cnt) begin
		if(r_cnt != r_end) r_cnt <= r_cnt - 1;
		else r_cnt <= r_cnt;
	end
end


// --- determine the end of reply counter ---
always@(*) begin
	case(act_reg)
		bs_new_rn16				:	r_end = 5'h08;
		reply_ack				:	if(~trct) r_end = 5'h17;
									else r_end = 5'h12;
		bs_new_rn16_tran_if		:	r_end = 5'h08;
		gen_and_bs_new_handle	:	r_end = 5'h08;
		bs_new_rn16_crc16		:	r_end = 5'h08;
		bs_read_data			:	r_end = 5'h06;
		bs_handle				:	r_end = 5'h08;
		bs_header_kill			:	r_end = 5'h07;
		bs_header_lock			:	r_end = 5'h07;
		bs_error_code			:	r_end = 5'h00;
		default					:	r_end = 5'h00;
	endcase
end


// --- reply data ---
always@(*) begin
	case(act_reg)
		bs_new_rn16				:	reply_data = rn16[r_cnt - 5'h08];
		reply_ack				:	if(~trct) reply_data = rd_data;
									else begin
										if(r_cnt > 5'h12) reply_data = 1'b0;
										else reply_data = rd_data;
									end
		bs_new_rn16_tran_if		:	reply_data = rn16[r_cnt - 5'h08];
		gen_and_bs_new_handle	:	reply_data = handle[r_cnt - 5'h08];
		bs_new_rn16_crc16		:	reply_data = rn16[r_cnt - 5'h08];
		bs_read_data			:	if(r_cnt == 5'h17) reply_data = 1'b0;
									else if(r_cnt == 5'h16) reply_data = rd_data;
									else if(r_cnt < 5'h16 & r_cnt > 5'h5) reply_data = handle[r_cnt - 5'h6];
									else reply_data = 1'b0;
		bs_handle				:	reply_data = handle[r_cnt - 5'h08];
		bs_header_kill			:	if(r_cnt == 5'h17) reply_data = 1'b0;
									else if(r_cnt < 5'h17 & r_cnt > 5'h6) reply_data = handle[r_cnt - 5'h07];
									else reply_data = 1'b0;
		bs_header_lock			:	if(r_cnt == 5'h17) reply_data = 1'b0;
									else if(r_cnt < 5'h17 & r_cnt > 5'h6) reply_data = handle[r_cnt - 5'h07];
									else reply_data = 1'b0;
		bs_error_code			:	if(r_cnt > 5'h13) reply_data = 1'b0;
									else if(r_cnt < 5'h14 & r_cnt > 5'h0f) reply_data = 1'b1;
									else reply_data = handle[r_cnt];
		default					:	reply_data = 1'b0;
	endcase
end


// --- determine when does the replying data complete ---
always@(*) begin
	if(act_reg == reply_ack) begin
		if(rd_complete) reply_complete = 1'b1;
		else reply_complete = 1'b0;
	end
	else begin
		if(r_cnt == r_end) reply_complete = 1'b1;
		else reply_complete = 1'b0;
	end
end


endmodule
