# 使用官方Ubuntu基础镜像
FROM ubuntu:22.04

# 设置环境变量，避免交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 更新包列表并安装必要组件
RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    supervisor \
    vim \
    curl \
    wget \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# 配置SSH
RUN mkdir /var/run/sshd
RUN echo 'root:12345678' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# 创建SSH密钥（如果不存在）
RUN ssh-keygen -A

# 安装webssh
RUN pip3 install webssh

# 创建webssh配置目录和数据目录
RUN mkdir -p /etc/webssh /var/log/webssh

# 修改webssh配置
RUN echo '{\
    "port": 8888,\
    "address": "0.0.0.0",\
    "policy": "warning",\
    "logging": "debug",\
    "log_file_prefix": "/var/log/webssh/webssh.log",\
    "xsrf": true,\
    "origin_policy": "same_origin",\
    "ssl": false,\
    "ssl_options": {\
        "certfile": "/path/to/cert.crt",\
        "keyfile": "/path/to/cert.key"\
    },\
    "syslog_address": "",\
    "fd_limit": 1024,\
    "max_body_size": 104857600,\
    "allow_agent": true,\
    "agent_path": "",\
    "allow_auth": true,\
    "allow_auth_password": true,\
    "allow_auth_publickey": true,\
    "allow_auth_keyboard_interactive": false,\
    "encoding": "utf8"\
}' > /etc/webssh/config.json

# 配置supervisor来管理sshd和webssh
RUN echo '[supervisord]\n\
nodaemon=true\n\
logfile=/var/log/supervisor/supervisord.log\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[program:sshd]\n\
command=/usr/sbin/sshd -D\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/var/log/sshd.log\n\
stderr_logfile=/var/log/sshd.err\n\
\n\
[program:webssh]\n\
command=wssh --address=0.0.0.0 --port=8888 --policy=warning --log-file-prefix=/var/log/webssh/webssh.log\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/var/log/webssh.log\n\
stderr_logfile=/var/log/webssh.err\n' > /etc/supervisor/conf.d/services.conf

# 创建启动脚本
RUN echo '#!/bin/bash\n\
# 显示登录信息\n\
echo "==========================================="\n\
echo "  Ubuntu SSH & WebSSH 容器已启动"\n\
echo "==========================================="\n\
echo "SSH 访问信息:"\n\
echo "  用户名: root"\n\
echo "  密码: 12345678"\n\
echo "  端口: 22"\n\
echo "WebSSH 访问信息:"\n\
echo "  地址: http://<容器IP>:8888"\n\
echo "  用户名: root"\n\
echo "  密码: 12345678"\n\
echo "==========================================="\n\
# 启动supervisor\n\
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf\n' > /start.sh

RUN chmod +x /start.sh

# 暴露端口 - 移除行尾注释以避免解析错误
EXPOSE 22
EXPOSE 8888

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD netstat -an | grep -w 22 && netstat -an | grep -w 8888 || exit 1

# 设置工作目录
WORKDIR /root

# 使用supervisor作为入口点
ENTRYPOINT ["/start.sh"]
