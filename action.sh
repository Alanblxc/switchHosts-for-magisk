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
# 检查目标文件是否存在
if test ! -f "${target_file}"; then
  return 1
fi

local system_host="/system/etc/hosts"
if test ! -f "${system_host}" ;then
  # 使用空格分隔的字符串来定义可能的hosts文件位置
 # local possible_hosts="/system/etc/hosts /system_ext/etc/hosts /vendor/etc/hosts /product/etc/hosts" 
 local possible_hosts="/system/etc/hosts"
  local found=0
  
  for file in $possible_hosts; do
    if [ -f "$file" ]; then
      case "$file" in
        /system_ext* | /vendor* | /product*)
          system_host="/system${file}"
          found=1
          break
          ;;
        /system*)
          system_host="${file}"
          found=1
          break
          ;;
      esac
    fi
  done
  
  # 如果没有找到系统hosts文件，返回错误
  if [ $found -eq 0 ]; then
    return 2
  fi
fi

# 获取权限信息
local perm_hosts=""

# 尝试使用busybox stat命令获取权限
perm_hosts="$($BUSYBOX stat -c '%U %G %a' ${system_host} 2>/dev/null)"

# 如果busybox stat失败，尝试使用ls命令获取权限
if [ -z "$perm_hosts" ]; then
  perm_hosts="$($BUSYBOX ls -ln ${system_host} 2>/dev/null | awk '{print $3, $4, substr($1,2)}')"
fi

# 如果仍然失败，使用默认权限
if [ -z "$perm_hosts" ]; then
  perm_hosts="root root 644"
fi

# 获取SELinux上下文
local selinux_context="$($BUSYBOX stat -Z ${system_host} 2>/dev/null | grep -i 'S_Context:' | sed 's/.*u:/u:/g')"
test "${selinux_context}" = "" && selinux_context="u:object_r:system_file:s0"

# 设置权限
set_perm "${target_file%/*}" ${perm_hosts} "${selinux_context}" >/dev/null 2>&1
local perm_result=$?
if [ $perm_result -ne 0 ]; then
  return 4
fi

# 卸载旧的挂载点
umount "${system_host}" >/dev/null 2>&1

# 挂载新的hosts文件
mount --bind "${target_file}" "${system_host}" >/dev/null 2>&1
local mount_result=$?
if [ $mount_result -ne 0 ]; then
  return 5
fi

# 验证挂载是否成功
if ! grep -q "$(head -n 1 "${target_file}")" "$system_host" 2>/dev/null; then
  return 6
fi

# 所有检查都通过，返回成功
return 0
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
