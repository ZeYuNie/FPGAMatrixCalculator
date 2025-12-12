# Compute Subsystem (计算子系统)

## 1. 概述

`compute_subsystem` 是 FPGA 矩阵计算器的核心处理单元，负责协调用户交互、指令解析、矩阵运算调度以及结果存储。它集成了输入缓冲 (`ascii_num_sep_top`)、运算选择 (`matrix_op_selector`) 和运算执行 (`matrix_op_executor`) 三大功能模块，通过统一的接口与外部存储 (`BRAM`) 和用户终端 (`UART`) 进行通信。

## 2. 架构设计

### 2.1 模块组成

1.  **`ascii_num_sep_top` (输入缓冲层)**:
    *   **功能**: 接收 UART 原始字节流，识别数字分隔符（空格、换行），将其解析为整数并存入 FIFO。
    *   **作用**: 解耦 UART 传输速率与内部处理逻辑，支持用户快速输入（Type-ahead）。

2.  **`matrix_op_selector` (控制与选择层)**:
    *   **功能**: 驱动用户交互流程。它负责提示用户输入矩阵维度、扫描 BRAM 中符合条件的矩阵、显示矩阵列表、并引导用户选择操作数（矩阵 ID 或标量值）。
    *   **特性**: 包含状态机以管理复杂的交互步骤，并具备超时处理和错误反馈机制。

3.  **`matrix_op_executor` (执行层)**:
    *   **功能**: 接收经过验证的运算指令，调度底层的运算加速器（如矩阵加法器、乘法器、脉动阵列等）。
    *   **特性**: 负责从 BRAM 读取源数据，计算结果，并通过标准化的写接口将结果回写到存储管理器。

### 2.2 内部数据流

1.  **选择阶段**: UART RX -> 输入缓冲 -> 选择器 -> (读取 BRAM 扫描/预览) -> UART TX (提示/回显)。
2.  **执行阶段**: 选择器 (指令) -> 执行器 -> (读取 BRAM 操作数) -> 运算单元 -> (写请求) -> 存储管理器。

## 3. 接口说明

### 3.1 系统与控制
| 信号名 | 方向 | 描述 |
| :--- | :--- | :--- |
| `clk` | Input | 系统时钟 (100MHz) |
| `rst_n` | Input | 异步复位 (低电平有效) |
| `start` | Input | 启动脉冲，触发一次新的计算流程 |
| `confirm_btn` | Input | 确认按钮，用于推进交互步骤 (如确认维度、确认选择) |
| `op_mode_in` | Input | 运算模式: `OP_SINGLE` (单目), `OP_DOUBLE` (双目), `OP_SCALAR` (标量) |
| `calc_type_in` | Input | 具体运算类型: `CALC_ADD`, `CALC_MUL`, `CALC_TRANSPOSE` 等 |

### 3.2 UART 交互
| 信号名 | 方向 | 描述 |
| :--- | :--- | :--- |
| `uart_rx_data` | Input | 接收到的 ASCII 字符 |
| `uart_rx_valid` | Input | 接收数据有效指示 |
| `uart_tx_data` | Output | 发送给终端的 ASCII 字符 |
| `uart_tx_valid` | Output | 发送数据有效指示 |
| `uart_tx_ready` | Input | 终端/UART 发送模块准备好接收指示 |

### 3.3 存储访问 (BRAM)
| 信号名 | 方向 | 描述 |
| :--- | :--- | :--- |
| `bram_rd_addr` | Output | 读地址 (14-bit)，用于扫描或读取操作数 |
| `bram_rd_data` | Input | 读数据 (32-bit) |
| `write_request` | Output | 写请求信号，高电平有效 |
| `write_ready` | Input | 存储管理器准备好接收写请求 |
| `write_done` | Input | 存储管理器完成写入的握手信号 |
| `write_data...` | Output | 包含 `write_matrix_id`, `write_rows`, `write_cols`, `write_data` 等 |

## 4. 使用指南与操作流程

### 4.1 典型操作序列 (以矩阵加法为例)

1.  **配置模式**: 设置 `op_mode_in = OP_DOUBLE`, `calc_type_in = CALC_ADD`。
2.  **启动**: 发送 `start` 脉冲。
3.  **输入维度**:
    *   用户通过 UART 输入目标矩阵维度，例如 `"3 3\n"` (3行3列)。
    *   按下 `confirm_btn`。
4.  **选择矩阵 A**:
    *   系统扫描 BRAM，列出所有 3x3 矩阵。
    *   用户输入矩阵 ID，例如 `"0\n"`。
    *   按下 `confirm_btn`。
5.  **选择矩阵 B**:
    *   系统提示选择第二个矩阵。
    *   用户输入矩阵 ID，例如 `"1\n"`。
    *   按下 `confirm_btn`。
6.  **执行与完成**:
    *   系统自动验证维度匹配性。
    *   执行加法运算。
    *   `done` 信号拉高，表示完成。

### 4.2 输入格式规范
*   **数字**: 支持十进制整数输入。
*   **分隔符**: 支持空格 (`0x20`) 和换行 (`0x0A`, `0x0D`)。
*   **负数**: 支持负号 (`-`)，例如输入 `-1` 可触发随机选择功能（如果启用）。

## 5. 集成注意事项 (Pitfalls & Best Practices)

### 5.1 写请求处理 (Critical)
`matrix_op_executor` 在计算完成后会发起写请求。集成时必须确保外部存储管理器正确响应握手协议：
1.  子系统拉高 `write_request`。
2.  外部模块在准备好后拉低 `write_ready` (可选，视具体握手协议而定) 并开始接收数据。
3.  **必须** 在写入完成后回送一个 `write_done` 脉冲。
4.  **警告**: 如果外部不产生 `write_done`，执行器将无限期挂起，导致 `done` 信号永远无法拉高。

### 5.2 输入缓冲与 Type-ahead
*   子系统支持“预输入”（Type-ahead）。例如，用户可以一次性发送 `"3 3\n0\n1\n"`，系统会依次处理维度、矩阵A ID 和矩阵B ID。
*   **注意**: 在状态机切换（如从 `CHECK_MODE` 到 `SELECT_B`）时，系统**不会**清除输入缓冲区，以保留用户的预输入数据。这意味着如果之前的操作留下了垃圾数据，可能会影响后续步骤。建议在 `start` 时刻确保缓冲区清空（系统已在 `IDLE` -> `SELECTING` 转换时自动处理）。

### 5.3 BRAM 初始化格式
为了使 `matrix_op_selector` 能正确扫描矩阵，BRAM 中的矩阵必须遵循特定的头部格式：
*   **地址偏移 0**: `{Rows[7:0], Cols[7:0], 16'b0}`
*   **地址偏移 1**: 矩阵名称 Part 1 (ASCII)
*   **地址偏移 2**: 矩阵名称 Part 2 (ASCII)
*   **地址偏移 3+**: 矩阵数据
*   **警告**: 如果头部格式不正确（例如 Rows/Cols 为 0），扫描器将忽略该矩阵。

### 5.4 仿真调试
*   在 Testbench 中，建议使用 `wait(dut.state == STATE_XXX)` 来同步测试步骤，而不是仅依赖固定的延时。
*   确保 Mock BRAM 的初始化数据符合上述 5.3 的格式要求。
