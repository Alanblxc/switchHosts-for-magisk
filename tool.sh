#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOXDIR=$MODDIR/busybox
Config=$MODDIR/config.json
export PATH=/system/bin:$BUSYBOXDIR:$PATH

# 验证 JSON 文件是否有效
if ! jq empty $Config > /dev/null 2>&1; then
    echo "JSON文件格式错误，无法继续。"
    exit 1
fi

# 添加配置项函数
add_config() {
    while true; do
        echo -n "请输入新的host文件名称："
        read name

        # 校验输入的名称是否已经存在
        if jq --arg name "$name" '.[] | select(.name == $name)' $Config | grep -q "$name"; then
            echo "配置名称 '$name' 已经存在，请输入一个新的名称。"
            # 继续循环，请求新输入
            continue
        else
            # 如果配置名称不存在，跳出循环
            break
        fi
    done

    echo -n "是否是在线文件？ (y/n)："
    read online

    url=""
    update=false
    if [ "$online" = "y" ]; then
        update=true
        echo -n "请输入在线host文件地址："
        read url
    fi
 
    if [ "$online" = "n" ]; then
        echo "请将同名文件复制到mod目录下。"
    else
        wget --spider -q "$url"

        if [ $? -eq 0 ]; then
            echo "URL可连通。"
        else
            echo "无法连接到URL: $url，请检查URL是否正确。"
        fi
    fi

    # 构建要添加的json内容
    new_entry="{\"name\":\"$name\",\"update\":$update,\"url\":\"$url\"}"

    # 使用jq命令添加到Config指向的config.json文件中
    current_content=$(cat $Config)
    echo $current_content | jq --argjson entry "$new_entry" '. += [$entry]' > $Config.new

    if [ $? -eq 0 ]; then
        mv $Config.new $Config
        echo "新的配置项已添加到 $Config。"
    else
        echo "在添加新的配置项时发生错误。"
        rm $Config.new
    fi
}

# 删除配置项函数
delete_config() {
    echo "输入 'q' 退出"
    while true; do
        echo "以下是目前所有的配置项名称："
        jq -r '.[].name' $Config

        echo -n "请输入要删除的配置项名称："
        read name

        if [ "$name" = "q" ]; then
            echo "退出删除配置项操作。"
            return
        fi

        # 判断输入的配置项名称是否存在
        name_exists=$(jq --arg name "$name" '.[] | select(.name == $name) | .name' $Config)

        if [ -z "$name_exists" ]; then
            echo "配置项名称 '$name' 不存在，请重新输入。"
            # 如果不存在就继续循环
            continue
        else
            # 如果存在，删除配置项
            jq --arg name "$name" '. |= map(select(.name != $name))' $Config > $Config.new

            if [ $? -eq 0 ]; then
                mv $Config.new $Config
                echo "配置项 '$name' 已从 $Config 删除。"
            else
                echo "在删除配置项时发生错误。"
                rm $Config.new
                return
            fi
        fi
    done
}

main() {
    echo -n "[A]添加配置 或者 [D]删除配置？ (A/D)："
    read action

    case "$action" in
        [Aa]* )
            add_config
            ;;
        [Dd]* )
            delete_config
            ;;
        * )
            echo "无效的选项。"
            exit 1
            ;;
    esac
}

# 调用main函数
main