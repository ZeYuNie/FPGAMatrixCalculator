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
});