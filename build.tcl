# Top level example build file for tcl-vivado scripting

#############
# IP Settings
#############

set design riscv_rv64g

set projdir ./riscv_rv64g/

set root "."

# FPGA device
set partname "xc7z020clg400-1"

# Board part
# (not needed for Parallella board -
# for ZedBoard use "em.avnet.com:zed:part0:1.3")
set boardpart ""

set hdl_files [list $root/hdl/]

set ip_files []

set constraints_files []

# Other variables
set clk_m_axi "m_axi_aclk"
set clk_s_axi "s_axi_aclk"

###########################
# Create Managed IP Project
###########################

create_project -force $design $projdir -part $partname 
set_property target_language Verilog [current_project]
set_property source_mgmt_mode None [current_project]

if {$boardpart != ""} {
set_property "board_part" $boardpart [current_project]
}

##########################################
# Create filesets and add files to project
##########################################

#HDL
if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}

add_files -norecurse -fileset [get_filesets sources_1] $hdl_files

set_property top $design [get_filesets sources_1]

#CONSTRAINTS
if {[string equal [get_filesets -quiet constraints_1] ""]} {
  create_fileset -constrset constraints_1
}
if {[llength $constraints_files] != 0} {
    add_files -norecurse -fileset [get_filesets constraints_1] $constraints_files
}

#ADDING IP
if {[llength $ip_files] != 0} {
    
    #Add to fileset
    add_files -norecurse -fileset [get_filesets sources_1] $ip_files
   
    #RERUN/UPGRADE IP
    upgrade_ip [get_ips]
}

##########################################
# Synthesize (Optional, checks for sanity)
##########################################

#set_property top $design [current_fileset]
#launch_runs synth_1 -jobs 2
#wait_on_run synth_1


#########
# Package
#########

ipx::package_project -import_files -force -root_dir $projdir
ipx::associate_bus_interfaces -busif s_axi -clock $clk_s_axi [ipx::current_core]
ipx::associate_bus_interfaces -busif m_axi -clock $clk_m_axi [ipx::current_core]

ipx::remove_memory_map {s_axi} [ipx::current_core]
ipx::add_memory_map {s_axi} [ipx::current_core]
set_property slave_memory_map_ref {s_axi} [ipx::get_bus_interfaces s_axi -of_objects [ipx::current_core]]
ipx::add_address_block {axi_lite} [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]
set_property range {65536} [ipx::get_address_blocks axi_lite -of_objects \
    [ipx::get_memory_maps s_axi -of_objects [ipx::current_core]]]

set_property vendor              {www.parallella.org}    [ipx::current_core]
set_property library             {user}                  [ipx::current_core]
set_property taxonomy            {{/AXI_Infrastructure}} [ipx::current_core]
set_property vendor_display_name {ADAPTEVA}              [ipx::current_core]
set_property company_url         {www.parallella.org}    [ipx::current_core]
set_property supported_families  { \
                     {virtex7}    {Production} \
                     {qvirtex7}   {Production} \
                     {kintex7}    {Production} \
                     {kintex7l}   {Production} \
                     {qkintex7}   {Production} \
                     {qkintex7l}  {Production} \
                     {artix7}     {Production} \
                     {artix7l}    {Production} \
                     {aartix7}    {Production} \
                     {qartix7}    {Production} \
                     {zynq}       {Production} \
                     {qzynq}      {Production} \
                     {azynq}      {Production} \
                     }   [ipx::current_core]

############################
# Save and Write ZIP archive
############################

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core [concat $projdir/$design.zip] [ipx::current_core]

#################
# System Settings
#################

#Design name ("system" recommended)
set design system

#Project directory
set projdir ./parallella_riscv/

#Device name
set partname "xc7z020clg400-1"

#Board part
set boardpart ""

#Paths to all IP blocks to use in Vivado "system.bd"
set ip_repos [list "./riscv_rv64g"]

#System's extra source files
set hdl_files []

#System's constraints files
set constraints_files []

################
# CREATE PROJECT
################

create_project -force $design $projdir -part $partname
set_property target_language Verilog [current_project]

if {$boardpart != ""} {
set_property "board_part" $boardpart [current_project]
}

#################################
# Create Report/Results Directory
#################################

set report_dir  $projdir/reports
set results_dir $projdir/results
if ![file exists $report_dir]  {file mkdir $report_dir}
if ![file exists $results_dir] {file mkdir $results_dir}

####################################
# Add IP Repositories to search path
####################################

set other_repos [get_property ip_repo_paths [current_project]]
set_property  ip_repo_paths  "$ip_repos $other_repos" [current_project]

update_ip_catalog

#####################################
# CREATE BLOCK DESIGN (GUI/TCL COMBO)
#####################################

create_bd_design "system"

source ./system.bd.tcl
make_wrapper -files [get_files $projdir/${design}.srcs/sources_1/bd/system/system.bd] -top

###########################################################
# ADD FILES
###########################################################

#HDL
if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
}
set top_wrapper $projdir/${design}.srcs/sources_1/bd/system/hdl/system_wrapper.v
add_files -norecurse -fileset [get_filesets sources_1] $top_wrapper

if {[llength $hdl_files] != 0} {
    add_files -norecurse -fileset [get_filesets sources_1] $hdl_files
}

#CONSTRAINTS
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}
if {[llength $constraints_files] != 0} {
    add_files -norecurse -fileset [get_filesets constrs_1] $constraints_files
}

##############################################
# Validate design and create top-level wrapper
##############################################

validate_bd_design
make_wrapper -files [get_files $projdir/${design}.srcs/sources_1/bd/system/system.bd] -top
remove_files -fileset sources_1 $projdir/${design}.srcs/sources_1/bd/system/hdl/system_wrapper.v
add_files -fileset sources_1 -norecurse $projdir/${design}.srcs/sources_1/bd/system/hdl/system_wrapper.v

###########
# Synthesis
###########

launch_runs synth_1
wait_on_run synth_1

# Report timing summary (optional)
#report_timing_summary -file synth_timing_summary.rpt

#################
# Place and route
#################

launch_runs impl_1
wait_on_run impl_1

# Report timing summary (optional)
#report_timing_summary -file impl_timing_summary.rpt

# Create netlist (optional)
#write_verilog ./system.v

#################
# Write Bitstream
#################

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

exit

