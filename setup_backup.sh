#!/bin/bash

# 创建存储配置和脚本的目录
BACKUP_DIR="/etc/back-Remote"
if [ ! -d "$BACKUP_DIR" ]; then
    sudo mkdir -p $BACKUP_DIR
fi

# 获取用户输入的服务器信息
read -p "请输入远程服务器IP: " REMOTE_HOST
read -p "请输入服务器用户名 [默认: root]: " REMOTE_USER
REMOTE_USER=${REMOTE_USER:-root}
read -sp "请输入服务器密码: " REMOTE_PASS
echo
read -p "请输入服务器端口 [默认: 22]: " REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}
read -p "请输入远程目录: " REMOTE_DIR
read -p "请输入本地目录 [默认: /root/backup-$REMOTE_HOST]: " LOCAL_DIR
LOCAL_DIR=${LOCAL_DIR:-/root/backup-$REMOTE_HOST}

# 保存到配置文件
CONFIG_FILE="$BACKUP_DIR/backup_config.conf"
echo "REMOTE_HOST=$REMOTE_HOST" > $CONFIG_FILE
echo "REMOTE_USER=$REMOTE_USER" >> $CONFIG_FILE
echo "REMOTE_PASS=$REMOTE_PASS" >> $CONFIG_FILE
echo "REMOTE_PORT=$REMOTE_PORT" >> $CONFIG_FILE
echo "REMOTE_DIR=$REMOTE_DIR" >> $CONFIG_FILE
echo "LOCAL_DIR=$LOCAL_DIR" >> $CONFIG_FILE

# 创建 back.sh 脚本
cat <<EOF > $BACKUP_DIR/back.sh
#!/bin/bash
# 加载配置文件
source /etc/back-Remote/backup_config.conf

# 检查并安装 sshpass 和 rsync
if ! command -v sshpass &> /dev/null; then
    echo "sshpass 未安装，正在安装..."
    sudo apt-get install -y sshpass
fi

if ! command -v rsync &> /dev/null; then
    echo "rsync 未安装，正在安装..."
    sudo apt-get install -y rsync
fi

# 创建本地备份目录（如果不存在）
sudo mkdir -p \$LOCAL_DIR

# 检查远程目录是否存在
if sshpass -p "\$REMOTE_PASS" ssh -o StrictHostKeyChecking=no -p \$REMOTE_PORT \$REMOTE_USER@\$REMOTE_HOST "[ -d \$REMOTE_DIR ]"; then
    echo "正在检查目录: \$REMOTE_DIR"
    # 找到最新的文件
    LATEST_FILE=\$(sshpass -p "\$REMOTE_PASS" ssh -o StrictHostKeyChecking=no -p \$REMOTE_PORT \$REMOTE_USER@\$REMOTE_HOST "find \$REMOTE_DIR -type f -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2")
    
    # 获取本地最新文件的名称
    LOCAL_LATEST_FILE=\$(find \$LOCAL_DIR -type f -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2)
    
    # 获取文件名，不包括路径
    REMOTE_LATEST_FILENAME=\$(basename "\$LATEST_FILE")
    LOCAL_LATEST_FILENAME=\$(basename "\$LOCAL_LATEST_FILE")
    
    echo "远程最新文件为: \$REMOTE_LATEST_FILENAME"
    echo "本地最新文件为: \$LOCAL_LATEST_FILENAME"
    
    # 比较文件名
    if [ "\$REMOTE_LATEST_FILENAME" != "\$LOCAL_LATEST_FILENAME" ]; then
        echo "发现新文件，正在同步..."
        # 使用 rsync 同步最新的文件到本地
        sshpass -p "\$REMOTE_PASS" rsync -avz -e "ssh -o StrictHostKeyChecking=no -p \$REMOTE_PORT" --progress "\$REMOTE_USER@\$REMOTE_HOST:\$LATEST_FILE" "\$LOCAL_DIR"
        echo "备份完成。"
    else
        echo "最新文件已存在，无需备份。"
    fi
else
    echo "远程目录不存在。"
fi
EOF

# 给 back.sh 脚本执行权限
sudo chmod +x $BACKUP_DIR/back.sh
echo "配置文件和备份脚本已创建并保存在 $BACKUP_DIR。"

# 创建符号链接
sudo ln -sf $BACKUP_DIR/back.sh /usr/local/bin/back.sh
echo "已创建符号链接，可以从任何位置运行 back.sh。"

# 安排在脚本执行完毕后删除自身
nohup bash -c "sleep 2; rm -- \"$0\"" &>/dev/null &
