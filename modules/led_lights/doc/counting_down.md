# counting_down - 倒计时模块

## 功能
实现倒计时功能并通过七段数码管实时显示。

## 端口
| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| clk | input | 1 | 系统时钟（100MHz） |
| rst_n | input | 1 | 异步复位，低电平有效 |
| time_in | input | [15:0] | 倒计时秒数（0-9999） |
| start | input | 1 | 启动倒计时信号 |
| stop | output | 1 | 倒计时结束信号 |
| seg | output | [7:0] | 七段数码管段选 |
| an | output | [3:0] | 七段数码管位选 |

## 状态机
- **IDLE**: 等待start信号
- **COUNTING**: 倒计时中，每秒递减
- **DONE**: 倒计时完成，拉高stop一周期

## 工作流程
1. IDLE状态接收start信号，锁存time_in
2. 进入COUNTING，七段管显示当前计数值
3. 每秒递减计数器
4. 计数到0后进入DONE，拉高stop并关闭显示
5. 下一周期返回IDLE

## 子模块
- `clock_divider`: 产生1Hz秒脉冲
- `bin_to_bcd`: 转换计数值为BCD码
- `seg7_display`: 驱动数码管显示

## 复位行为
rst_n或stop信号后自动回到初始状态。