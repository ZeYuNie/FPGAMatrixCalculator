const { app, BrowserWindow, Menu, ipcMain } = require('electron/main')
const path = require('path')
const { spawn } = require('child_process')
const fs = require('fs')

let pythonProcess = null
let backendStatus = { connected: false, error: null }

// 启动Python后端
const startPythonBackend = () => {
  const middlewarePath = path.join(__dirname, '..', 'middleware')
  const appPyPath = path.join(middlewarePath, 'app.py')
  const venvPythonWin = path.join(middlewarePath, '.venv', 'Scripts', 'python.exe')
  const venvPythonUnix = path.join(middlewarePath, '.venv', 'bin', 'python')
  
  // 检查app.py是否存在
  if (!fs.existsSync(appPyPath)) {
    backendStatus = { connected: false, error: 'app.py文件不存在' }
    console.error('Python后端文件不存在:', appPyPath)
    return
  }
  
  // 确定使用哪个Python解释器
  let pythonCmd = 'python'
  if (fs.existsSync(venvPythonWin)) {
    pythonCmd = venvPythonWin
  } else if (fs.existsSync(venvPythonUnix)) {
    pythonCmd = venvPythonUnix
  }
  
  console.log('使用Python解释器:', pythonCmd)
  console.log('工作目录:', middlewarePath)
  
  // 启动Python进程，设置UTF-8编码避免中文乱码
  pythonProcess = spawn(pythonCmd, ['app.py'], {
    cwd: middlewarePath,
    stdio: ['pipe', 'pipe', 'pipe'],
    env: {
      ...process.env,
      PYTHONIOENCODING: 'utf-8'
    }
  })
  
  pythonProcess.stdout.on('data', (data) => {
    // Windows下使用GBK解码，其他系统使用UTF-8
    const decoded = process.platform === 'win32'
      ? data.toString('latin1') // Windows控制台输出
      : data.toString('utf-8')
    console.log(`Python后端: ${decoded}`)
  })
  
  pythonProcess.stderr.on('data', (data) => {
    // Windows下使用GBK解码，其他系统使用UTF-8
    const decoded = process.platform === 'win32'
      ? data.toString('latin1') // Windows控制台输出
      : data.toString('utf-8')
    
    const isRealError = /error|exception|traceback|failed|fatal/i.test(decoded)
    
    if (isRealError) {
      console.error(`Python后端错误: ${decoded}`)
      backendStatus = { connected: false, error: decoded }
    } else {
      console.log(`Python后端日志: ${decoded}`)
    }
  })
  
  pythonProcess.on('error', (error) => {
    console.error('启动Python后端失败:', error)
    backendStatus = { connected: false, error: `启动失败: ${error.message}` }
  })
  
  pythonProcess.on('exit', (code) => {
    console.log(`Python后端进程退出，代码: ${code}`)
    backendStatus = { connected: false, error: `进程退出，代码: ${code}` }
    pythonProcess = null
  })
  
  // 给Python后端一些启动时间
  setTimeout(() => {
    if (pythonProcess && !pythonProcess.killed) {
      backendStatus = { connected: true, error: null }
      console.log('Python后端启动成功')
    }
  }, 3000)
}

// 停止Python后端
const stopPythonBackend = async () => {
  if (pythonProcess) {
    // 尝试通过API优雅关闭
    try {
      console.log('发送关闭请求到Python后端...')
      const response = await fetch('http://127.0.0.1:11459/shutdown', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        }
      })
      
      if (response.ok) {
        console.log('Python后端收到关闭请求')
        // 等待一段时间让后端自己关闭
        await new Promise(resolve => setTimeout(resolve, 1000))
      }
    } catch (error) {
      console.log('无法通过API关闭后端，使用强制关闭:', error.message)
    }
    
    // 如果进程仍在运行，强制关闭
    if (pythonProcess && !pythonProcess.killed) {
      console.log('强制终止Python进程')
      pythonProcess.kill()
    }
    
    pythonProcess = null
    backendStatus = { connected: false, error: null }
  }
}

const createWindow = () => {
  // 移除默认菜单栏
  Menu.setApplicationMenu(null)
  
  const win = new BrowserWindow({
    width: 1200,
    height: 900,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true
    }
  })

  win.loadFile('index.html')
}

// IPC处理：获取后端状态
ipcMain.handle('get-backend-status', async () => {
  return backendStatus
})

// IPC处理：重启后端
ipcMain.handle('restart-backend', async () => {
  stopPythonBackend()
  setTimeout(() => {
    startPythonBackend()
  }, 500)
  return { success: true }
})

app.whenReady().then(() => {
  // 启动Python后端
  startPythonBackend()
  
  createWindow()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

app.on('window-all-closed', async () => {
  // 停止Python后端
  await stopPythonBackend()
  
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

// 应用退出时确保Python进程被终止
app.on('before-quit', async (event) => {
  if (pythonProcess) {
    event.preventDefault()
    await stopPythonBackend()
    app.exit(0)
  }
})