#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOXDIR=$MODDIR/busybox
Config=$MODDIR/config.json
HOSTS_FILE="$MODDIR/system/etc/hosts"
TEMP_FILE="$MODDIR/tmp/temp.txt"
export PATH=/system/bin:$BUSYBOXDIR:$PATH

counter=0

chmod 777 $HOSTS_FILE
chmod 777 $Config
chmod +x $BUSYBOXDIR/jq
chmod +x $BUSYBOXDIR/wget


start(){
    echo "" > "$MODDIR/log.txt"
    echo "" > "$HOSTS_FILE"
}
start

while [[ "$(getprop sys.boot_completed)" != "1" ]]; do
  sleep 30
  echo "等待开机" >> "$MODDIR/log.txt"
done

echo "success: 开机成功" >> "$MODDIR/log.txt"
echo "等待联网" >> "$MODDIR/log.txt"

# 指定联网检测的地址
PING_ADDRESS=baidu.com

# 无限循环直到能够ping通指定地址
while true; do
    # ping 指定地址一次，-c 1 表示发送一个数据包
    ping -c 1 $PING_ADDRESS > /dev/null 2>&1

    # 检查上条 ping 命令的退出状态
    if [ $? -eq 0 ]; then
        echo "success: 联网成功！" >> "$MODDIR/log.txt"
        break
    else
        echo "fail: 联网失败，正在重试..." >> "$MODDIR/log.txt"
        sleep 5
    fi
done

main(){
    check_update
    read_config
    echo "success: 读取配置成功,更新成功" >> "$MODDIR/log.txt"
    #去重
    sort $HOSTS_FILE | uniq > $MODDIR/system/etc/temp.txt && mv $MODDIR/system/etc/temp.txt $HOSTS_FILE  
    echo "success: 去重成功" >> "$MODDIR/log.txt"
    # whitelist
    # echo "success: 排除白名单成功"
    cat "$MODDIR/自定义Host.conf" >> $HOSTS_FILE
    echo "success: 导入自定义Hosts成功" >> "$MODDIR/log.txt"
}

read_config(){
    jq -r '.[].name' $Config | while read -r name; do
    cat "$MODDIR/mod/$name.conf" >> "$HOSTS_FILE"
    ((counter++))
done
counter=0
}

check_update(){
    jq -r '.[].name' $Config | while read -r name; do
    first_line_update=$(jq -r ".[$counter].update" $Config)
    if [[ "$first_line_update" == "true" ]]; then
        update $counter
    fi
    ((counter++))
done
counter=0
}

update(){
   url=$(jq -r --argjson line "$1" '.[$line].url' $Config)
   if wget -q --spider $url; then
       echo "文件 $url 正常" >> "$MODDIR/log.txt"
       rm "$MODDIR/mod/$name.conf"
       wget -qO- "$url" >> "$MODDIR/mod/$name.conf"
       echo "sucess: 第$(($1+1))条"
   else
       echo "fail: $url 无法访问" >> "$MODDIR/log.txt"
   fi
   url=""
}

whitelist(){
    rm $TEMP_FILE
    # 当前HOSTS_FILE的拷贝，用于读取
    cp $HOSTS_FILE $TEMP_FILE

    # 逐行读取原始的 HOSTS_FILE 内容
    while IFS= read -r line
    do
    # 删除 TEMP_FILE 中与当前行相同的行
    grep -v -- "$line" $TEMP_FILE > $TEMP_FILE.tmp && mv $TEMP_FILE.tmp $TEMP_FILE
    done < $HOSTS_FILE

    # 将最终结果写回原始 HOSTS_FILE
    mv $TEMP_FILE $HOSTS_FILE
}

main