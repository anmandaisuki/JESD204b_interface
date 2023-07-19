# Refer UG835.
# URL: https://docs.xilinx.com/v/u/ja-JP/ug835-vivado-tcl-commands

# Variables. Change these variables below depends on your projects.
set origin_dir "."
set project_name "Project_Name"
set target_part "xcau25p-ffvb676-2-i"
set rtl_src_folder "src"
set ip_repository "src/ip"


#####################################
### Do not change below from here.###
##################################### 

create_project $project_name $origin_dir/$project_name

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

# RTL source and IP(.xci) adding process
    # RTL source is being added
    # check if folder exist or not 
    if { [ file exists $rtl_src_folder ] == 1 } {

        set rtl_list [glob -nocomplain $rtl_src_folder/*.{v,sv,vh}]

        if { [string equal [lindex $rtl_list 0] ""] } {

            puts "There is no RTL file in src directory.\n"

        } else {

            add_files -fileset sources_1 $rtl_src_folder
            puts "rtl source(s) is/are added.\n"

        }
    } else {

        puts "src is not found. Adding src is cancelled. \n"
    }


    # IP(.xci) is being added
    if { [ file exists $ip_repository ] == 1 } {

        set ip_list [glob -nocomplain $ip_repository/*.xci]

        if {[string equal [lindex $ip_list 0] ""]} {

            puts "There is no IP(.xci) file in src directory.\n"

        } else {

            foreach ip $ip_list {
                add_files -fileset sources_1 $ip
                puts "$ip is added.\n"
            }
        }
    } else {

        puts "IP folder doesn't exist.\n"
    }


update_ip_catalog

