#!/usr/bin/env bash

# 在UEFI下重建Rocky Linux的GRUB引导配置脚本示例

# 1. 设置目标GRUB配置文件路径
GRUB_CFG_PATH="/boot/efi/EFI/rocky/grub.cfg"

# 2. 显示当前内核和grub配置信息
echo "当前内核列表："
rpm -qa | grep kernel

echo "当前grub配置文件位置：$GRUB_CFG_PATH"

# 3. 备份现有的grub配置文件
if [ -f "$GRUB_CFG_PATH" ]; then
    echo "为安全起见，备份当前grub配置文件为grub.cfg.bak"
    sudo cp "$GRUB_CFG_PATH" "${GRUB_CFG_PATH}.bak"
fi

# 4. 清理无需的旧内核（根据实际情况自行决定）
# 假设要删除特定老旧版本的内核，请将其写入变量OLD_KERNEL
# 示例：OLD_KERNEL="kernel-5.14.0-100.el9.x86_64"
OLD_KERNEL=""
if [ -n "$OLD_KERNEL" ]; then
    echo "删除旧内核：$OLD_KERNEL"
    sudo dnf remove -y $OLD_KERNEL
fi

# 5. 重新生成grub配置文件
echo "正在重新生成grub配置..."
sudo grub2-mkconfig -o "$GRUB_CFG_PATH"

# 6. 重启提示
echo "grub配置已重新生成。请重启系统以测试引导项是否已恢复正常。"
echo "执行：sudo reboot"
