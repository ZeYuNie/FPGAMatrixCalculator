# UART数据包处理器

## 帧格式

```text
+--------+--------+---------+---------+---------+---------------+
| HEAD0  | HEAD1  |  CMD    | LEN_L   | LEN_H   |   PAYLOAD     |
+--------+--------+---------+---------+---------+---------------+
  0xAA     0x55      1 byte   1 byte    1 byte    0-65535 bytes
```

- HEAD0/HEAD1: 固定帧头 0xAA55
- CMD: 命令字节
- LEN: payload长度，小端序 (LEN = LEN_H << 8 | LEN_L)
- PAYLOAD: 可选数据

## 参数

- `MAX_PAYLOAD_BYTES`: 最大payload字节数，默认512

## 接口

### RX路径（PC → FPGA）

```systemverilog
// 字节输入
input  logic [7:0]  rx_byte
input  logic        rx_byte_valid
output logic        rx_byte_ready

// 元数据输出
output logic        pkt_meta_valid
input  logic        pkt_meta_ready
output logic [7:0]  pkt_cmd
output logic [15:0] pkt_length
output logic [1:0]  pkt_error        // 0: 正常, 1: 长度溢出

// Payload流输出
output logic [7:0]  pkt_payload_data
output logic        pkt_payload_valid
output logic        pkt_payload_last
input  logic        pkt_payload_ready
```

### TX路径（FPGA → PC）

```systemverilog
// 元数据输入
input  logic        tx_meta_valid
output logic        tx_meta_ready
input  logic [7:0]  tx_cmd
input  logic [15:0] tx_length

// Payload流输入
input  logic [7:0]  tx_payload_data
input  logic        tx_payload_valid
input  logic        tx_payload_last
output logic        tx_payload_ready

// 字节输出
output logic [7:0]  tx_byte
output logic        tx_byte_valid
input  logic        tx_byte_ready
```

## 使用方法

### 接收数据

1. 连接uart_rx输出到rx_byte接口
2. pkt_meta_valid有效时读取cmd和length
3. 置pkt_meta_ready为高，握手完成
4. 通过pkt_payload接口读取payload数据

### 发送数据

1. 设置tx_cmd和tx_length
2. 置tx_meta_valid为高，等待tx_meta_ready
3. 通过tx_payload接口发送payload数据
4. 连接tx_byte输出到uart_tx输入

## 错误处理

- pkt_error=1: payload长度超过MAX_PAYLOAD_BYTES，丢弃该帧
