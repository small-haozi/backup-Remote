#!/bin/bash

echo -e "\033[1;94m设置备份脚本\033[0m"

echo "======================================================"

# 创建存储配置和脚本的目录
BACKUP_DIR="/etc/back-Remote"
if [ ! -d "$BACKUP_DIR" ]; then
    sudo mkdir -p $BACKUP_DIR
    echo "已创建目录: $BACKUP_DIR"
fi

echo -e "\033[1;94m请输入服务器信息:\033[0m"
echo "======================================================"
echo -e " "
read -p "远程服务器IP: " REMOTE_HOST
read -p "远程服务器用户名 [默认: root]: " REMOTE_USER
REMOTE_USER=${REMOTE_USER:-root}
read -p "远程服务器密码: " REMOTE_PASS
read -p "远程服务器端口 [默认: 22]: " REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}
read -p "远程目录: " REMOTE_DIR
read -p "本地目录 [默认: /root/backup-$REMOTE_HOST]: " LOCAL_DIR
LOCAL_DIR=${LOCAL_DIR:-/root/backup-$REMOTE_HOST}
echo -e " "
echo "======================================================"
echo -e " "
echo -e "当前设置信息为："
echo -e " "
echo -e "远程服务器IP:$REMOTE_HOST"
echo -e "远程服务器用户名:$REMOTE_USER"
echo -e "远程服务器密码:$REMOTE_PASS"
echo -e "远程服务器端口:$REMOTE_PORT"
echo -e "远程目录:$REMOTE_DIR"
echo -e "本地目录:$LOCAL_DIR"
echo -e " "
echo -e " 请仔细确认是否输入错误！！如需修改，请自行修改 /etc/back-Remote/backup_config.conf 文件"
echo "======================================================"
echo -e " "
echo -e "\033[1;94m备份文件数量设置:\033[0m"
echo -e " "
echo "======================================================"
read -p "是否设置最大备份文件数量? (y/n): " SET_MAX_BACKUPS
if [ "$SET_MAX_BACKUPS" = "y" ]; then
    read -p "最大备份文件数量: " MAX_BACKUPS
fi

# 删除旧的配置文件和脚本（如果存在）
sudo rm -f $BACKUP_DIR/backup_config.conf
sudo rm -f $BACKUP_DIR/back.sh

# 保存到配置文件
CONFIG_FILE="$BACKUP_DIR/backup_config.conf"
echo "REMOTE_HOST=$REMOTE_HOST" > $CONFIG_FILE
echo "REMOTE_USER=$REMOTE_USER" >> $CONFIG_FILE
echo "REMOTE_PASS=$REMOTE_PASS" >> $CONFIG_FILE
echo "REMOTE_PORT=$REMOTE_PORT" >> $CONFIG_FILE
echo "REMOTE_DIR=$REMOTE_DIR" >> $CONFIG_FILE
echo "LOCAL_DIR=$LOCAL_DIR" >> $CONFIG_FILE
if [ "$SET_MAX_BACKUPS" = "y" ]; then
    echo "MAX_BACKUPS=$MAX_BACKUPS" >> $CONFIG_FILE
fi

echo -e "\n\033[1;34m正在创建备份脚本...\033[0m"
# 创建 back.sh 脚本
cat <<EOF > $BACKUP_DIR/back.sh
#!/bin/bash
# 加载配置文件
source /etc/back-Remote/backup_config.conf

# 检查并安装 sshpass 和 rsync
if ! command -v sshpass &> /dev/null; then
    echo -e "\033[0;33msshpass 未安装，正在安装...\033[0m"
    echo "======================================================"
    sudo apt-get install -y sshpass
fi

if ! command -v rsync &> /dev/null; then
    echo -e "\033[0;33mrsync 未安装，正在安装...\033[0m"
    echo "======================================================"
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
    
    echo "======================================================"
    echo -e " "
    echo "远程最新文件为: \$REMOTE_LATEST_FILENAME"
    echo -e " "
    echo "本地最新文件为: \$LOCAL_LATEST_FILENAME"
    echo -e " "
    echo "======================================================"
    # 比较文件名
    if [ "\$REMOTE_LATEST_FILENAME" != "\$LOCAL_LATEST_FILENAME" ]; then
        echo "发现新文件，正在同步..."
        echo -e "======================================================"
        # 使用 rsync 同步最新的文件到本地
        sshpass -p "\$REMOTE_PASS" rsync -avz -e "ssh -o StrictHostKeyChecking=no -p \$REMOTE_PORT" --progress "\$REMOTE_USER@\$REMOTE_HOST:\$LATEST_FILE" "\$LOCAL_DIR"
        echo "备份完成。"
        echo "======================================================"
    else
        echo "最新文件已存在，无需备份。"
        echo "======================================================"
    fi
else
    echo "远程目录不存在。"
fi

# 管理本地备份文件数量
if [ ! -z "\$MAX_BACKUPS" ]; then
    cd \$LOCAL_DIR
    if [ \$(ls -1 | wc -l) -gt \$MAX_BACKUPS ]; then
        ls -t | tail -n +\$(expr \$MAX_BACKUPS + 1) | xargs rm -f
        echo "超出最大备份文件数量，已删除最旧的备份文件。"
    fi
fi
EOF

# 给 back.sh 脚本执行权限
sudo chmod +x $BACKUP_DIR/back.sh
echo "======================================================"
echo -e " "
echo -e "\033[1;94m配置文件和备份脚本已创建并保存在\033[0m \033[1;92m $BACKUP_DIR。\033[0m"
echo -e " "
# 创建符号链接
sudo ln -sf $BACKUP_DIR/back.sh /usr/local/bin/back.sh
echo -e "\033[1;94m已创建符号链接，可以从任何位置运行\033[0m \033[1;92m back.sh。\033[0m"
echo -e " "
echo "======================================================"

# 安排在脚本执行完毕后删除自身
nohup bash -c "sleep 2; rm -- \"$0\"" &>/dev/null &
