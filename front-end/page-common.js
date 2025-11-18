// 页面通用脚本 - 处理返回按钮和页面动画

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
});