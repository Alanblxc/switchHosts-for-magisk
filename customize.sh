# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " "
ui_print " Version=$MODVER"
ui_print " MagiskVersion=$MAGISK_VER"
ui_print " "
ui_print " SwitchHosts for Android"
ui_print " By Alan"
ui_print " "

add_config(){
    ui_print " "
    ui_print " 是否安装额外去广告配置（规则过多可能影响网速）"
    ui_print " "
    ui_print " 音量键 + 安装"
    ui_print " 音量键 - 不安装"
        while [ "$key_click_7" = "" ]; do
        key_click_7=$(getevent -qlc 1 | awk '{ print $3 }' | grep 'KEY_')
    sleep 0.2
    done
    case $key_click_7 in
    KEY_VOLUMEUP)
        echo '[
  {
    "name": "github520",
    "update": true,
    "url": "https://raw.hellogithub.com/hosts"
  },
  {
    "name": "10007",
    "update": true,
    "url": "https://raw.gitmirror.com/lingeringsound/10007_auto/master/all"
  },
  {
    "name": "AdAway 官方 hosts",
    "update": true,
    "url": "https://adaway.org/hosts.txt"
  },
  {
    "name": "Pete Lowe blocklist hosts",
    "update": true,
    "url": "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
  },
  {
    "name": "StevenBlack Unified hosts",
    "update": true,
    "url": "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  }
]
' > $MODPATH/config.json
        ui_print " "
        ui_print "--已安装adaway配置--"
        ui_print " "
        ;;
    *)
        ui_print " "
        ui_print "--已取消--"
        ui_print " "
        ;;
    esac
}

ad_hold(){
    key_click_7=""
    ui_print " "
    ui_print " 是否保留广告奖励（去除广告效果减弱）"
    ui_print " "
    ui_print " 音量键 + 保留"
    ui_print " 音量键 - 不保留"

    while [ "$key_click_7" = "" ]; do
        key_click_7=$(getevent -qlc 1 | awk '{ print $3 }' | grep 'KEY_')
    sleep 0.2
    done
    case $key_click_7 in
    KEY_VOLUMEUP)
    echo '[
    {
        "name": "github520",
        "update": true,
        "url": "https://raw.hellogithub.com/hosts"
    },
    {
        "name": "10007",
        "update": true,
        "url": "https://raw.gitmirror.com/lingeringsound/10007_auto/master/reward"
    }
]
    ' > $MODPATH/config.json
        ui_print " "
        ui_print "--已保留广告奖励--"
        ui_print "--请重启后等更新完成后再次重启--"
        ui_print " "
        ;;
    *)
        ui_print " "
        ui_print "--已取消--"
        ui_print " "
        ;;
    esac

}

check_update_f(){
    key_click_7=""
    ui_print " "
    ui_print " 是否检查更新配置文件"
    ui_print " "
    ui_print " 音量键 + 更新"
    ui_print " 音量键 - 不更新"

    while [ "$key_click_7" = "" ]; do
        key_click_7=$(getevent -qlc 1 | awk '{ print $3 }' | grep 'KEY_')
    sleep 0.2
    done
    case $key_click_7 in
    KEY_VOLUMEUP)
        ui_print "--更新配置文件--"
        source $MODPATH/service.sh
        ;;
    *)
        ui_print "--已取消--"
        ;;
    esac

}

add_config

sleep 3

ad_hold

sleep 3

#check_update_f