const { contextBridge, ipcRenderer } = require('electron')

// 暴露安全的API给渲染进程
contextBridge.exposeInMainWorld('electronAPI', {
  // 获取后端状态
  getBackendStatus: () => ipcRenderer.invoke('get-backend-status'),
  
  // 重启后端
  restartBackend: () => ipcRenderer.invoke('restart-backend'),
  
  // 检查后端心跳
  checkBackendHealth: async () => {
    try {
      const response = await fetch('http://127.0.0.1:11459/health')
      if (response.ok) {
        const data = await response.json()
        return { connected: true, data }
      }
      return { connected: false, error: `HTTP ${response.status}` }
    } catch (error) {
      return { connected: false, error: error.message }
    }
  }
})