# System Top (系统顶层集成)

## 1. 概述

`system_top` 是 FPGA 矩阵计算器的核心集成模块。它负责实例化所有功能子系统 (`input_subsystem`, `compute_subsystem`, `display_subsystem`) 以及中央存储管理器 (`matrix_storage_manager`)，并实现它们之间的资源仲裁和信号路由。

## 2. 架构设计

系统采用分层架构，将功能相关的模块封装在子系统中，由 `system_top` 进行统一管理：

1.  **`matrix_storage_manager` (中央存储)**:
    *   系统的核心数据存储，提供统一的读写接口。
    *   所有子系统都通过 `system_top` 访问该存储。

2.  **`input_subsystem` (输入子系统)**:
    *   负责 Matrix Input, Generate, Settings 模式。
    *   管理全局输入缓冲区。

3.  **`compute_subsystem` (计算子系统)**:
    *   负责 Matrix Calculate 模式。
    *   包含选择和执行逻辑。

4.  **`display_subsystem` (显示子系统)**:
    *   负责 Matrix Show 模式。
    *   实例化 `matrix_reader_all`，遍历并打印所有矩阵。

## 3. 资源仲裁

`system_top` 实现了关键资源的仲裁逻辑，确保不同模式下的子系统能正确访问共享资源：

### 3.1 BRAM 写端口仲裁
*   **Input/Gen/Settings 模式**: 授权给 `input_subsystem`。
*   **Calc 模式**: 授权给 `compute_subsystem`。

### 3.2 BRAM 读端口仲裁
*   **Show 模式**: 授权给 `display_subsystem`。
*   **Calc 模式**: 授权给 `compute_subsystem`。
*   **Input/Gen 模式**: 授权给 `input_subsystem` (用于查找空闲槽位)。

### 3.3 UART TX 仲裁
*   **Show 模式**: 输出 `display_subsystem` 的数据。
*   **Calc 模式**: 输出 `compute_subsystem` 的数据。
*   **其他模式**: 保持静默。

## 4. 拨码开关映射

为了解决模式选择和运算类型选择的冲突，`system_top` 重新定义了 8 位拨码开关的映射：

*   **模式选择 (SW[7:3])**:
    *   `SW[7]`: Matrix Input Mode
    *   `SW[6]`: Matrix Generate Mode
    *   `SW[5]`: Matrix Show Mode
    *   `SW[4]`: Matrix Calculate Mode
    *   `SW[3]`: Settings Mode
*   **运算类型选择 (SW[2:0])**:
    *   仅在 Calculate Mode 下有效。
    *   `000`: Transpose
    *   `001`: Add
    *   `010`: Multiply
    *   `011`: Scalar Multiply
    *   ... (其他由 `op_mode_controller` 定义)

## 5. 物理接口映射

`system_top` 将逻辑信号映射到 `main_module` 的物理端口：
*   **LEDs**: 汇总各子系统的 `busy` 和 `error` 信号。
*   **Seg7**: 目前主要由 `compute_subsystem` 使用 (显示倒计时或状态)，其他模式下关闭。
