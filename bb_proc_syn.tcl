# Clock period

set cycle_dpie 6250

set cycle_200K 5000



# Read design file

read_file -format verilog {./bb_proc.v ./cmd_buf.v ./cmd_proc.v ./crc16.v ./crc5.v ./crg.v ./fm0_enc.v ./frmgen.v ./fs_detector.v ./mem_if.v ./miller_enc.v ./prng.v ./rom_64x16.v ./rx.v ./two_dff_sync.v ./tx.v}
# The file rom_64x16.v is our ROM verilog file
# You should design your memory by writing a module by yourself or generating it by tool

current_design [get_designs bb_proc]

link



# Set design environment

set_operating_conditions -max_library slow -max slow -min_library fast -min fast

set_wire_load_model -name tsmc18_w110 -library slow

set_driving_cell -library slow -lib_cell BUFX4 -no_design_rule [all_inputs]

set_load [load_of "slow/BUFX4/A"] [all_outputs]



# Set clock constraints

create_clock -name clk_dpie -period $cycle_dpie [get_ports clk_dpie]

create_clock -name clk_200K -period $cycle_200K [get_ports clk_200K]

set_dont_touch_network					[get_clocks clk_dpie]

set_dont_touch_network					[get_clocks clk_200K]

set_ideal_network						[get_clocks clk_dpie]

set_ideal_network						[get_clocks clk_200K]

set_fix_hold							[get_clocks clk_dpie]

set_fix_hold							[get_clocks clk_200K]

set_clock_uncertainty	0.1				[get_clocks clk_dpie]

set_clock_uncertainty	0.2				[get_clocks clk_200K]

set_clock_latency		-source 0.5		[get_clocks clk_dpie]

set_clock_latency		-source 0.5		[get_clocks clk_200K]

set_clock_latency		0.5				[get_clocks clk_dpie]

set_clock_latency		0.5				[get_clocks	clk_200K]

set_input_transition	0.5				[all_inputs]

set_clock_transition	0.1				[get_clocks clk_dpie]

set_clock_transition	0.1				[get_clocks clk_200K]

set_input_delay			-max 5		-clock clk_dpie		[all_inputs]

set_input_delay			-min 0.5	-clock clk_dpie		[all_inputs]

set_output_delay		-max 1		-clock clk_200K		[all_outputs]

set_output_delay		-min 1		-clock clk_200K		[all_outputs]

remove_input_delay		-max 	clk_200K

remove_input_delay		-min	clk_200K

set_clock_groups		-asynchronous	-group {clk_dpie}	-group {clk_200K}



# Create generated clock

# Should define the generated clocks to let Synthesis tool know
# The follow commands is an example of specifying the generated clocks in the schematic
# Your generated clocks are possibly not as follows

create_generated_clock	-name clk_blf	-source clk_200K	-divide_by 2					[get_pins crg_1/C471/A]
set_dont_touch_network	[get_clocks clk_blf]
set_ideal_network		[get_pins crg_1/C471/A]

create_generated_clock	-name clk_cp	-source clk_200K	-divide_by 2	-combinational	[get_pins crg_1/C473/Z]
set_dont_touch_network	[get_clocks clk_cp]
set_ideal_network		[get_pins crg_1/C473/Z]

create_generated_clock	-name clk_crc5	-source clk_dpie	-combinational					[get_pins crg_1/C413/Z]
set_dont_touch_network	[get_clocks clk_crc5]
set_ideal_network		[get_pins crg_1/C413/Z]

create_generated_clock	-name clk_crc16	-source clk_dpie	-combinational					[get_pins crg_1/C392/Z_0]
set_dont_touch_network	[get_clocks clk_crc16]
set_ideal_network		[get_pins crg_1/C392/Z_0]

create_generated_clock	-name clk_fm0	-source clk_200K	-divide_by 2	-combinational	[get_pins crg_1/C398/Z_0]
set_dont_touch_network	[get_clocks clk_fm0]
set_ideal_network		[get_pins crg_1/C398/Z_0]

create_generated_clock	-name clk_mem	-source clk_200K	-divide_by 2 	-combinational	[get_pins crg_1/C519/Z]
set_dont_touch_network	[get_clocks clk_mem]
set_ideal_network		[get_pins crg_1/C519/Z]

create_generated_clock	-name clk_mil	-source clk_200K	-divide_by 2 	-combinational	[get_pins crg_1/C400/Z_0]
set_dont_touch_network	[get_clocks clk_mil]
set_ideal_network		[get_pins crg_1/C400/Z_0]

create_generated_clock	-name clk_frm	-source clk_200K	-divide_by 2 	-combinational	[get_pins crg_1/C422/B]
set_dont_touch_network	[get_clocks clk_frm]
set_ideal_network		[get_pins crg_1/C422/B]

create_generated_clock	-name clk_prng	-source clk_200K	-divide_by 2 	-combinational	[get_pins crg_1/C476/Z]
set_dont_touch_network	[get_clocks clk_prng]
set_ideal_network		[get_pins crg_1/C476/Z]



# Set design rule constraints

set_max_area	0

set_max_fanout	20	[all_inputs]

set_max_transition	0.5		[all_inputs]



# Solve multiple instance

uniquify

set_fix_multiple_port_nets	-all	-buffer_constants	[get_designs *]

set case_analysis_with_logic_constants	true



# Synthesis design

compile_ultra	-area_high_effort_script



# Optimization

set_dynamic_optimization	true

compile		-inc

remove_unconnected_ports	-blast_bused	[get_cells * -hier]



set edifout_netlist_only	"TRUE"

set verilogout_no_tri		"TRUE"

history keep	100

alias h history

set bus_interface_style		{%s[%d]}

set bus_naming_style		{%s[%d]}

set hdlout_internal_busses	true

change_names	-hierarchy	-rule	verilog

define_name_rules	name_rule	-allowed {a-z A-Z 0-9 _}	-max_length 255		-type cell

define_name_rules	name_rule	-allowed {a-z A-Z 0-9 _[]}	-max_length 255		-type net

define_name_rules	name_rule	-map {{"\\*cell\\" "cell"}}

change_names	-hierarchy	-rule	name_rule



# Output reports and netlists

# Please create "Report" and "Netlist" directory

report_design					>		Report/bb_proc\.design

report_port						>		Report/bb_proc\.port

report_net						>		Report/bb_proc\.net

report_timing_requirements		>		Report/bb_proc\.timing_requirements

report_constraints				>		Report/bb_proc\.constraints

report_timing					>		Report/bb_proc\.timing

report_area						>		Report/bb_proc\.area

report_resource					>		Report/bb_proc\.resource

report_power					>		Report/bb_proc\.power

set verilogout_higher_design_first		true

write	-format	verilog		-hierarchy	-output		Netlist/bb_proc\_syn.v

write_sdf	-version 2.1	-context verilog	-load_delay net		Netlist/bb_proc\_syn.sdf

write_sdc	Netlist/bb_proc\_syn.sdc

write_file	-format ddc		-hierarchy		-output		Netlist/bb_proc\_syn.ddc
