# Matrix Info Reader 模块设计文档

## 1. 概述

`matrix_info_reader` 模块负责扫描 BRAM 中存储的所有矩阵，统计有效矩阵的总数以及每种规格（行x列）的矩阵数量，并以格式化的 ASCII 文本流输出。

## 2. 功能特性

- **全量扫描**：自动扫描所有 8 个矩阵槽位 (ID 0-7)。
- **智能统计**：自动识别有效矩阵（行数和列数均大于 0），并对相同规格的矩阵进行归类统计。
- **格式化输出**：输出格式符合以下规范：
  ```
  Total R1*C1*Count1 R2*C2*Count2 ...
  ```
  示例：`3 2*2*1 4*5*2` 表示共有 3 个矩阵，其中 1 个 2x2 矩阵，2 个 4x5 矩阵。
- **流式接口**：输出采用 `valid/ready` 握手协议。

## 3. 接口定义

| 信号名 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `clk` | Input | 1 | 系统时钟 |
| `rst_n` | Input | 1 | 异步复位，低电平有效 |
| `start` | Input | 1 | 启动统计信号（脉冲） |
| `busy` | Output | 1 | 模块忙标志 |
| `done` | Output | 1 | 统计完成标志（脉冲） |
| `bram_addr` | Output | 14 | BRAM 读地址 |
| `bram_data` | Input | 32 | BRAM 读数据 |
| `ascii_data` | Output | 8 | ASCII 字符输出 |
| `ascii_valid` | Output | 1 | ASCII 数据有效 |
| `ascii_ready` | Input | 1 | 下游接收就绪 |

## 4. 内部架构

模块主要由状态机和 `ascii_num_pack` 子模块组成。

### 4.1 状态机流程

1.  **SCAN_LOOP**: 遍历 ID 0-7，读取每个矩阵的元数据（行数、列数）。
2.  **CALC_TOTAL**: 统计有效矩阵的总数。
3.  **SEND_TOTAL**: 输出总数。
4.  **STATS_LOOP**: 再次遍历 ID 0-7，对未处理的有效矩阵进行统计。
    - **CHECK_CURRENT**: 检查当前 ID 是否有效且未处理。
    - **COUNT_MATCHES**: 扫描后续 ID，查找具有相同规格的矩阵，并计数。
    - **SEND_STATS**: 输出 `R*C*Count` 格式的统计信息。
    - **MARK_PROCESSED**: 标记已统计的矩阵，避免重复输出。
5.  **DONE**: 完成操作。

### 4.2 内部存储

- `dims [0:7]`: 存储 8 个矩阵的规格信息 `{rows, cols}`。
- `valid_mask`: 标记哪些 ID 存储了有效矩阵。
- `processed_mask`: 标记哪些 ID 已经被统计输出过。

## 5. 仿真验证

模块已通过 `matrix_info_reader_tb` 进行验证，覆盖了以下场景：
- 混合规格矩阵统计（2x2, 4x5, 3x3）。
- 空槽位处理。
- 多个相同规格矩阵的正确计数。
- 输出格式验证。
