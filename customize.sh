# info
MODVER=`grep_prop version $MODPATH/module.prop`
MODVERCODE=`grep_prop versionCode $MODPATH/module.prop`
ui_print " "
ui_print " Version=$MODVER"
ui_print " MagiskVersion=$MAGISK_VER"
ui_print " "
ui_print " SwitchHosts for android"
ui_print " By Alan"
ui_print " "
ui_print " 正在设置权限"
ui_print " "

sleep 3

chmod -R 0755 $MODPATH/busybox
chmod 777 $MODDIR/system/etc/hosts
chmod 777 $Config
chmod +x $BUSYBOXDIR/jq
chmod +x $BUSYBOXDIR/wget
chmod +x $MODPATH/tool.sh

sleep 3

ui_print " "
ui_print " 设置权限成功"
ui_print " "