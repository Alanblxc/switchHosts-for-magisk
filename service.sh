#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOXDIR=$MODDIR/busybox
Config=$MODDIR/config.json
export PATH=/system/bin:$BUSYBOXDIR:$PATH

while [[ "$(getprop sys.boot_completed)" != "1" ]]; do
  sleep 30
done

counter=0

chmod 777 $MODDIR/system/etc/hosts
chmod 777 $Config
chmod +x $BUSYBOXDIR/jq
chmod +x $BUSYBOXDIR/wget

main(){
    echo "" > "$MODDIR/log.txt"
    echo "" > "$MODDIR/system/etc/hosts"
    check_update
    read_config
    echo "success: 读取配置成功,更新成功"
}

read_config(){
    jq -r '.[].name' $Config | while read -r name; do
    cat "$MODDIR/mod/$name.conf" >> "$MODDIR/system/etc/hosts"
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
       echo "URL $url 无法访问" >> "$MODDIR/log.txt"
   fi
}
main