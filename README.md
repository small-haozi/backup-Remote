# 用于备份远程服务器数据的一键脚本
- (默认备份指定文件夹中的最新的文件)
## 一键脚本
```
bash <(curl -L -s https://raw.githubusercontent.com/small-haozi/backup-Remote/main/setup_backup.sh)
```
## 定时备份
  ### 1 编辑 crontab 文件
    
    crontab -e
    
  ### 2 添加定时任务
  以下为每小时备份一次的定时任务，如需要修改时间，请自行搜索定时规则
    
    0 * * * * /etc/back-Remote/back.sh
    
  ### 3 保存并退出编辑器
  - 保存你的更改并退出编辑器。在大多数编辑器中，你可以按 Ctrl+X 来退出，如果是使用 nano 编辑器，它会询问你是否保存更改，回答 Y 然后按 Enter 确认。
  ### 4 确认定时任务已设置
     
     crontab -l
     
  ### 5 设置开机自启
  - cron 服务通常在大多数 Linux 发行版中默认启动。只要 cron 服务在系统启动时运行，你的定时任务就会自动启动。你可以通过以下命令确认 cron 服务的状态：
  ```
  sudo systemctl status cron
  ```
  - 如果服务没有运行，你可以使用以下命令启动它，并设置为开机自启：
  ```
  sudo systemctl start cron
  sudo systemctl enable cron
  ```
