# ===================================================================================
# create_project.tcl: 创建并配置 Vivado 工程
#
# 如何运行:
# 1. 打开 Vivado Tcl Shell 或 Windows/Linux 终端
# 2. cd 到项目根目录 (my_fpga_project/)
# 3. 运行命令: vivado -mode batch -source ./scripts/create_project.tcl
# ===================================================================================

# --- 递归文件搜索（单个扩展名）---
proc find_files_recursively {search_dir extension} {
    set files {}
    
    # 在当前目录查找指定扩展名的文件
    foreach file [glob -nocomplain [file join $search_dir *.$extension]] {
        lappend files $file
    }
    
    # 递归查找子目录
    foreach subdir [glob -nocomplain -type d [file join $search_dir *]] {
        set subdirfiles [find_files_recursively $subdir $extension]
        set files [concat $files $subdirfiles]
    }
    
    return $files
}

# --- 递归文件搜索（多个扩展名）---
proc find_files_recursively_multi {search_dir extensions} {
    set files {}
    
    # 对每个扩展名进行搜索
    foreach ext $extensions {
        set ext_files [find_files_recursively $search_dir $ext]
        set files [concat $files $ext_files]
    }
    
    return $files
}

# --- 1. 设置变量 ---
# 项目名称
set proj_name "FPGAMatrixCalculator"
# FPGA 型号
set part_name "xc7a35tcsg324-1"
# 项目顶层模块名
set top_level_name "main_module"

# 获取脚本所在的目录，用于构造相对路径
set script_dir [file dirname [info script]]
# 项目根目录 (脚本目录的上一级)
set root_dir [file dirname $script_dir]
# Vivado 工程生成目录
set proj_dir "$root_dir/vivado_proj"
# Vivado 日志目录
set logs_dir "$root_dir/logs"

# 创建logs目录（如果不存在）
if { ![file isdirectory $logs_dir] } {
    file mkdir $logs_dir
    puts "INFO: Created logs directory: $logs_dir"
}

puts "INFO: Project will be created in: $proj_dir"
puts "INFO: Vivado logs will be saved in: $logs_dir"
puts "INFO: Current working directory: [pwd]"


# --- 2. 创建工程 ---
# 如果工程目录已存在，先删除，确保每次都是全新创建
if { [file isdirectory $proj_dir] } {
    puts "INFO: Deleting existing project directory: $proj_dir"
    file delete -force $proj_dir
}
puts "INFO: Creating project '$proj_name' in directory: $proj_dir"
create_project $proj_name $proj_dir -part $part_name


# --- 3. 添加源文件 ---
puts "INFO: Adding RTL source files..."

# 设置模块目录
set modules_dir "$root_dir/modules"

# 分别处理设计文件和仿真文件
set design_verilog_files {}
set sim_verilog_files {}
set design_vhdl_files {}
set sim_vhdl_files {}

# 递归搜索所有 Verilog/SystemVerilog 文件 (.v 和 .sv)
set all_verilog_files [find_files_recursively_multi $modules_dir {v sv}]
foreach file $all_verilog_files {
    # 检查文件路径是否包含 /sim/ 目录
    if { [string match "*/sim/*" $file] } {
        lappend sim_verilog_files $file
    } else {
        lappend design_verilog_files $file
    }
}

# 添加设计文件到 sources_1
if { [llength $design_verilog_files] > 0 } {
    add_files $design_verilog_files
    puts "INFO: Added [llength $design_verilog_files] design Verilog/SystemVerilog files to sources_1:"
    foreach file $design_verilog_files {
        puts "  - [file tail $file] (from [file dirname $file])"
    }
} else {
    puts "WARNING: No design Verilog/SystemVerilog (.v/.sv) files found in modules directory"
}

# 添加仿真文件到 sim_1
if { [llength $sim_verilog_files] > 0 } {
    add_files -fileset sim_1 $sim_verilog_files
    puts "INFO: Added [llength $sim_verilog_files] simulation Verilog/SystemVerilog files to sim_1:"
    foreach file $sim_verilog_files {
        puts "  - [file tail $file] (from [file dirname $file])"
    }
} else {
    puts "INFO: No simulation Verilog/SystemVerilog (.v/.sv) files found in sim directories"
}

# 递归搜索所有 VHDL 文件 (.vhd)
set all_vhdl_files [find_files_recursively $modules_dir "vhd"]
foreach file $all_vhdl_files {
    # 检查文件路径是否包含 /sim/ 目录
    if { [string match "*/sim/*" $file] } {
        lappend sim_vhdl_files $file
    } else {
        lappend design_vhdl_files $file
    }
}

# 添加设计 VHDL 文件到 sources_1
if { [llength $design_vhdl_files] > 0 } {
    add_files $design_vhdl_files
    puts "INFO: Added [llength $design_vhdl_files] design VHDL files to sources_1:"
    foreach file $design_vhdl_files {
        puts "  - [file tail $file] (from [file dirname $file])"
    }
} else {
    puts "INFO: No design VHDL (.vhd) files found in modules directory"
}

# 添加仿真 VHDL 文件到 sim_1
if { [llength $sim_vhdl_files] > 0 } {
    add_files -fileset sim_1 $sim_vhdl_files
    puts "INFO: Added [llength $sim_vhdl_files] simulation VHDL files to sim_1:"
    foreach file $sim_vhdl_files {
        puts "  - [file tail $file] (from [file dirname $file])"
    }
} else {
    puts "INFO: No simulation VHDL (.vhd) files found in sim directories"
}

# 设置 IP 核文件目录
set ip_dir "$root_dir/ip"

# 添加 IP 核 (.xci 文件)
puts "INFO: Adding IP core files..."
set ip_files [find_files_recursively $ip_dir "xci"]
if { [llength $ip_files] > 0 } {
    add_files $ip_files
    puts "INFO: Added [llength $ip_files] IP core files:"
    foreach file $ip_files {
        puts "  - [file tail $file] (from [file dirname $file])"
    }
} else {
    puts "INFO: No IP core (.xci) files found in modules directory"
}

# 添加 Block Design (.bd 文件)
puts "INFO: Adding Block Design files..."
set bd_files [find_files_recursively $modules_dir "bd"]
if { [llength $bd_files] > 0 } {
    add_files $bd_files
    puts "INFO: Added [llength $bd_files] Block Design files:"
    foreach file $bd_files {
        puts "  - [file tail $file] (from [file dirname $file])"
    }
} else {
    puts "INFO: No Block Design (.bd) files found in modules directory"
}


# --- 4. 添加约束文件 ---
puts "INFO: Adding constraint files..."
set constraint_files [glob -nocomplain "$root_dir/constraints/*.xdc"]
if { [llength $constraint_files] > 0 } {
    add_files -fileset constrs_1 $constraint_files
    puts "INFO: Added [llength $constraint_files] constraint files:"
    foreach file $constraint_files {
        puts "  - [file tail $file]"
    }
} else {
    puts "WARNING: No constraint (.xdc) files found in constraints directory"
}


# --- 5. 设置工程属性 ---
# 设置顶层模块
set_property top $top_level_name [current_fileset]
# 更新文件层级
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: Project creation complete."
puts "INFO: Log files are automatically saved in the current directory (logs/)"
puts "INFO: You can now open the project using Vivado GUI:"
puts "vivado $proj_dir/$proj_name.xpr"

# 脚本自动打开 GUI
start_gui
