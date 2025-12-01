# Settings RAM 模块使用说明

## 模块概述

`settings_ram` 是一个简易的设置保存模块，用于存储矩阵运算相关的配置参数。该模块提供寄存器存储功能，支持读写操作。

## 端口说明

### 输入端口

| 端口名 | 位宽 | 说明 |
|--------|------|------|
| `clk` | 1 | 系统时钟 |
| `rst_n` | 1 | 异步复位信号（低电平有效） |
| `wr_en` | 1 | 写使能信号（高电平有效） |
| `set_max_row` | 32 | 要设置的最大行数 |
| `set_max_col` | 32 | 要设置的最大列数 |
| `data_min` | 32 | 要设置的数据最小值 |
| `data_max` | 32 | 要设置的数据最大值 |

### 输出端口

| 端口名 | 位宽 | 说明 |
|--------|------|------|
| `rd_max_row` | 32 | 读取的最大行数 |
| `rd_max_col` | 32 | 读取的最大列数 |
| `rd_data_min` | 32 | 读取的数据最小值 |
| `rd_data_max` | 32 | 读取的数据最大值 |

## 功能说明

### 1. 复位行为

当 `rst_n` 为低电平时，所有设置恢复为默认值：
- 最大行数：5
- 最大列数：5
- 数据最小值：1
- 数据最大值：9

### 2. 写入操作

- 当 `wr_en = 1` 时，在时钟上升沿更新内部寄存器
- 输入的设置值会被保存到对应的寄存器中
- 写入后的值立即体现在输出端口上

### 3. 读取操作

- 输出端口持续输出当前保存的设置值
- 无需额外的读使能信号
- 读取为组合逻辑，无延迟

## 使用示例

```systemverilog
// 实例化模块
settings_ram u_settings_ram (
    .clk          (clk),
    .rst_n        (rst_n),
    .wr_en        (settings_wr_en),
    .set_max_row  (new_max_row),
    .set_max_col  (new_max_col),
    .data_min     (new_data_min),
    .data_max     (new_data_max),
    .rd_max_row   (current_max_row),
    .rd_max_col   (current_max_col),
    .rd_data_min  (current_data_min),
    .rd_data_max  (current_data_max)
);

// 写入新设置
always_ff @(posedge clk) begin
    if (need_update_settings) begin
        settings_wr_en <= 1'b1;
        new_max_row    <= 32'd8;
        new_max_col    <= 32'd8;
        new_data_min   <= 32'd0;
        new_data_max   <= 32'd255;
    end else begin
        settings_wr_en <= 1'b0;
    end
end

// 随时读取当前设置
assign matrix_rows = current_max_row;
assign matrix_cols = current_max_col;
```

## 注意事项

1. **写入时序**：写入操作在时钟上升沿完成，确保 `wr_en` 和输入数据在时钟上升沿稳定
2. **复位优先**：复位信号优先级最高，复位期间忽略写入操作
3. **数据有效性**：模块不检查输入数据的合法性，由上层模块保证数据有效
4. **读取延迟**：读取为组合逻辑输出，无延迟，但建议在时钟域同步后使用
