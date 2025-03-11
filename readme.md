# switchHost for Magisk

这是一个 Magisk 模块，用于帮助你更方便地管理多个 hosts 文件。
你能用他导入本地 hosts 文件，也可以订阅如 github520 等的 hosts 源，并自动更新。

## how to use

- 安装模块，后重启手机，即可使用，模块内置 10007 大佬的去广告 Hosts和github520 的 hosts 源。
- 如有需要，可以通过 tool.sh 增删 hosts 源。
- 每天晚上12点会自动更新，并且更新后会自动挂载，无需重启。

## Todo

- 使用Zygisk实现指定应用关闭hosts
- 自己维护一个加速规则（暂时没精力，准备高考）
