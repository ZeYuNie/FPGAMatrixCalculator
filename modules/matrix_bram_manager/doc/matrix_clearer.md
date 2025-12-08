# Matrix Clearer 模块使用说明

## 模块概述

`matrix_clearer` 是矩阵元数据清除模块，用于将指定矩阵的元数据清零。该模块通过向 BRAM 的前 3 个地址写入全 0 来清除矩阵的行数、列数和名称信息，从而将矩阵槽位标记为空闲状态。

## 功能特性

- 快速清除矩阵元数据（仅需 3 个写周期）
- 支持清除任意矩阵 ID（0-7）
- 简单的请求-完成握手接口
- 自动计算目标矩阵的基地址

## 参数

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `BLOCK_SIZE` | 1152 | 每个矩阵块大小 |
| `DATA_WIDTH` | 32 | 数据位宽 |
| `ADDR_WIDTH` | 14 | 地址位宽 |

## 接口定义

### 控制信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` | 输入 | 1 | 时钟信号 |
| `rst_n` | 输入 | 1 | 异步低电平复位 |
| `clear_request` | 输入 | 1 | 清除请求信号 |
| `clear_ready` | 输出 | 1 | 清除就绪标志 |
| `matrix_id` | 输入 | 3 | 要清除的矩阵 ID (0-7) |
| `clear_done` | 输出 | 1 | 清除完成标志（单周期脉冲） |

### BRAM 接口

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `bram_wr_en` | 输出 | 1 | BRAM 写使能 |
| `bram_addr` | 输出 | ADDR_WIDTH | BRAM 写地址 |
| `bram_din` | 输出 | DATA_WIDTH | BRAM 写数据（始终为 0） |

## 工作原理

### 清除流程

1. `clear_ready` 为高时，模块处于空闲状态，可接受清除请求
2. 检测到 `clear_request` 拉高，模块开始清除操作
3. 依次写入 3 个地址的元数据：
   - 地址 0: `32'h00000000` (rows=0, cols=0, 16'b0)
   - 地址 1: `32'h00000000` (name[0:3]=0)
   - 地址 2: `32'h00000000` (name[4:7]=0)
4. 完成后拉高 `clear_done` 一个周期
5. 返回空闲状态

### 状态机

```
IDLE → CLEAR_META_0 → CLEAR_META_1 → CLEAR_META_2 → DONE → IDLE
```

| 状态 | 说明 |
|------|------|
| `IDLE` | 空闲状态，等待清除请求 |
| `CLEAR_META_0` | 清除地址 0（行列信息） |
| `CLEAR_META_1` | 清除地址 1（名称前半部分） |
| `CLEAR_META_2` | 清除地址 2（名称后半部分） |
| `DONE` | 清除完成，拉高 clear_done |

## 地址计算

模块使用 `matrix_address_getter` 子模块计算基地址：

| 矩阵 ID | 基地址 | 计算方式 |
|---------|--------|----------|
| 0 | 0 | 0 × 1152 |
| 1 | 1152 | 1 × 1152 |
| 2 | 2304 | 2 × 1152 |
| 3 | 3456 | 3 × 1152 |
| 4 | 4608 | 4 × 1152 |
| 5 | 5760 | 5 × 1152 |
| 6 | 6912 | 6 × 1152 |
| 7 | 8064 | 7 × 1152 |

## 使用示例

```systemverilog
// 实例化 matrix_clearer
matrix_clearer #(
    .BLOCK_SIZE(1152),
    .DATA_WIDTH(32),
    .ADDR_WIDTH(14)
) clearer_inst (
    .clk(clk),
    .rst_n(rst_n),
    .clear_request(clear_req),
    .clear_ready(clear_rdy),
    .matrix_id(clear_id),
    .clear_done(clear_complete),
    .bram_wr_en(bram_wr),
    .bram_addr(bram_addr),
    .bram_din(bram_data)
);

// 清除矩阵 ID=3
initial begin
    clear_id = 3'd3;
    
    // 等待就绪
    wait(clear_rdy);
    
    // 发起清除请求
    @(posedge clk);
    clear_req <= 1'b1;
    @(posedge clk);
    clear_req <= 1'b0;
    
    // 等待完成
    wait(clear_complete);
    $display("Matrix 3 cleared");
end
```

## 时序特性

| 特性 | 周期数 |
|------|--------|
| 清除延迟 | 4 个时钟周期 |
| 状态 IDLE→DONE | 4 cycles |
| 完成脉冲宽度 | 1 cycle |

## 典型应用场景

1. **错误恢复**：当矩阵输入/计算出错时，清除无效数据
2. **矩阵删除**：用户主动删除不需要的矩阵
3. **空间回收**：释放不再使用的矩阵槽位
4. **数据验证失败**：输入数据不符合要求时清除

## 与其他模块的集成

### 在 matrix_storage_manager 中的使用

```systemverilog
module matrix_storage_manager (
    // ... 其他端口
    input  logic        clear_request,
    output logic        clear_done,
    input  logic [2:0]  clear_matrix_id
);
    // 实例化 clearer
    matrix_clearer clearer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .clear_request(clear_request),
        .matrix_id(clear_matrix_id),
        .clear_done(clear_done),
        // 连接到 BRAM
        .bram_wr_en(clearer_bram_wr_en),
        .bram_addr(clearer_bram_addr),
        .bram_din(clearer_bram_din)
    );
    
    // BRAM 仲裁：清除优先级高于写入
    always_comb begin
        if (clearer_bram_wr_en) begin
            bram_wr_en = 1'b1;
            bram_addr = clearer_bram_addr;
            bram_din = clearer_bram_din;
        end else if (writer_bram_wr_en) begin
            // 写入操作
        end else begin
            // 读取操作
        end
    end
endmodule
```

## 注意事项

1. **清除优先级**：在 `matrix_storage_manager` 中，清除操作应具有最高优先级
2. **单次请求**：每次 `clear_request` 只处理一个矩阵的清除
3. **不检查有效性**：模块不检查矩阵 ID 的有效性，由上层模块保证
4. **仅清除元数据**：只清除前 3 个地址，不清除实际矩阵数据
5. **同步操作**：所有操作都是同步的，严格遵循时钟边沿
6. **握手协议**：使用标准的 request-done 握手协议

## 测试验证

建议的测试用例：
- 清除不同 ID 的矩阵（0-7）
- 连续清除多个矩阵
- 验证清除后槽位确实为空
- 验证 BRAM 写入的地址和数据正确
- 时序测试（清除延迟）

## 相关模块

- [`matrix_storage_manager`](矩阵储存管理器.md) - 使用 clearer 的上层模块
- [`matrix_writer`](矩阵储存管理器.md) - 与 clearer 配合使用的写入模块
- [`matrix_address_getter`](矩阵储存管理器.md) - 地址计算子模块