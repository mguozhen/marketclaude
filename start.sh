#!/bin/bash
# 启动 GTM Agent（后台运行，日志写到 agent.log）
cd "$(dirname "$0")"
nohup python3.13 main.py >> agent.log 2>&1 &
echo "GTM Agent started (PID $!)"
echo "Logs: tail -f $(dirname "$0")/agent.log"
