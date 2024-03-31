#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOXDIR=$MODDIR/busybox
Config=$MODDIR/config.json
HOSTS_FILE="$MODDIR/system/etc/hosts"
TEMP_FILE="$MODDIR/tmp/temp.txt"
export PATH=/system/bin:$BUSYBOXDIR:$PATH

counter=0



start() {
    echo "" > "$MODDIR/log.txt"
    echo "" > "$HOSTS_FILE"
    chmod +x "$MODDIR/tool.sh"
    chmod 777 $MODDIR/system/etc/hosts
    chmod 777 $Config
    chmod +x $BUSYBOXDIR/jq
    chmod +x $BUSYBOXDIR/wget
}
start

# 等待开机完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 30
    echo "wait: 等待开机" >> "$MODDIR/log.txt"
done
echo "success: 开机成功" >> "$MODDIR/log.txt"

# 等待联网
echo "wait: 等待联网" >> "$MODDIR/log.txt"
PING_ADDRESS=baidu.com
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
            sleep 5
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
    cat "$MODDIR/自定义Host.conf" >> $HOSTS_FILE
    echo "success: 导入自定义Hosts成功" >> "$MODDIR/log.txt"
    HOSTS_LINE_COUNT=$(wc -l < "$HOSTS_FILE")
    sed -i "s/{math}/$HOSTS_LINE_COUNT/g" "$MODDIR/module.prop"
}

main