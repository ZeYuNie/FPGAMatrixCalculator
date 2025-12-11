# Matrix Operation Selector (matrix_op_selector)

## 概述
`matrix_op_selector` 是矩阵计算器的用户交互与操作选择模块。它负责引导用户通过 UART 终端输入矩阵维度、选择源矩阵、输入标量，并验证用户的选择是否符合当前操作模式的要求。最终，它将验证通过的操作参数传递给 `matrix_op_executor` 执行。

## 功能特性
1.  **用户引导**：通过 UART 发送提示信息，引导用户逐步完成操作配置。
2.  **输入解析**：集成 `ascii_num_sep_top` 模块，解析用户通过 UART 输入的数字（维度、矩阵 ID、标量值）。
3.  **矩阵扫描**：集成 `matrix_scanner` 模块，扫描 BRAM 中符合指定维度（m x n）的有效矩阵，并生成掩码。
4.  **矩阵预览**：集成 `matrix_reader` 模块，在用户选择过程中通过 UART 打印矩阵内容，辅助用户决策。
5.  **随机选择**：支持随机选择矩阵和标量，用于测试或演示。
6.  **参数验证**：根据操作类型（加法、乘法、卷积等）验证用户选择的矩阵维度是否合法。
    *   乘法：验证 A 的列数是否等于 B 的行数（在当前设计中，由于筛选了相同维度的矩阵，隐含要求 m=n，即方阵）。
    *   卷积：验证源矩阵是否为 3x3。
7.  **超时与错误处理**：集成倒计时器，在用户无操作或输入错误时进行提示和复位。

## 接口说明

| 信号名 | 方向 | 位宽 | 描述 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | 系统时钟 |
| `rst_n` | Input | 1 | 异步复位（低有效） |
| `start` | Input | 1 | 模块启动信号（通常来自按键或上层控制） |
| `confirm_btn` | Input | 1 | 确认按钮，用于推进状态机 |
| `scalar_in` | Input | 32 | 外部输入的标量值（如来自拨码开关） |
| `random_scalar` | Input | 1 | 是否使用随机标量 |
| `op_mode_in` | Input | Enum | 操作模式 (SINGLE, DOUBLE, SCALAR) |
| `calc_type_in` | Input | Enum | 具体计算类型 (ADD, MUL, CONV, etc.) |
| `countdown_time_in` | Input | 32 | 倒计时初始值 |
| `uart_rx_data` | Input | 8 | UART 接收数据 |
| `uart_rx_valid` | Input | 1 | UART 接收数据有效 |
| `uart_tx_data` | Output | 8 | UART 发送数据 |
| `uart_tx_valid` | Output | 1 | UART 发送数据有效 |
| `uart_tx_ready` | Input | 1 | UART 发送就绪 |
| `bram_addr` | Output | ADDR_WIDTH | BRAM 读取地址（用于扫描和预览） |
| `bram_data` | Input | 32 | BRAM 读取数据 |
| `result_valid` | Output | 1 | 选择完成，结果有效 |
| `result_op` | Output | Enum | 最终确定的计算类型 |
| `result_matrix_a` | Output | 3 | 选定的矩阵 A ID |
| `result_matrix_b` | Output | 3 | 选定的矩阵 B ID |
| `result_scalar` | Output | 32 | 选定的标量值 |

## 状态机流程

1.  **IDLE**: 等待 `start` 信号。
2.  **GET_DIMS**: 等待用户输入矩阵维度 (m, n)。
3.  **SCAN_MATRICES**: 扫描 BRAM 中所有 m x n 的矩阵。
4.  **DISPLAY_LIST**: 列出所有符合条件的矩阵，并通过 UART 打印预览。
5.  **SELECT_A**: 等待用户输入矩阵 A 的 ID。支持输入 `-1` 进行随机选择。
6.  **CHECK_MODE**: 根据 `op_mode_in` 判断后续流程：
    *   `OP_SINGLE` (如转置、卷积): 直接进入验证。
    *   `OP_DOUBLE` (如加法、乘法): 进入 `SELECT_B`。
    *   `OP_SCALAR` (如标量乘法): 进入 `SELECT_SCALAR`。
7.  **SELECT_B**: 等待用户输入矩阵 B 的 ID。
8.  **SELECT_SCALAR**: 等待用户确认标量值（来自开关或随机）。
9.  **VALIDATE**: 验证选择的参数是否符合 `calc_type_in` 的数学要求。
    *   例如：卷积操作要求输入矩阵必须为 3x3。
10. **DONE**: 输出有效结果，随后返回 IDLE。

## 参数配置
*   `BLOCK_SIZE`: 矩阵块大小 (默认 1152)
*   `ADDR_WIDTH`: 地址位宽 (默认 14)
