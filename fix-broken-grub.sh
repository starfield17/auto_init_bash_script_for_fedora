#!/bin/bash

# 确保脚本以 root 权限运行
if [[ $EUID -ne 0 ]]; then
   echo "请以 root 权限运行此脚本。"
   exit 1
fi

# 配置变量
GRUB_CFG_PATH="/boot/grub2/grub.cfg"       # BIOS 系统
# GRUB_CFG_PATH="/boot/efi/EFI/rocky/grub.cfg" # UEFI 系统，请根据实际情况取消注释

# 备份当前的 grub.cfg
BACKUP_PATH="/boot/grub2/grub.cfg.backup_$(date +%F_%T)"
cp "$GRUB_CFG_PATH" "$BACKUP_PATH"
if [[ $? -ne 0 ]]; then
    echo "备份 grub.cfg 失败，请检查权限和路径。"
    exit 1
fi
echo "已备份 grub.cfg 至 $BACKUP_PATH"

# 获取所有的 menuentry
mapfile -t MENU_ENTRIES < <(grep "^menuentry" "$GRUB_CFG_PATH" | cut -d "'" -f2)

if [[ ${#MENU_ENTRIES[@]} -eq 0 ]]; then
    echo "未找到任何 GRUB 引导项。"
    exit 1
fi

echo "当前的 GRUB 引导项如下："
echo "----------------------------------"
for i in "${!MENU_ENTRIES[@]}"; do
    echo "$((i+1)). ${MENU_ENTRIES[$i]}"
done
echo "----------------------------------"

# 提示用户输入要删除的引导项编号（支持多个，用空格或逗号分隔）
read -p "请输入要删除的引导项编号（用空格或逗号分隔，按 Enter 跳过）： " INPUT

# 如果用户没有输入，则退出
if [[ -z "$INPUT" ]]; then
    echo "未选择任何引导项，脚本结束。"
    exit 0
fi

# 处理用户输入，将逗号替换为空格，然后转换为数组
INPUT=$(echo "$INPUT" | tr ',' ' ')
read -a DELETE_NUMBERS <<< "$INPUT"

# 声明一个关联数组来存储要删除的引导项
declare -A DELETE_ENTRIES

# 验证输入的编号是否合法
for num in "${DELETE_NUMBERS[@]}"; do
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "无效的编号：$num，请输入数字编号。"
        exit 1
    fi
    if (( num < 1 || num > ${#MENU_ENTRIES[@]} )); then
        echo "编号 $num 超出范围，请输入 1 到 ${#MENU_ENTRIES[@]} 之间的数字。"
        exit 1
    fi
    # 存储要删除的引导项，防止重复
    DELETE_ENTRIES["$num"]=1
done

# 确认删除操作
echo "您选择要删除以下引导项："
for num in "${!DELETE_ENTRIES[@]}"; do
    echo "$num. ${MENU_ENTRIES[$((num-1))]}"
done
read -p "确定要删除这些引导项吗？（y/N）： " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "操作已取消。"
    exit 0
fi

# 遍历要删除的引导项
for num in "${!DELETE_ENTRIES[@]}"; do
    ENTRY="${MENU_ENTRIES[$((num-1))]}"
    echo "正在处理删除引导项：$ENTRY"

    # 判断引导项类型
    if [[ "$ENTRY" == Rocky* ]]; then
        # 假设 Rocky Linux 快照的命名格式为 "Rocky Linux (snapshotX)"
        SNAPSHOT_NAME=$(echo "$ENTRY" | grep -oP '(?<=Rocky Linux ).*')
        # 提取快照名称，去除括号
        SNAPSHOT_NAME=$(echo "$SNAPSHOT_NAME" | tr -d '()')
        
        # 假设使用 Btrfs，且快照位于 /@snapshots 目录下
        SNAPSHOT_PATH="/@snapshots/$SNAPSHOT_NAME"
        
        # 检查快照是否存在
        if sudo btrfs subvolume list / | grep -q "$SNAPSHOT_PATH"; then
            echo "正在删除快照: $SNAPSHOT_PATH"
            sudo btrfs subvolume delete "$SNAPSHOT_PATH"
            if [[ $? -ne 0 ]]; then
                echo "删除快照 $SNAPSHOT_PATH 失败，请手动检查。"
            else
                echo "已删除快照: $SNAPSHOT_PATH"
            fi
        else
            echo "未找到快照 $SNAPSHOT_PATH，请手动检查。"
        fi
    elif [[ "$ENTRY" == Windows* ]]; then
        echo "检测到 Windows 引导项。将从 GRUB 配置中移除该引导项。"
        # 通常，Windows 引导项由 os-prober 自动检测，不建议手动删除
        # 如果确实需要删除，可以禁用 os-prober 或手动编辑 grub.cfg（不推荐）
        echo "请注意，删除 Windows 引导项可能需要进一步配置。建议谨慎操作。"
        # 这里不执行实际删除操作
    else
        echo "未知类型的引导项：$ENTRY。跳过删除。"
    fi
    echo "----------------------------------"
done

# 更新 GRUB 配置
echo "正在更新 GRUB 配置..."
if [[ "$GRUB_CFG_PATH" == "/boot/grub2/grub.cfg" ]]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
elif [[ "$GRUB_CFG_PATH" == "/boot/efi/EFI/rocky/grub.cfg" ]]; then
    grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg
else
    echo "未知的 GRUB 配置路径，请手动更新 GRUB。"
    exit 1
fi

if [[ $? -ne 0 ]]; then
    echo "更新 GRUB 配置失败。"
    exit 1
fi

echo "GRUB 配置已更新。"

# 重启系统提示
echo "操作完成。建议重启系统以应用更改。"
read -p "是否现在重启系统？（y/N）： " REBOOT_CONFIRM
if [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]]; then
    reboot
else
    echo "请手动重启系统以应用更改。"
fi
