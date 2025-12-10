# Matrix Operation Executor (matrix_op_executor)

## 概述
`matrix_op_executor` 是矩阵计算器的核心执行控制模块。它负责接收 `matrix_op_selector` 的指令，协调并执行具体的矩阵运算（加法、乘法、标量乘法、转置），并将结果写入 BRAM。

## 功能特性
1.  **操作调度**：根据输入的 `op_type` 激活相应的运算子模块 (`matrix_op_add`, `matrix_op_mul`, `matrix_op_scalar_mul`, `matrix_op_T`)。
2.  **标量处理**：对于标量乘法 (`CALC_SCALAR_MUL`)，模块会自动将输入的立即数标量 (`scalar_in`) 写入到一个临时的 1x1 矩阵（默认 ID 为 7）中，然后再触发标量乘法模块。
3.  **接口复用**：复用 BRAM 读取接口和 `matrix_storage_manager` 的写入接口，根据当前激活的子模块进行信号路由。
4.  **状态管理**：提供 `busy` 和 `done` 信号，指示执行状态。

## 接口说明

| 信号名 | 方向 | 位宽 | 描述 |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | 系统时钟 |
| `rst_n` | Input | 1 | 异步复位（低有效） |
| `start` | Input | 1 | 开始信号（来自 selector） |
| `op_type` | Input | Enum | 操作类型 (ADD, MUL, SCALAR_MUL, TRANSPOSE) |
| `matrix_a` | Input | 3 | 矩阵 A 的 ID |
| `matrix_b` | Input | 3 | 矩阵 B 的 ID |
| `scalar_in` | Input | 32 | 标量值（用于标量乘法） |
| `busy` | Output | 1 | 忙碌信号 |
| `done` | Output | 1 | 完成信号 |
| `bram_read_addr` | Output | ADDR_WIDTH | BRAM 读取地址 |
| `bram_data_out` | Input | DATA_WIDTH | BRAM 读取数据 |
| `write_request` | Output | 1 | 写请求信号 |
| `write_ready` | Input | 1 | 写就绪信号（来自 storage manager） |
| `write_matrix_id` | Output | 3 | 写入的目标矩阵 ID |
| `write_rows` | Output | 8 | 写入矩阵的行数 |
| `write_cols` | Output | 8 | 写入矩阵的列数 |
| `write_name` | Output | 8x8 | 写入矩阵的名称 |
| `write_data` | Output | DATA_WIDTH | 写入数据 |
| `write_data_valid` | Output | 1 | 写入数据有效信号 |
| `writer_ready` | Input | 1 | 写入器就绪信号 |
| `write_done` | Input | 1 | 写入完成信号 |

## 内部流程

### 1. 标量乘法流程
如果操作类型是 `CALC_SCALAR_MUL`：
1.  状态机进入 `STATE_PREPARE_SCALAR_REQ`。
2.  等待 `write_ready`，然后发送写请求，目标为 `SCALAR_TEMP_ID` (默认 7)，大小 1x1，名称 "SCALAR"。
3.  等待 `writer_ready`，发送 `scalar_in` 数据。
4.  等待 `write_done`。
5.  状态机进入 `STATE_EXECUTE_START`，触发 `matrix_op_scalar_mul` 子模块，源矩阵为 `matrix_a`，标量矩阵为 `SCALAR_TEMP_ID`。

### 2. 普通运算流程
对于其他操作（加法、乘法、转置）：
1.  状态机直接进入 `STATE_EXECUTE_START`。
2.  根据 `op_type` 拉高对应子模块的 `start` 信号。
3.  进入 `STATE_EXECUTE_WAIT`，等待子模块完成（通过监控子模块状态或忙碌信号）。
4.  完成后拉高 `done` 信号。

## 参数配置
*   `BLOCK_SIZE`: 矩阵块大小 (默认 1152)
*   `ADDR_WIDTH`: 地址位宽 (默认 14)
*   `DATA_WIDTH`: 数据位宽 (默认 32)
*   `SCALAR_TEMP_ID`: 用于存储临时标量的矩阵 ID (默认 7)
