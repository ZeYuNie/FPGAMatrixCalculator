# FPGA Matrix Calculator

CS 207 Proj. **基于 FPGA 的矩阵计算器开发**

## 配置与运行

### VSCode (推荐)

1. 打开 `.vscode/settings.json`，根据 Vivado 安装路径修改 `vivado.installPath`，例如

    ```json
    {
        "vivado.installPath": "F:/Programs/VivadoSuite/2025.1/Vivado",
    }
    ```

2. 使用 `ctrl+shift+P` 打开命令，输入 `run task` 找到 `任务：运行任务`，进入后选择 `Run Vivado Tcl Script`，即可自动创建 Vivado 工程并打开 Vivado GUI

> 注意，每一次都会根据源代码生成新的 Vivado 项目
