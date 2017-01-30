# Create library

# The following command is an example of creating a library
# Please define and create your own library

create_mw_lib	-technology		./tsmc18_CIC.tf		-mw_reference_library {./rom_64x16_frame/rom_64x16 ./tsmc18_fram ./tpz973gv ./tpb973gv}



# Check library

set_check_library_option	-all

check_library



# Specify tlu* parasitic RC model files

# Please define your tluplus and map files of process

set_tlu_plus_files	-max_tluplus ./t18.tluplus	-min_tluplus ./t18.tluplus	-tech2itf_map ./t18.map



# Read the netlist and create a design cel

import_designs {./bb_proc_syn.v}	-foramt verilog		-top bb_proc	-cel bb_proc



# Verify logical library are loaded

list_libs



# Define logical power/ground connections

derive_pg_connection	-power_net VDD	-power_pin VDD		-ground_net VSS	-ground_pin VSS

check_mw_design	-power_nets



# Apply and check timing constraints

read_sdc	./bb_proc_syn.sdc

report_timing

report_timing_requirements

report_case_analysis



# Ensure proper modeling of clock tree

report_clock	-skew



# Apply timing and optimization controls

set timing_enable_multiple_clocks_per_reg	true

set case_analysis_with_logic_constants		true

set fix_multiple_port_nets	-all	-buffer_constants

set_auto_disable_drc_nets	-constant	false

set_max_area	0



# Perform a timing sanity check

set_zero_interconnect_delay_mode	true

report_constraints	-all

report_timing

set_zero_interconnect_delay_mode	false



# Save the design

save_mw_cel	bb_proc

save_mw_cel bb_proc	-as design_setup



# I/O order assignments

set_pin_physical_constraints	-side 4		-pin_name bs_data			-order 1	-width 1	-depth 1	-offset 30

set_pin_physical_constraints	-side 4		-pin_name clk_200K			-order 2	-width 1	-depth 1	-offset 130

set_pin_physical_constraints	-side 4		-pin_name rst				-order 3	-width 1	-depth 1	-offset 230

set_pin_physical_constraints	-side 4		-pin_name clk_dpie			-order 4	-width 1	-depth 1	-offset 330

set_pin_physical_constraints	-side 4		-pin_name pie_code			-order 5	-width 1	-depth 1	-offset 430

set_pin_physical_constraints	-side 3		-pin_name package_complete	-order 1	-width 1	-depth 1	-offset 430

set_pin_physical_constraints	-side 3		-pin_name crc_check_pass	-order 2	-width 1	-depth 1	-offset 330



# Design planning

gui_set_current_task	-name	{ALL}

create_floorplan	-core_utilization 0.4	-core_aspect_ratio 1	-left_io2core 20	-bottom_io2core 20	-right_io2core 20	-top_io2core 20

set_fp_macro_options	[get_cells rom_64x16_1]		-legal_orientations W

set_keepout_matgin	-type hard	-outer {10 0 10 0}	rom_64x16_1

set physopt_hard_keepout_distance 10

set_fp_placement_strategy	-macros_on_edge on

set_fp_placement_strategy	-auto_grouping	high

create_fp_placement

set_dont_touch_placement	[all_macro_cells]

create_fp_placement		-timing_driven	-incremental	all

derive_pg_connection	-power_net {VDD}	-ground_net {VSS}	-power_pin {VDD}	-ground_pin {VSS}

create_fp_virtual_pad	-net VDD	-point {63.850 0.000}

create_fp_virtual_pad	-net VDD	-point {404.685 -0.860}

create_fp_virtual_pad	-net VSS	-point {94.915 0.000}

create_fp_virtual_pad	-net VSS	-point {369.310 0.000}

set_fp_rail_constraints	-add_layer	-layer METAL5	-direction horizontal	-max_strap 10	-min_strap 3	-max_width 4	-min_width 4	-spacing minimum

set_fp_rail_constraints	-add_layer	-layer METAL4	-direction vertical		-max_strap 10	-min_strap 3	-max_width 4	-min_width 4	-spacing minimum

set_fp_rail_constraints	-set_ring	-nets {VDD VSS VDD VSS VDD VSS}		-horizontal_ring_layer {METAL5}		-vertical_ring_layer {METAL4}	-ring_width 8	-extend_strap core_ring

set_fp_rail_constraints	-set_global	-no_routing_over_hard_macros

set_fp_block_ring_constraints	-add 	-horizontal_layer METAL5	-horizontal_width 1.5	-horizontal_offset 1	-vertical_layer METAL4	-vertical_width 1.5		-vertical_offset 1		-block_type master	-block {rom_64x16}	-net {VDD VSS}

synthesize_fp_rail	-nets {VDD VSS}		-voltage_supply 1.6		-target_voltage_drop 100	-synthesize_power_plan	-power_budget 200

commit_fp_rail

preroute_instances	-ignore_macros	-ignore_cover_cells	-primary_routing_layer pin	-extend_for_multiple_connections	-extension_gap 16

preroute_instances	-ignore_pads	-ignore_cover_cells	-primary_routing_layer pin

preroute_standard_cells	-extend_for_multiple_connections	-extension_gap 16	-connect horizontal		-remove_floating_pieces		-do_not_route_over_macros	-fill_empty_rows	-port_filter_mode off	-cell_instance_filter_mode off	-voltage_area_filter_mode off

set_pnet_options	-complete "METAL4 METAL5"

create_fp_placement	-incremental all



# Placement

read_sdc	-version Latest "./bb_proc_syn.sdc"

check_physical_design	-stage pre_place_opt

source	./add_tie.tcl

place_opt	-power	-optimize_dft

derive_pg_connection	-power_net {VDD}	-ground_net {VSS}	-power_pin {VDD}	-ground_pin {VSS}



# CTS

remove_clock_tree

set_clock_tree_options	-target_early_delay 0.9		-target_skew 0.1

clock_opt	-only_cts	-no_clock_route

route_group	-all_clock_nets

clock_opt	-only_psyn

set_fix_hold	[all_clocks]

clock_opt	-only_psyn

optimize_clock_tree



# Route

check_zrt_routability	-error_view		bb_proc.err

set_route_zrt_common_options	-post_detail_route_redundant_via_insertion high		-concurrent_redundant_via_mode insert_at_high_cost	-concurrent_redundant_via_effort_level high

route_zrt_group	-all_clock_nets

route_zrt_auto

derive_pg_connection	-power_net {VDD}	-ground_net {VSS}	-power_pin {VDD}	-ground_pin {VSS}



# DFM

source	./addCoreFiller.cmd

verify_zrt_route

route_zrt_detail	-incremental true	-initial_drc_from_input	true

derive_pg_connection	-power_net {VDD}	-ground_net {VSS}	-power_pin {VDD}	-ground_pin {VSS}

# Specify the I/O pins
# Please specify the I/O pins in GUI
# The following commands are examples of specifying the I/O pins
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {bs_data}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {VDD}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {VSS}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {rst}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {pie_code}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {clk_dpie}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {clk_200K}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {package_complete}
# gui_set_mouse_tool_option	-tool CreateTextTool	-option {text}		-value {crc_check_pass}

save_mw_cel	-design "bb_proc.CEL;1"

set_write_stream_options	-map_layer ./macro.map	-child_depth 20		-flatten_via

write_stream	-format gds		-lib_name ./rfid_tag_bb_proc	-cell {bb_proc}		bb_proc.gds

write_sdf	-version 2.0	-context verilog	-load_delay net		bb_proc.sdf



# Save design

save_mw_cel	-design "bb_proc.CEL;1"
