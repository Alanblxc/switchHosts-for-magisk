#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOXDIR=$MODDIR/busybox
Config=$MODDIR/config.json
HOSTS_FILE="$MODDIR/system/etc/hosts"
TEMP_FILE="$MODDIR/tmp/temp.txt"
export PATH=/system/bin:$BUSYBOXDIR:$PATH
. "$MODDIR/action.sh" "-i"

counter=0

start() {
    EXECUTABLE_FILES="$MODDIR/tool.sh $BUSYBOXDIR/jq $BUSYBOXDIR/wget $BUSYBOXDIR/crond $Config"
    echo "" > "$MODDIR/log.txt"
    echo "" > "$HOSTS_FILE"
    mkdir -p "$MODDIR/tmp"
    chmod 666 "$MODDIR/system/etc/hosts"
    for file in $EXECUTABLE_FILES; do
        if [ -f "$file" ]; then
            chmod 755 "$file"
        fi
    done
    mkdir -p $MODDIR/cron.d
    echo "0 0 * * * $MODDIR/service.sh" > $MODDIR/cron.d/root
    chmod 600 $MODDIR/cron.d/root
    crond -c $MODDIR/cron.d
    
}
start

# 等待开机完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 40
    echo "wait: 等待开机" >> "$MODDIR/log.txt"
done
echo "success: 开机成功" >> "$MODDIR/log.txt"

# 等待联网
echo "wait: 等待联网" >> "$MODDIR/log.txt"
PING_ADDRESS=www.baidu.com
while true; do
    if ping -c 1 $PING_ADDRESS > /dev/null 2>&1; then
        echo "success: 联网成功" >> "$MODDIR/log.txt"
        break
    else
        echo "fail: 联网失败，正在重试..." >> "$MODDIR/log.txt"
        sleep 5
    fi
done

echo "wait: 等待配置读取" >> "$MODDIR/log.txt"

read_config() {
    echo "wait: 读取配置文件中" >> "$MODDIR/log.txt"
    jq -r '.[].name' $Config | while read -r name; do
        cat "$MODDIR/mod/$name.conf" >> "$HOSTS_FILE"
        counter=$(($counter + 1))
    done
    echo "success: 读取配置文件成功" >> "$MODDIR/log.txt"
    counter=0
}

update() {
    local index=$1
    local name=$2
    local url=$(jq -r ".[$index].url" "$Config")
    local retries=3
    local count=0
    
    while [ $count -lt $retries ]; do
        if wget -q --spider "$url"; then
            echo "文件 $url 正常" >> "$MODDIR/log.txt"
            wget -O "$MODDIR/mod/$name.conf" "$url"
            echo "success: 更新了 $name" >> "$MODDIR/log.txt"
            return 0
        else
            echo "fail: $url 无法访问，正在重试... $(($count + 1))/$retries)" >> "$MODDIR/log.txt"
            count=$(($count + 1))
            sleep 3
        fi
    done
    
    echo "error: $name 更新失败。已经重试 $retries 次，无法访问 $url" >> "$MODDIR/log.txt"
}

check_update() {
    local count=$(jq '. | length' "$Config")
    local i=0
    
    while [ $i -lt $count ]; do
        local update=$(jq -r ".[$i].update" "$Config")
        local name=$(jq -r ".[$i].name" "$Config")
        
        if [ "$update" = "true" ]; then
            update $i "$name"
        fi
        i=$(($i + 1))
    done
}

main() {
    check_update
    read_config
    sort $HOSTS_FILE | uniq > $TEMP_FILE && mv $TEMP_FILE $HOSTS_FILE
    echo "success: 去重成功" >> "$MODDIR/log.txt"

    if [ -f "$MODDIR/白名单.conf" ]; then
        echo "info: 找到白名单文件" >> "$MODDIR/log.txt"
        while IFS= read -r line || [ -n "$line" ]; do
            # 去除行首尾的空白字符
            line=$(echo "$line" | xargs)
            
            # 跳过空行和注释行
            if [ -z "$line" ] || [[ "$line" == \#* ]]; then
                continue
            fi
            
            domain="$line"
            echo "info: 正在处理域名: $domain" >> "$MODDIR/log.txt"
            
            # 检查域名是否存在于hosts文件中
            if grep -q "$domain" "$HOSTS_FILE"; then
                # 域名存在，执行删除操作
                grep -v "$domain" "$HOSTS_FILE" > "$HOSTS_FILE.tmp"
                mv "$HOSTS_FILE.tmp" "$HOSTS_FILE"
                
                # 再次检查是否删除成功
                if grep -q "$domain" "$HOSTS_FILE"; then
                    echo "warning: 域名 $domain 可能未被完全删除" >> "$MODDIR/log.txt"
                else
                    echo "success: 成功删除域名" >> "$MODDIR/log.txt"
                fi
            else
                # 域名不存在，输出未找到的信息
                echo "notice: 未能找到域名" >> "$MODDIR/log.txt"
            fi
        done < "$MODDIR/白名单.conf"
        echo "success: 白名单处理完成" >> "$MODDIR/log.txt"
    else
        echo "warning: 未找到白名单文件" >> "$MODDIR/log.txt"
    fi


    cat "$MODDIR/自定义Host.conf" >> $HOSTS_FILE
    echo "success: 导入自定义Hosts成功" >> "$MODDIR/log.txt"


    HOSTS_LINE_COUNT=$(wc -l < "$HOSTS_FILE")
    
    BASE_DESCRIPTION=$(grep "description=" "$MODDIR/module.prop" | sed 's/description=\(.*\)当前规则数量 [0-9]*/\1/')
    
    sed -i "s/description=.*/description=${BASE_DESCRIPTION}当前规则数量 $HOSTS_LINE_COUNT/" "$MODDIR/module.prop"
    
    echo "success: 更新规则数量为 $HOSTS_LINE_COUNT" >> "$MODDIR/log.txt"
    
    echo "info: 正在挂载hosts...挂载成功后无需重启" >> "$MODDIR/log.txt"
    mount_set_perm_for_hosts "${HOSTS_FILE}"
    echo "success: 挂载成功!" >> "$MODDIR/log.txt"
    rm -r "$MODDIR/tmp"
}

main