# 卷积运算模块 (matrix_op_conv)

## 概述

`matrix_op_conv` 是一个符合矩阵运算执行器接口标准的模块，用于执行卷积运算。它封装了 `conv_stat_wrapper`，负责从 BRAM 读取卷积核，启动卷积计算，并将结果写回 BRAM。

## 功能特性

1.  **BRAM 接口**：符合 `matrix_op_executor` 的标准接口，支持从 BRAM 读取和写入。
2.  **卷积核读取**：自动从源矩阵地址读取 3x3 卷积核。
3.  **维度检查**：检查源矩阵是否为 3x3，如果不是则报错。
4.  **结果写入**：将 8x10 的卷积结果写入目标矩阵（通常是 Ans 矩阵）。

## 接口定义

| 信号名 | 方向 | 位宽 | 描述 |
|---|---|---|---|
| `clk` | Input | 1 | 时钟信号 |
| `rst_n` | Input | 1 | 复位信号 |
| `start` | Input | 1 | 启动信号 |
| `matrix_src_id` | Input | 3 | 源矩阵 ID |
| `busy` | Output | 1 | 忙信号 |
| `status` | Output | 4 | 状态信号 |
| `read_addr` | Output | ADDR_WIDTH | BRAM 读取地址 |
| `data_out` | Input | DATA_WIDTH | BRAM 读取数据 |
| `write_request` | Output | 1 | 写入请求 |
| `write_ready` | Input | 1 | 写入允许 |
| `matrix_id` | Output | 3 | 写入矩阵 ID |
| `actual_rows` | Output | 8 | 写入矩阵行数 (8) |
| `actual_cols` | Output | 8 | 写入矩阵列数 (10) |
| `matrix_name` | Output | 8x8 | 写入矩阵名称 ("CONV_RES") |
| `data_in` | Output | DATA_WIDTH | 写入数据 |
| `data_valid` | Output | 1 | 数据有效 |
| `writer_ready` | Input | 1 | 写入器就绪 |
| `write_done` | Input | 1 | 写入完成 |

## 状态机

1.  **IDLE**: 等待启动信号。
2.  **READ_METADATA**: 读取源矩阵的元数据（行数和列数）。
3.  **CHECK_DIMENSIONS**: 检查源矩阵是否为 3x3。
4.  **READ_KERNEL**: 逐个读取 9 个卷积核元素。
5.  **EXECUTE**: 启动 `conv_stat_wrapper`。
6.  **REQ_WRITE**: 请求写入权限。
7.  **WRITE_DATA**: 逐个写入 80 个结果元素。
8.  **DONE**: 完成。
