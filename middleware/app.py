# python_backend/main.py

from flask import Flask, jsonify, request
from flask_cors import CORS
import time
import os
import signal
import logging

app = Flask(__name__)
CORS(app)

# 禁用Flask的访问日志，避免在生产环境中输出大量无用日志
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)  # 只显示错误级别的日志

@app.route('/health', methods=['GET'])
def health_check():
    """
    心跳接口
    """
    return jsonify({"status": "ok", "timestamp": time.time()})

@app.route('/shutdown', methods=['POST'])
def shutdown():
    """
    关闭服务器
    """
    print("收到关闭请求，正在关闭服务器...")
    
    # 返回响应
    response = jsonify({"status": "shutting down"})
    
    # 延迟关闭以确保响应被发送
    def delayed_shutdown():
        time.sleep(0.5)
        print("服务器已关闭")
        os.kill(os.getpid(), signal.SIGTERM)
    
    import threading
    threading.Thread(target=delayed_shutdown).start()
    
    return response

@app.route('/api/process_data', methods=['POST'])
def process_data():
    """
    接收前端 JSON 数据，处理后返回新的 JSON 数据。
    """
    try:
        data = request.json

        if not data:
            return jsonify({"error": "No data provided"}), 400

        name = data.get('name', 'Guest')

        response_message = f"Hello, {name}! Your request was processed by Python."
        
        response_data = {
            "message": response_message,
            "received_data": data
        }
        
        return jsonify(response_data)

    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=11459)

