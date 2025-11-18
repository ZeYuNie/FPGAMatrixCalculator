// 页面通用脚本 - 处理返回按钮、页面动画和状态栏

// 更新状态栏显示
const updateStatusBar = (connected, errorMessage = null) => {
    const indicator = document.getElementById('backend-indicator');
    const statusText = document.getElementById('backend-status-text');
    
    if (!indicator || !statusText) return;
    
    if (connected) {
        indicator.className = 'status-indicator status-connected';
        statusText.textContent = '后端已连接';
    } else {
        indicator.className = 'status-indicator status-disconnected';
        statusText.textContent = errorMessage ? `后端断开: ${errorMessage}` : '后端断开连接';
    }
};

// 心跳检测
const checkBackendHealth = async () => {
    try {
        const result = await window.electronAPI.checkBackendHealth();
        updateStatusBar(result.connected, result.error);
    } catch (error) {
        updateStatusBar(false, error.message);
    }
};

// 添加状态栏到页面
const addStatusBar = () => {
    // 检查是否已经有状态栏
    if (document.querySelector('.status-bar')) return;
    
    const statusBar = document.createElement('div');
    statusBar.className = 'status-bar';
    statusBar.innerHTML = `
        <div class="status-item">
            <span class="status-indicator" id="backend-indicator"></span>
            <span class="status-text" id="backend-status-text">检查后端连接...</span>
        </div>
    `;
    document.body.appendChild(statusBar);
};

document.addEventListener('DOMContentLoaded', () => {
    // 页面淡入动画
    document.body.style.opacity = '0';
    setTimeout(() => {
        document.body.style.transition = 'opacity 0.3s ease';
        document.body.style.opacity = '1';
    }, 10);

    // 返回按钮功能
    const backButton = document.getElementById('back-button');
    if (backButton) {
        backButton.addEventListener('click', () => {
            // 淡出动画
            document.body.style.opacity = '0';
            setTimeout(() => {
                window.location.href = '../index.html';
            }, 300);
        });
    }
    
    // 添加状态栏（如果页面中没有的话）
    addStatusBar();
    
    // 初始检查后端状态（快速检查避免显示"检查中"状态）
    setTimeout(() => {
        checkBackendHealth();
    }, 100);
    
    // 定期心跳检测（每5秒）
    setInterval(checkBackendHealth, 5000);
});