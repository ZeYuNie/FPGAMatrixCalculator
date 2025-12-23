# FPGA 矩阵计算器项目数据流分类文档

本报告细致分析了系统中数据的流向、行为及关联的元数据，按功能类别分类如下：

---

## 1. 外部数据输入流 (External Data Input Flow)
**路径**: 上位机 (Host) $\rightarrow$ UART PHY $\rightarrow$ Buffer RAM

| 阶段 | 数据内容 | 元数据/格式 | 控制信号/握手 |
| :--- | :--- | :--- | :--- |
| **串行接收** | 原始比特流 | 8-bit ASCII 字符 | UART Start/Stop Bit |
| **字符校验** | 过滤后的 ASCII 字节 | 合法字符集 (0-9, -, \n, \r) | `pkt_payload_valid` |
| **数值转换** | 32-bit 有符号整数 | 累加结果 (Int32) | `converter_result_valid` |
| **缓冲存储** | 整数序列 | 存储于 `num_storage_ram` | `ram_wr_en`, `ram_wr_addr` |

---

## 2. 矩阵结构化存储流 (Matrix Structured Storage Flow)
**路径**: Buffer RAM $\rightarrow$ Matrix Writer $\rightarrow$ Main BRAM

| 数据类别 | 具体内容 | 存储位置 (偏移) | 行为描述 |
| :--- | :--- | :--- | :--- |
| **维度元数据** | 行数 (8-bit), 列数 (8-bit) | Word 0 | 写入块首地址，用于后续寻址校验 |
| **标识元数据** | 矩阵名称 (8-byte ASCII) | Word 1-2 | 存储用户定义的矩阵标签 |
| **元素数据流** | 32-bit 矩阵元素 | Word 3+ | 按行优先顺序流式写入 |
| **控制信号** | `write_request`, `write_ready`, `data_valid`, `writer_ready`, `write_done` |

---

## 3. 运算操作数检索流 (Operand Retrieval Flow)
**路径**: Main BRAM $\rightarrow$ Scanner/Selector $\rightarrow$ Accelerator

| 流向分类 | 数据内容 | 涉及元数据 | 行为逻辑 |
| :--- | :--- | :--- | :--- |
| **元数据扫描** | Word 0 (维度) | 目标维度 (m, n) | 遍历 8 个槽位，比对维度生成 `valid_mask` |
| **操作数读取** | 32-bit 矩阵元素 | 矩阵 ID, 元素索引 | 根据 `row_idx` 和 `col_idx` 计算 BRAM 物理地址 |
| **标量输入** | 32-bit 标量值 | 无 | 从拨码开关或 UART 缓存直接送入加速器 |
| **控制信号** | `scanner_start`, `scanner_done`, `bram_rd_addr`, `bram_rd_data` |

---

## 4. 计算结果回写流 (Computation Result Write-back Flow)
**路径**: Accelerator $\rightarrow$ Matrix Writer $\rightarrow$ Main BRAM (Slot 0)

| 数据内容 | 目标元数据 | 行为描述 | 控制信号 |
| :--- | :--- | :--- | :--- |
| **运算结果** | 32-bit 结果元素 | ID = 0, 结果维度 | 加速器计算出单个元素后立即发起写入请求 | `write_request` |
| **性能指标** | 32-bit 时钟周期数 | 无 | 统计 `start` 到 `done` 的周期，送往数码管显示 | `cycle_count` |

---

## 5. 矩阵展示输出流 (Matrix Display Output Flow)
**路径**: Main BRAM $\rightarrow$ Reader $\rightarrow$ UART TX $\rightarrow$ Host

| 阶段 | 数据内容 | 格式处理 | 控制信号 |
| :--- | :--- | :--- | :--- |
| **数据提取** | 32-bit 整数 | 从 Word 3+ 顺序读取 | `bram_rd_addr` |
| **格式化转换** | ASCII 字符流 | 整数转字符串，添加空格 (0x20) | `ascii_valid` |
| **布局控制** | 换行符 (0x0A) | 根据元数据中的 `cols` 插入换行 | `ascii_ready` |

---

## 6. 随机矩阵生成流 (Random Matrix Generation Flow)
**路径**: Buffer RAM $\rightarrow$ RNG $\rightarrow$ Matrix Writer $\rightarrow$ Main BRAM

| 阶段 | 数据内容 | 元数据/参数 | 控制信号 |
| :--- | :--- | :--- | :--- |
| **参数读取** | 生成参数 (m, n, count) | 从 Buffer RAM 读取 | `buf_rd_addr`, `buf_rd_data` |
| **随机数产生** | 32-bit 伪随机序列 | XorShift32 算法，基于周期计数器种子 | `rng_start`, `rng_out` |
| **数值映射** | 范围限制后的整数 | `(rand % range) + min` | `remainder_reg` (取模结果) |
| **流式存储** | 随机矩阵元素 | 自动寻找空闲槽位 ID | `write_request`, `data_valid` |

---

## 7. 系统参数配置流 (System Settings Configuration Flow)
**路径**: Buffer RAM $\rightarrow$ Settings Handler $\rightarrow$ Settings RAM $\rightarrow$ Subsystems

| 阶段 | 数据内容 | 校验规则 | 目标寄存器 |
| :--- | :--- | :--- | :--- |
| **指令解析** | 命令字 (1-5) | 识别 max_row, max_col, min, max, countdown | `cmd_reg` |
| **数值校验** | 32-bit 配置值 | 维度 $\le 32$, 倒计时 5-15s | `validation_error` |
| **参数广播** | 稳定的配置电平 | 实时更新至所有子系统 | `settings_max_row/col` 等 |

---

## 8. Winograd 内部变换流 (Winograd Internal Transformation Flow)
**路径**: Image/Kernel Reg $\rightarrow$ KTU/TTU $\rightarrow$ PWM $\rightarrow$ RTU $\rightarrow$ Result Reg

| 阶段 | 数据内容 | 变换行为 | 握手信号 |
| :--- | :--- | :--- | :--- |
| **核变换 (KTU)** | 3x3 Kernel $\rightarrow$ 6x6 域 | $GgG^T$ 矩阵运算 | `ktu_start`, `ktu_done` |
| **块变换 (TTU)** | 6x6 Tile $\rightarrow$ 6x6 域 | $B^TdB$ 矩阵运算 | `ttu_start`, `ttu_done` |
| **点乘 (PWM)** | 6x6 逐元素乘积 | 36 个并行/串行乘法器 | `mult_start`, `mult_done` |
| **逆变换 (RTU)** | 6x6 域 $\rightarrow$ 4x4 结果 | $A^TMA$ 矩阵运算 | `rtu_start`, `rtu_done` |

---

## 9. 硬件交互反馈流 (Hardware Interaction & Feedback Flow)
**路径**: Subsystems $\rightarrow$ LED/7-Seg Controller $\rightarrow$ Physical Pins

| 类别 | 数据内容 | 触发源 | 物理表现 |
| :--- | :--- | :--- | :--- |
| **状态指示** | Busy/Done/Error 信号 | 各子系统状态机 | 板载 LED[2:0] |
| **模式显示** | 当前运算类型代号 | `op_mode_controller` | 数码管显示 (T, A, B, C, J) |
| **性能/计数** | 周期数或输入数字个数 | `executor_cycle_count` | 数码管 4 位 BCD 显示 |
| **错误倒计时** | 剩余秒数 | `countdown_timer` | 数码管实时递减显示 |

---

## 10. 全局控制与仲裁流 (Global Control & Arbitration Flow)
**路径**: Top Module $\rightarrow$ Subsystems

| 控制类别 | 信号内容 | 影响范围 | 优先级逻辑 |
| :--- | :--- | :--- | :--- |
| **模式切换** | `op_mode` (3-bit) | 全局子系统激活 | Input > Gen > Show > Calc |
| **存储仲裁** | `bram_wr_en`, `addr` | Main BRAM 访问权 | Clear > Write > Read |
| **通信仲裁** | `tx_data`, `tx_start` | UART 发送权 | Clear Resp > Dump > Calc > Show |
| **状态反馈** | `busy`, `done`, `error` | 板载 LED/数码管 | 实时反映当前激活流的状态 |

---

## 7. 总结：数据流中的关键元数据
*   **维度 (Dimensions)**: 决定了 BRAM 寻址边界、运算合法性及输出换行逻辑。
*   **矩阵 ID (Matrix ID)**: 决定了数据在 9KB BRAM 空间中的基地址偏移 ($ID \times 1152$)。
*   **状态掩码 (Valid Mask)**: 决定了哪些存储块包含有效数据，可作为运算操作数。
