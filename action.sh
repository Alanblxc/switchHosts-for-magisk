#!/system/bin/sh

MODDIR=${0%/*}
BUSYBOXDIR=$MODDIR/busybox
target_hosts_file="${0%/*}/system/etc/hosts"
flag_file="${0%/*}/allow_flag"
export BUSYBOX="$BUSYBOXDIR"

function set_perm() {
  chown -R $2:$3 "${1}" >/dev/null 2>&1
  chmod -R $4 "${1}" >/dev/null 2>&1
  local CON=$5
  [ -z $CON ] && CON=u:object_r:system_file:s0
  chcon -R $CON "${1}" >/dev/null 2>&1
}
function mount_set_perm_for_hosts(){
local target_file="${1}"
test ! -f "${target_file}" && return
local system_host="/system/etc/hosts"
if test ! -f "${system_host}" ;then
  # 使用空格分隔的字符串来定义可能的hosts文件位置
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
local perm_hosts="$($BUSYBOX stat -c '%U %G %a' ${system_host} 2>/dev/null)"
local selinux_context="$($BUSYBOX stat -Z ${system_host} 2>/dev/null | grep -i 'S_Context:' | sed 's/.*u:/u:/g')"
test "${selinux_context}" = "" && selinux_context="u:object_r:system_file:s0"
set_perm "${target_file%/*}" ${perm_hosts} "${selinux_context}" >/dev/null 2>&1
umount "${system_host}" >/dev/null 2>&1
mount --bind "${target_file}" "${system_host}" >/dev/null 2>&1
}

main(){
recovery_file="${0%/*}/mod/recovery"
module_description_file="${0%/*}/module.prop"
[[ ! -f "${module_description_file%/*}/backup.prop" ]] && cp -rf "${module_description_file}" "${module_description_file%/*}/backup.prop"
[[ ! -f "$recovery_file" ]] && {
mkdir -p "${recovery_file%/*}"
echo -e "127.0.0.1	localhost\n::1	localhost" > "$recovery_file"
}

if [[ ! -f "${flag_file}" ]];then
	echo "恢复hosts……"
	touch "${flag_file}"
	mount_set_perm_for_hosts "${recovery_file}"
	sed -i 's/description=.*/description=已经临时禁用模块hosts，使用系统hosts，点击模块Action(操作)可以切换/g' "${module_description_file}"
	echo "完成！"
else
	echo "使用模块hosts……"
	rm -rf "${flag_file}"
	mount_set_perm_for_hosts "${target_hosts_file}"
	cp -rf "${module_description_file%/*}/backup.prop" "${module_description_file}"
	echo "完成！"
	rm -rf "${module_description_file%/*}/backup.prop"
fi
}

if [[ "$1" != "-i" ]]; then
  main
fi
