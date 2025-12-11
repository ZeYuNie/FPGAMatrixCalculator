# Main Module (主模块)

## 1. 项目概述

`main_module` 是 FPGA 矩阵计算器的顶层模块，负责集成所有功能子系统、管理物理 I/O 接口以及协调系统级的资源共享。

## 2. 系统架构

系统采用分层模块化设计，主要包含以下层级：

1.  **顶层 (Top Level)**: `main_module.v`
    *   负责物理引脚映射 (UART, Switches, LEDs, Buttons)。
    *   实例化 `system_top`。

2.  **系统集成层 (System Integration)**: `system_top.sv`
    *   核心集成逻辑。
    *   实例化中央存储 (`matrix_storage_manager`)。
    *   实例化功能子系统 (`input_subsystem`, `compute_subsystem`, `display_subsystem`)。
    *   实现 BRAM 和 UART 的资源仲裁。
    *   [详细文档: system_top.md](./system_top.md)

3.  **子系统层 (Subsystems)**:
    *   **Input Subsystem**: 处理矩阵输入、生成和设置。
        *   [详细文档: input_subsystem.md](./input_subsystem.md)
    *   **Compute Subsystem**: 处理矩阵运算 (选择 + 执行)。
        *   [详细文档: compute_subsystem.md](./compute_subsystem.md)
    *   **Display Subsystem**: 处理矩阵展示。

## 3. 目录结构

*   `src/`: 源代码文件
    *   `main_module.v`: 顶层模块
    *   `system_top.sv`: 系统集成模块
    *   `input_subsystem.sv`: 输入子系统
    *   `compute_subsystem.sv`: 计算子系统
*   `sim/`: 仿真文件
    *   `main_module_tb.sv`: 顶层测试平台
    *   `input_subsystem_tb.sv`: 输入子系统测试平台
    *   `compute_subsystem_tb.sv`: 计算子系统测试平台
*   `docs/`: 文档
    *   `system_top.md`: 系统集成文档
    *   `input_subsystem.md`: 输入子系统文档
    *   `compute_subsystem.md`: 计算子系统文档

## 4. 快速开始

### 4.1 仿真
运行 `sim/main_module_tb.sv` 可验证顶层连接和基本模式切换。
运行子系统 TB (如 `input_subsystem_tb.sv`) 可验证特定功能的详细逻辑。

### 4.2 综合与实现
将 `main_module.v` 设置为 Top Module，并确保所有子模块路径已包含在工程中。
注意检查 `constraints/` 中的引脚约束是否与开发板匹配。
