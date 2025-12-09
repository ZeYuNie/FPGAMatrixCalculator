# Matrix Reader 模块设计文档

## 1. 概述

`matrix_reader` 模块负责从 BRAM 中读取指定 ID 的矩阵数据，并将其转换为格式化的 ASCII 文本流输出。该模块主要用于将内部存储的矩阵数据导出到外部接口（如 UART）。

## 2. 功能特性

- **指定读取**：支持通过 `matrix_id` (0-7) 选择要读取的矩阵。
- **格式化输出**：输出格式符合以下规范：
  ```
  ID Name
  Rows Cols
  Data1 Data2 ...
  ...
  ```
- **流式接口**：输出采用 `valid/ready` 握手协议，支持背压。
- **自动解析**：自动解析 BRAM 头部存储的元数据（行数、列数、名称）。

## 3. 接口定义

| 信号名 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `clk` | Input | 1 | 系统时钟 |
| `rst_n` | Input | 1 | 异步复位，低电平有效 |
| `start` | Input | 1 | 启动读取信号（脉冲） |
| `matrix_id` | Input | 3 | 要读取的矩阵 ID (0-7) |
| `busy` | Output | 1 | 模块忙标志 |
| `done` | Output | 1 | 读取完成标志（脉冲） |
| `bram_addr` | Output | 14 | BRAM 读地址 |
| `bram_data` | Input | 32 | BRAM 读数据 |
| `ascii_data` | Output | 8 | ASCII 字符输出 |
| `ascii_valid` | Output | 1 | ASCII 数据有效 |
| `ascii_ready` | Input | 1 | 下游接收就绪 |

## 4. 内部架构

模块主要由状态机和 `ascii_num_pack` 子模块组成。

### 4.1 状态机流程

1.  **IDLE**: 等待 `start` 信号。
2.  **READ_META**: 读取 BRAM 前 3 个地址，获取行数、列数和矩阵名称。
3.  **SEND_HEADER**: 调用 `ascii_num_pack` 输出 ID 和名称。
4.  **SEND_DIMS**: 调用 `ascii_num_pack` 输出行数和列数。
5.  **READ_DATA_LOOP**: 循环读取矩阵数据。
6.  **SEND_DATA**: 调用 `ascii_num_pack` 输出矩阵元素，并根据位置插入空格或换行符。
7.  **DONE**: 完成操作。

### 4.2 ASCII 转换

模块内部实例化了 `ascii_num_pack`，用于处理数字到 ASCII 的转换以及控制字符（空格、换行）的生成。对于矩阵名称（存储为 ASCII 字符），模块使用了 `ascii_num_pack` 的 `TYPE_CHAR` 模式直接透传。

## 5. BRAM 存储格式假设

- **地址 0**: `{rows[7:0], cols[7:0], 16'b0}` (高位为 Rows)
- **地址 1**: Name Part 1 (4 chars, Big Endian)
- **地址 2**: Name Part 2 (4 chars, Big Endian)
- **地址 3+**: 矩阵数据（行优先存储）

## 6. 仿真验证

模块已通过 `matrix_reader_tb` 进行验证，覆盖了以下场景：
- 读取标准矩阵（2x2）。
- 读取非方阵（2x3）。
- 背压测试（下游随机反压）。
- 验证了输出格式的正确性。
