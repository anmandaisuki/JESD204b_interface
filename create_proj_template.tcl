# Refer UG835.
# URL: https://docs.xilinx.com/v/u/ja-JP/ug835-vivado-tcl-commands


set origin_dir "."
set project_name "Project_Name"
#set board_part [get_board_parts -quiet -latest_file_version "*zc706*"]
set target_part "xcau25p-ffvb676-2-i"
set rtl_folder "src"


create_project $origin_dir $project_name

# target setting
# if{[info exists ::target_part]}{
#     puts "$target_part"
#     puts " is selected."
# } else {
#     puts "ERROR: Please set target_part."
#     return 1
# }

# project setting
set_property "default_lib"        "xil_defaultlib" [current_project]
set_property "simulator_language" "Mixed"          [current_project]
set_property "target_language"    "verilog"        [current_project]

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set obj [current_project]
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/$project_name.cache/ip" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "part" -value $target_part -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/$project_name.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "sim_compile_state" -value "1" -objects $obj
set_property -name "webtalk.activehdl_export_sim" -value "1" -objects $obj
set_property -name "webtalk.modelsim_export_sim" -value "1" -objects $obj
set_property -name "webtalk.questa_export_sim" -value "1" -objects $obj
set_property -name "webtalk.riviera_export_sim" -value "1" -objects $obj
set_property -name "webtalk.vcs_export_sim" -value "1" -objects $obj
set_property -name "webtalk.xsim_export_sim" -value "1" -objects $obj


# sources_1 is created if not existed.
if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}

# constrs_1 is created if not existed.
if {[string equal [get_filesets -quiet constrs_1] ""]} {
    create_fileset -constrset constrs_1
}

# sim_1 is created if not existed.
if {[string equal [get_filesets -quiet sim_1] ""]} {
    create_fileset -simset sim_1
}

# add_files -fileset sources_1 
add_files -fileset sources_1 src

set ips [glob src/*.xci]
add_files -fileset sources_1 $ips

update_ip_catalog

# add 