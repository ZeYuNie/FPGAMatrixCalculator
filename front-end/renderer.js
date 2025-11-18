// 后端连接状态管理
let backendConnected = false;

// 更新状态栏显示
const updateStatusBar = (connected, errorMessage = null) => {
    const indicator = document.getElementById('backend-indicator');
    const statusText = document.getElementById('backend-status-text');
    
    if (!indicator || !statusText) return;
    
    backendConnected = connected;
    
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

// 页面跳转逻辑
document.addEventListener('DOMContentLoaded', () => {
    // 页面淡入动画
    document.body.style.opacity = '0';
    setTimeout(() => {
        document.body.style.transition = 'opacity 0.3s ease';
        document.body.style.opacity = '1';
    }, 10);

    // 获取所有的卡片元素
    const cards = document.querySelectorAll('.card');
    
    // 页面跳转函数（带淡出效果）
    const navigateToPage = (pageName) => {
        document.body.style.opacity = '0';
        setTimeout(() => {
            window.location.href = `pages/${pageName}.html`;
        }, 300);
    };
    
    // 为每个卡片添加点击事件监听器
    cards.forEach(card => {
        card.addEventListener('click', () => {
            const pageName = card.getAttribute('data-page');
            if (pageName) {
                navigateToPage(pageName);
            }
        });
        
        // 添加键盘访问支持
        card.setAttribute('tabindex', '0');
        card.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                const pageName = card.getAttribute('data-page');
                if (pageName) {
                    navigateToPage(pageName);
                }
            }
        });
    });
    
    // 初始检查后端状态（快速检查避免显示"检查中"状态）
    setTimeout(() => {
        checkBackendHealth();
    }, 100);
    
    // 定期心跳检测（每5秒）
    setInterval(checkBackendHealth, 5000);
});