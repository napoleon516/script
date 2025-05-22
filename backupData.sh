#!/bin/bash

# 远程服务器配置
REMOTE_USER="hamal"
REMOTE_PASS="password"
REMOTE_HOST="172.27.36.217"
REMOTE_BASE_DIR="/data/logs"

# 本地参数设置,日志路径，指定要处理的文件大小
LOGPATH="/var/log"
FSIZE="+1G"

# 项目文件名数组
FILES=(
  "aiapi" "cdp" "ievents"
  "event" "ivane" "liveshell"
  "martech" "recommend" "recommext"
  "duosuna" "access" "aidata"
  "tools" "contect" "error"
  "gucp" "meet" "portal"
  "wecomdev"
)

# 定义正则规则数组
REGS=(
  "^access\.api\.(.*?) \.log"
  "^access\.(.*?)\.log"
  "^api\.(.*?)\.access\.log"
  "^(?!access\.api\.|api\.|access\.)(.*?)\.access\.log"
)

# 处理大日志文件
process_large_logs() {
    local log_dir="$LOGPATH"

    find "$log_dir" -type f -size "$FSIZE" | while read -r file; do
        local base_name=$(basename "$file")
        local category="other"

        # 检查是否在FILES数组中
        for item in "${FILES[@]}"; do
            if [[ "$base_name" == *"$item"* ]]; then
                category="$item"
                break
            fi
        done

        # 检查是否符合正则规则
        if [[ "$category" == "other" ]]; then
            for regex in "${REGS[@]}"; do
                if [[ "$base_name" =~ $regex ]]; then
                    category="${BASH_REMATCH[0]}"
                    break
                fi
            done
        fi

        echo "process file: $base_name"

        # 压缩文件
        local compressed_file="/tmp/${base_name}_$(date +%Y%m%d%H%M%S).gz"
        gzip -c "$file" > "$compressed_file"

        # 远程目录路径
        local remote_dir="${REMOTE_BASE_DIR}/${category}"
        local remote_file="${remote_dir}/$(basename $compressed_file)"

        # 使用SSH创建远程目录
        sshpass -p "$REMOTE_PASS" ssh -n -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_HOST" "mkdir -p \"$remote_dir\""

        # 使用SCP传输文件
        sshpass -p "$REMOTE_PASS" scp -o StrictHostKeyChecking=no "$compressed_file" "$REMOTE_USER@$REMOTE_HOST:$remote_file"

        if [ $? -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 成功传输文件: $file 到 $remote_file"
            # 清空原文件
            # > "$file"
            # 删除临时压缩文件
            rm -f "$compressed_file"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 传输文件失败: $file" >&2
        fi
    done
}

# 主执行流程
echo "开始处理大日志文件..."
process_large_logs
echo "日志文件处理完成"%