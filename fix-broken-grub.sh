#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root权限运行此脚本。使用 sudo ./manage_grub.sh"
  exit 1
fi

# 确定GRUB配置文件路径
if [ -d /sys/firmware/efi ]; then
  echo "检测到 UEFI 系统。"

  # 获取 /boot/efi/EFI/ 目录下的所有子目录，排除 BOOT
  EFI_DIR="/boot/efi/EFI"
  GRUB_CFG=""
  GRUB_DIR=""

  echo "正在查找 GRUB 配置文件..."

  for dir in "$EFI_DIR"/*/; do
    # 排除 BOOT 目录
    if [[ "$dir" == *"BOOT"* ]]; then
      continue
    fi

    # 检查 grub.cfg 是否存在于子目录
    if [ -f "${dir}grub.cfg" ]; then
      # 解析 grub.cfg 以找到实际的配置文件
      # 读取 grub.cfg 中的 configfile 行
      configfile_line=$(grep "^configfile " "${dir}grub.cfg" | head -n 1)
      if [[ "$configfile_line" =~ configfile\ ([^[:space:]]+) ]]; then
        actual_grub_cfg="${BASH_REMATCH[1]}"
        # 处理相对路径
        if [[ "$actual_grub_cfg" != /* ]]; then
          actual_grub_cfg="${dir}${actual_grub_cfg}"
        fi
        if [ -f "$actual_grub_cfg" ]; then
          GRUB_CFG="$actual_grub_cfg"
          GRUB_DIR=$(basename "$dir")
          echo "找到实际的 GRUB 配置文件：$GRUB_CFG （目录：$GRUB_DIR）"
          break
        fi
      fi
    fi
  done

  # 如果未找到，尝试手动指定路径
  if [ -z "$GRUB_CFG" ]; then
    # 检查常见路径
    COMMON_PATHS=(
      "/boot/grub2/grub.cfg"
      "/boot/efi/EFI/fedora/grub2/grub.cfg"
      "/boot/efi/EFI/BOOT/grub.cfg"
    )

    for path in "${COMMON_PATHS[@]}"; do
      if [ -f "$path" ]; then
        GRUB_CFG="$path"
        GRUB_DIR=$(basename "$(dirname "$path")")
        echo "手动指定找到 GRUB 配置文件：$GRUB_CFG （目录：$GRUB_DIR）"
        break
      fi
    done
  fi

  if [ -z "$GRUB_CFG" ]; then
    echo "未找到包含 menuentry 的实际 GRUB 配置文件。请手动查找并指定。"
    exit 1
  fi
else
  GRUB_CFG="/boot/grub2/grub.cfg"
  echo "检测到 BIOS 系统。使用 $GRUB_CFG 作为 GRUB 配置文件。"
fi

if [ ! -f "$GRUB_CFG" ]; then
  echo "无法找到 GRUB 配置文件：$GRUB_CFG"
  exit 1
fi

echo "当前系统的 GRUB 启动项如下："
echo "-----------------------------------"

# 解析 GRUB 配置文件，提取菜单项
mapfile -t entries < <(grep "^menuentry '" "$GRUB_CFG" | cut -d"'" -f2)

# 检查是否找到启动项
if [ ${#entries[@]} -eq 0 ]; then
  echo "未在 $GRUB_CFG 中找到任何启动项。"
  exit 1
fi

# 显示启动项列表
for i in "${!entries[@]}"; do
  echo "[$i] ${entries[$i]}"
done

echo "-----------------------------------"
echo "请输入要删除的启动项编号（或按 'q' 退出）："
read -r choice

# 检查用户是否选择退出
if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
  echo "已退出。"
  exit 0
fi

# 验证输入是否为有效的数字
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
  echo "无效的输入。请输入有效的编号。"
  exit 1
fi

# 检查编号是否在范围内
if [ "$choice" -lt 0 ] || [ "$choice" -ge "${#entries[@]}" ]; then
  echo "编号超出范围。"
  exit 1
fi

selected_entry="${entries[$choice]}"
echo "您选择删除的启动项是：$selected_entry"

# 确认删除操作
echo "您确定要删除此启动项吗？（y/N）："
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "已取消删除操作。"
  exit 0
fi

# 判断启动项类型并执行相应的删除操作
if [[ "$selected_entry" == *"系统备份"* || "$selected_entry" == *"snapshot"* ]]; then
  echo "检测到该启动项可能对应一个系统快照。尝试删除相关快照。"

  # 检查是否安装了 Timeshift
  if command -v timeshift >/dev/null 2>&1; then
    echo "使用 Timeshift 删除快照。"
    # 列出所有快照
    timeshift --list

    echo "请输入要删除的快照名称（例如：2024-04-27_12-00）："
    read -r snapshot_name

    # 删除指定快照
    timeshift --delete --snapshot "$snapshot_name"

    if [ $? -eq 0 ]; then
      echo "快照 '$snapshot_name' 已成功删除。"
    else
      echo "删除快照失败，请检查输入是否正确或是否有足够权限。"
      exit 1
    fi
  else
    echo "系统快照工具（如 Timeshift）未安装。请手动删除相关快照。"
    exit 1
  fi
elif [[ "$selected_entry" == Rocky* || "$selected_entry" == Fedora* ]]; then
  echo "检测到该启动项可能对应一个内核版本或系统实例。尝试删除相关内核或系统快照。"

  # 列出所有已安装的内核
  echo "已安装的内核版本："
  rpm -q kernel

  echo "请输入要删除的内核版本（例如：kernel-5.14.0-1.el8.x86_64）："
  read -r kernel_version

  # 确认内核版本是否存在
  if rpm -q "$kernel_version" >/dev/null 2>&1; then
    # 防止删除当前正在使用的内核
    current_kernel=$(uname -r)
    if [[ "$kernel_version" == *"$current_kernel"* ]]; then
      echo "无法删除当前正在使用的内核版本。请先切换到其他内核。"
      exit 1
    fi

    # 删除指定内核
    dnf remove -y "$kernel_version"

    if [ $? -eq 0 ]; then
      echo "内核 '$kernel_version' 已成功删除。"
    else
      echo "删除内核失败，请检查输入是否正确或是否有足够权限。"
      exit 1
    fi
  else
    echo "指定的内核版本未找到。"
    exit 1
  fi
else
  echo "无法识别启动项类型。请手动删除相关启动项。"
  exit 1
fi

# 更新 GRUB 配置
echo "正在更新 GRUB 配置..."
if [ -d /sys/firmware/efi ]; then
  # UEFI 系统
  if [ -d "/boot/efi/EFI/$GRUB_DIR" ]; then
    grub2-mkconfig -o "/boot/efi/EFI/$GRUB_DIR/grub.cfg"
  else
    echo "无法找到 GRUB 目录：/boot/efi/EFI/$GRUB_DIR"
    exit 1
  fi
else
  # BIOS 系统
  grub2-mkconfig -o /boot/grub2/grub.cfg
fi

if [ $? -eq 0 ]; then
  echo "GRUB 配置已成功更新。"
else
  echo "更新 GRUB 配置失败。请检查错误信息。"
  exit 1
fi

echo "删除操作完成。请重启系统以应用更改。"
