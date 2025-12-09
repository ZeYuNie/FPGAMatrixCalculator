# Matrix Reader All 模块设计文档

## 1. 概述

`matrix_reader_all` 模块是 `matrix_reader` 的上层封装，用于一次性读取并输出所有存储的有效矩阵的详细内容。它自动遍历所有矩阵槽位，跳过空矩阵，并在每个矩阵输出之间插入分隔符。

## 2. 功能特性

- **全量导出**：自动遍历 ID 0-7，导出所有有效矩阵。
- **自动过滤**：自动跳过无效（行或列为 0）的矩阵槽位。
- **格式化输出**：
  - 每个矩阵的输出格式与 `matrix_reader` 一致。
  - 矩阵之间插入两个换行符 (`\n\n`) 作为分隔。
- **流式接口**：输出采用 `valid/ready` 握手协议。

## 3. 接口定义

| 信号名 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `clk` | Input | 1 | 系统时钟 |
| `rst_n` | Input | 1 | 异步复位，低电平有效 |
| `start` | Input | 1 | 启动导出信号（脉冲） |
| `busy` | Output | 1 | 模块忙标志 |
| `done` | Output | 1 | 导出完成标志（脉冲） |
| `bram_addr` | Output | 14 | BRAM 读地址 |
| `bram_data` | Input | 32 | BRAM 读数据 |
| `ascii_data` | Output | 8 | ASCII 字符输出 |
| `ascii_valid` | Output | 1 | ASCII 数据有效 |
| `ascii_ready` | Input | 1 | 下游接收就绪 |

## 4. 内部架构

模块主要由状态机和 `matrix_reader` 实例组成。

### 4.1 状态机流程

1.  **SCAN_LOOP**: 遍历 ID 0-7。
2.  **CHECK_VALID**: 读取当前 ID 的元数据，检查行数和列数是否大于 0。
3.  **START_READER**: 如果有效，启动内部的 `matrix_reader` 模块。
4.  **WAIT_READER**: 等待 `matrix_reader` 完成当前矩阵的输出。
5.  **SEND_SEP**: 发送两个换行符 (`\n\n`)。
6.  **NEXT_ID**: 继续处理下一个 ID。
7.  **DONE**: 完成操作。

### 4.2 资源复用

- **BRAM 接口**：模块内部对 `matrix_reader` 的 BRAM 地址和自身的检查地址进行多路复用。
- **ASCII 接口**：模块内部对 `matrix_reader` 的 ASCII 输出和自身生成的分隔符进行多路复用。

## 5. 仿真验证

模块已通过 `matrix_reader_all_tb` 进行验证，确认了：
- 正确输出所有有效矩阵。
- 正确跳过无效矩阵。
- 正确插入分隔符。
