#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOXDIR=$MODDIR/busybox
Config=$MODDIR/config.json
HOSTS_FILE="$MODDIR/system/etc/hosts"
TEMP_FILE="$MODDIR/tmp/temp.txt"
LOCK_FILE="$MODDIR/script.lock"
export PATH=/system/bin:$BUSYBOXDIR:$PATH
. "$MODDIR/action.sh" "-i"

# 使用文件锁而非文件夹锁
if [ -f "$LOCK_FILE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - warning: 脚本已在运行中" >> "$MODDIR/log.txt"
    exit 0
fi

# 创建锁文件
echo $$ > "$LOCK_FILE"

# 在脚本结束时删除锁文件
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# 日志函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1: $2" >> "$MODDIR/log.txt"
}

counter=0

start() {
    # 设置tool.sh和config.json的权限
    chmod 755 "$MODDIR/tool.sh" "$Config"
    > "$MODDIR/log.txt"
    > "$HOSTS_FILE"
    mkdir -p "$MODDIR/tmp"
    chmod 666 "$MODDIR/system/etc/hosts"
    
    # 设置busybox目录下所有文件的权限
    if [ -d "$BUSYBOXDIR" ]; then
        find "$BUSYBOXDIR" -type f -exec chmod 755 {} \;
    fi
    
    mkdir -p $MODDIR/cron.d
    # 修改为每天凌晨3点执行一次
    echo "0 3 * * * $MODDIR/service.sh" > $MODDIR/cron.d/root
    chmod 600 $MODDIR/cron.d/root
    crond -c $MODDIR/cron.d
}
start

# 等待开机完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
    log "wait" "等待开机"
done
log "success" "开机成功"

# 等待联网
log "wait" "等待联网"
PING_ADDRESS=www.baidu.com

while true; do
    if ping -c 1 -W 3 $PING_ADDRESS > /dev/null 2>&1; then
        log "success" "联网成功"
        break
    else
        log "wait" "等待网络连接..."
        sleep 5
    fi
done

log "wait" "等待配置读取"

read_config() {
    log "wait" "读取配置文件中"
    if [ ! -f "$Config" ]; then
        log "error" "配置文件不存在"
        return 1
    fi
    
    jq -r '.[].name' $Config 2>/dev/null | while read -r name; do
        if [ -z "$name" ]; then
            continue
        fi
        
        if [ -f "$MODDIR/mod/$name.conf" ]; then
            cat "$MODDIR/mod/$name.conf" >> "$HOSTS_FILE"
            counter=$(($counter + 1))
        else
            log "warning" "配置文件 $name.conf 不存在"
        fi
    done
    log "success" "读取配置文件成功"
    counter=0
}

update() {
    local index=$1
    local name=$2
    local url=$(jq -r ".[$index].url" "$Config" 2>/dev/null)
    
    if [ -z "$url" ] || [ "$url" = "null" ]; then
        log "error" "$name 的URL为空或无效"
        return 1
    fi
    
    local retries=3
    local count=0
  
    while [ $count -lt $retries ]; do
        if wget -q --timeout=10 --tries=1 --spider "$url"; then
            if wget -O "$MODDIR/mod/$name.conf" "$url" --timeout=30; then
                log "success" "更新了 $name"
                return 0
            else
                log "error" "下载 $name 失败"
            fi
        else
            log "fail" "$url 无法访问，正在重试... $(($count + 1))/$retries)"
            count=$(($count + 1))
            sleep 2
        fi
    done
  
    log "error" "$name 更新失败，无法访问 $url"
    return 1
}

check_update() {
    if [ ! -f "$Config" ]; then
        log "error" "配置文件不存在，跳过更新"
        return 1
    fi
    
    local count=$(jq '. | length' "$Config" 2>/dev/null)
    if [ -z "$count" ] || [ "$count" -eq 0 ]; then
        log "warning" "配置文件为空或格式错误"
        return 1
    fi
    
    local i=0
    local updated=0
    local total=0
  
    log "info" "开始检查更新"
    while [ $i -lt $count ]; do
        local update_flag=$(jq -r ".[$i].update" "$Config" 2>/dev/null)
        local name=$(jq -r ".[$i].name" "$Config" 2>/dev/null)
      
        if [ "$update_flag" = "true" ] && [ -n "$name" ]; then
            total=$((total + 1))
            if update $i "$name"; then
                updated=$((updated + 1))
            fi
        fi
        i=$((i + 1))
    done
    
    log "info" "更新完成: $updated/$total 个配置已更新"
}

# 将通配符模式转换为shell模式
convert_to_shell_pattern() {
    echo "$1" | sed 's/\./\\./g'
}

main() {
    # 确保目录存在
    mkdir -p "$MODDIR/mod" "$MODDIR/tmp"
    
    # 检查更新
    check_update
    
    # 读取配置
    read_config
    
    # 去重
    if [ -s "$HOSTS_FILE" ]; then
        sort -u "$HOSTS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$HOSTS_FILE"
        log "success" "去重成功"
    else
        log "warning" "hosts文件为空，跳过去重"
    fi

    # 处理白名单 - 高效版本带日志
    if [ -f "$MODDIR/白名单.conf" ]; then
        log "info" "找到白名单文件，开始处理"
        
        # 创建临时目录和日志文件
        mkdir -p "$MODDIR/tmp"
        WHITELIST_LOG="$MODDIR/whitelist_log.txt"
        > "$WHITELIST_LOG"  # 清空白名单日志文件
        
        # 提取有效的白名单规则（去除注释和空行）
        grep -v "^[[:space:]]*#" "$MODDIR/白名单.conf" | grep -v "^[[:space:]]*$" > "$MODDIR/tmp/valid_rules.txt"
        
        if [ -s "$MODDIR/tmp/valid_rules.txt" ]; then
            # 记录白名单规则数量
            rule_count=$(wc -l < "$MODDIR/tmp/valid_rules.txt")
            log "info" "加载了 $rule_count 条白名单规则"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - 白名单处理日志" > "$WHITELIST_LOG"
            echo "加载了 $rule_count 条白名单规则" >> "$WHITELIST_LOG"
            
            # 保存原始hosts文件的副本用于比较
            cp "$HOSTS_FILE" "$MODDIR/tmp/hosts.original"
            
            # 保存注释和空行
            grep -E "^[[:space:]]*#|^[[:space:]]*$" "$HOSTS_FILE" > "$TEMP_FILE"
            
            # 处理非注释行 - 使用更高效的方法
            grep -v -E "^[[:space:]]*#|^[[:space:]]*$" "$HOSTS_FILE" > "$MODDIR/tmp/hosts.content"
            
            # 对于每条白名单规则，提取匹配的行并记录
            while read -r pattern; do
                # 转换通配符模式为grep正则表达式
                pattern_regex="$(echo "$pattern" | sed 's/\./\\./g' | sed 's/\*/[^ ]*/g')"
                
                # 查找匹配的行
                grep -E "[[:space:]]${pattern_regex}([[:space:]]|$)" "$MODDIR/tmp/hosts.content" > "$MODDIR/tmp/matched.tmp" || true
                
                # 记录匹配的域名
                if [ -s "$MODDIR/tmp/matched.tmp" ]; then
                    echo "规则 \"$pattern\" 匹配以下域名:" >> "$WHITELIST_LOG"
                    while read -r matched_line; do
                        domain=$(echo "$matched_line" | tr -s ' \t' ' ' | cut -d ' ' -f2)
                        echo "  - $domain" >> "$WHITELIST_LOG"
                    done < "$MODDIR/tmp/matched.tmp"
                    echo "" >> "$WHITELIST_LOG"
                fi
                
                # 从内容文件中移除匹配的行
                if [ -s "$MODDIR/tmp/matched.tmp" ]; then
                    grep -v -f "$MODDIR/tmp/matched.tmp" "$MODDIR/tmp/hosts.content" > "$MODDIR/tmp/hosts.filtered"
                    mv "$MODDIR/tmp/hosts.filtered" "$MODDIR/tmp/hosts.content"
                fi
            done < "$MODDIR/tmp/valid_rules.txt"
            
            # 合并过滤后的内容
            cat "$MODDIR/tmp/hosts.content" >> "$TEMP_FILE"
            
            # 计算过滤的行数
            original_count=$(grep -v -E "^[[:space:]]*#|^[[:space:]]*$" "$MODDIR/tmp/hosts.original" | wc -l)
            filtered_count=$(grep -v -E "^[[:space:]]*#|^[[:space:]]*$" "$TEMP_FILE" | wc -l)
            matched_count=$((original_count - filtered_count))
            
            if [ -s "$TEMP_FILE" ]; then
                mv "$TEMP_FILE" "$HOSTS_FILE"
                log "success" "白名单处理完成: 共过滤了 $matched_count 个域名"
                echo "----------------------------------------" >> "$WHITELIST_LOG"
                echo "白名单处理完成: 共过滤了 $matched_count 个域名" >> "$WHITELIST_LOG"
            else
                log "warning" "白名单处理后文件为空，保留原始hosts文件"
                echo "白名单处理后文件为空，保留原始hosts文件" >> "$WHITELIST_LOG"
            fi
        else
            log "notice" "白名单规则为空，保留原始hosts文件"
        fi
        
        # 清理临时文件
        rm -f "$MODDIR/tmp/valid_rules.txt" "$MODDIR/tmp/hosts.original" "$MODDIR/tmp/hosts.content" "$MODDIR/tmp/matched.tmp"
    else
        log "notice" "未找到白名单文件"
    fi


    

    # 导入自定义Hosts
    if [ -f "$MODDIR/自定义Host.conf" ]; then
        cat "$MODDIR/自定义Host.conf" >> "$HOSTS_FILE"
        log "success" "导入自定义Hosts成功"
    else
        log "notice" "未找到自定义Host文件"
    fi

    # 更新规则数量
    if [ -f "$HOSTS_FILE" ]; then
        HOSTS_LINE_COUNT=$(wc -l < "$HOSTS_FILE")
        BASE_DESCRIPTION=$(grep "description=" "$MODDIR/module.prop" | sed 's/description=\(.*\)当前规则数量 [0-9]*/\1/')
        
        if [ -z "$BASE_DESCRIPTION" ]; then
            BASE_DESCRIPTION=$(grep "description=" "$MODDIR/module.prop" | sed 's/description=\(.*\)/\1 /')
        fi
        
        sed -i "s/description=.*/description=${BASE_DESCRIPTION}当前规则数量 $HOSTS_LINE_COUNT/" "$MODDIR/module.prop"
        log "success" "更新规则数量为 $HOSTS_LINE_COUNT"
    else
        log "error" "hosts文件不存在，无法更新规则数量"
    fi
  
    # 挂载hosts
    log "info" "正在挂载hosts...挂载成功后无需重启"
    
    # 保存当前目录以便后续检查
    local mount_result=0
    local system_host="/system/etc/hosts"
    
    # 查找实际的系统hosts文件位置
    if [ ! -f "$system_host" ]; then
        local possible_hosts="/system/etc/hosts /system_ext/etc/hosts /vendor/etc/hosts /product/etc/hosts"
        for file in $possible_hosts; do
            if [ -f "$file" ]; then
                case "$file" in
                    /system_ext* | /vendor* | /product*)
                        system_host="/system${file}"
                        break
                        ;;
                    /system*)
                        system_host="${file}"
                        break
                        ;;
                esac
            fi
        done
    fi
    
    # 执行挂载操作
    mount_set_perm_for_hosts "${HOSTS_FILE}"
    mount_result=$?
    
    # 验证挂载是否成功
    if [ $mount_result -eq 0 ]; then
        # 进一步验证挂载是否成功
        if grep -q "$(head -n 1 "${HOSTS_FILE}")" "$system_host" 2>/dev/null; then
            log "success" "挂载成功! 系统hosts文件已更新"
        else
            log "warning" "挂载可能未成功，无法验证hosts文件内容"
            # 尝试重新挂载
            log "info" "尝试重新挂载..."
            umount "$system_host" 2>/dev/null
            mount --bind "${HOSTS_FILE}" "$system_host"
            if [ $? -eq 0 ] && grep -q "$(head -n 1 "${HOSTS_FILE}")" "$system_host" 2>/dev/null; then
                log "success" "重新挂载成功!"
            else
                log "error" "挂载失败，请检查权限或系统状态"
            fi
        fi
    else
        log "error" "挂载命令执行失败，错误代码: $mount_result"
    fi
    
    # 清理临时文件
    rm -rf "$MODDIR/tmp"
    log "info" "脚本执行完成"
}

# 执行主函数
main
