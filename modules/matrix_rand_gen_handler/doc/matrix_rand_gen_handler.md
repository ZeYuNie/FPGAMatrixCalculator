# Matrix Random Generation Handler 模块

## 功能概述

`matrix_rand_gen_handler` 模块用于根据用户指令生成随机矩阵。它从缓冲RAM（`num_storage_ram`）读取生成参数（维度和数量），利用 `xorshift32` 算法生成随机数据，并将生成的矩阵写入矩阵存储管理器（`matrix_storage_manager`）。

## 输入指令格式

缓冲RAM中的数据格式（每个元素为32位有符号整数）：
```
行数(m), 列数(n), 矩阵数量(count)
```

**说明**：
- `m`：矩阵行数
- `n`：矩阵列数
- `count`：需要生成的矩阵数量（不超过 2 个）

**示例**：
```
输入：1, 3, 2
表示：生成 2 个 1x3 的矩阵。
```

## 接口定义

### 控制信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | 输入 | 1 | 时钟信号 |
| `rst_n` | 输入 | 1 | 异步低电平复位 |
| `start` | 输入 | 1 | 启动信号（单周期脉冲） |
| `error` | 输出 | 1 | 错误标志，拉高后持续直到复位 |
| `busy` | 输出 | 1 | 忙标志，处理过程中为高 |
| `done` | 输出 | 1 | 完成标志 |

### Settings 接口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `settings_max_row` | 输入 | 32 | 最大允许行数 |
| `settings_max_col` | 输入 | 32 | 最大允许列数 |
| `settings_data_min` | 输入 | 32 | 数据最小值（有符号） |
| `settings_data_max` | 输入 | 32 | 数据最大值（有符号） |

### 缓冲RAM读接口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `buf_rd_addr` | 输出 | 11 | 缓冲RAM读地址 |
| `buf_rd_data` | 输入 | 32 | 缓冲RAM读数据（1周期延迟） |

### 矩阵存储管理器写接口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `write_request` | 输出 | 1 | 写请求信号 |
| `write_ready` | 输入 | 1 | 写就绪标志 |
| `matrix_id` | 输出 | 3 | 矩阵ID (1-7) |
| `actual_rows` | 输出 | 8 | 实际行数 |
| `actual_cols` | 输出 | 8 | 实际列数 |
| `matrix_name[0:7]` | 输出 | 8×8 | 矩阵名称（8字节），随机生成时设为全0 |
| `data_in` | 输出 | 32 | 写入数据 |
| `data_valid` | 输出 | 1 | 数据有效标志 |
| `write_done` | 输入 | 1 | 写完成标志 |
| `writer_ready` | 输入 | 1 | 写模块就绪标志 |

### 矩阵存储管理器读接口 (用于检测空闲槽位)

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `storage_rd_addr` | 输出 | 14 | 存储RAM读地址 |
| `storage_rd_data` | 输入 | 32 | 存储RAM读数据 |

## 状态机流程

1.  **IDLE**: 等待 `start` 信号。
2.  **READ_PARAMS**: 从缓冲RAM读取 `m`, `n`, `count`。
3.  **VALIDATE**: 验证参数：
    *   `m <= settings_max_row` 且 `m > 0`
    *   `n <= settings_max_col` 且 `n > 0`
    *   `count <= 2` 且 `count > 0`
    *   如果验证失败，跳转至 `ERROR_STATE`。
4.  **FIND_SLOT**: 查找空闲矩阵ID (1-7)。
    *   如果找不到空闲槽位，跳转至 `ERROR_STATE`。
5.  **INITIATE_WRITE**: 向 `matrix_storage_manager` 发起写请求。
6.  **GENERATE_STREAM**:
    *   利用 `xorshift32` 生成随机数。
    *   将随机数限制在 `settings_data_min` 和 `settings_data_max` 之间（取模或截断）。
    *   流式写入数据。
7.  **WAIT_WRITE_DONE**: 等待当前矩阵写入完成。
8.  **CHECK_MORE**: 检查是否已生成 `count` 个矩阵。
    *   如果还有剩余，跳转回 `FIND_SLOT`。
    *   如果完成，跳转至 `DONE_STATE`。
9.  **DONE_STATE**: 完成状态。
10. **ERROR_STATE**: 错误状态。

## 随机数生成

使用 `xorshift32` 模块。
- **种子 (Seed)**: 为了确保每次生成的矩阵不同，可以使用 `m + n + count + cycle_counter` 组合作为初始种子，或者让 `xorshift32` 持续运行，仅在需要时采样。
- **范围控制**: 生成的 32 位随机数需要映射到 `[settings_data_min, settings_data_max]` 范围内。
  - 简单映射：`data = (random % (max - min + 1)) + min`。注意处理负数取模的问题。

## 错误处理

以下情况触发错误：
1.  输入维度 `m` 或 `n` 超过 Settings 限制。
2.  输入数量 `count` 超过 2 或为 0。
3.  系统没有足够的空闲矩阵槽位。
