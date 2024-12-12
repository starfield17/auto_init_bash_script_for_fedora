#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root权限运行此脚本，例如使用sudo。"
  exit 1
fi

# 获取当前的EFI引导项
BOOT_ENTRIES=$(efibootmgr | grep "^Boot" | grep -v "BootOrder")

# 检查是否有EFI引导项
if [ -z "$BOOT_ENTRIES" ]; then
  echo "未检测到任何EFI引导项。"
  exit 1
fi

# 显示引导项列表
echo "当前的EFI引导项如下："
echo "----------------------------------------"
echo "编号 | 引导编号 | 描述"
echo "----------------------------------------"

# 使用数组存储引导项信息
declare -a ENTRY_ARRAY
INDEX=1

while IFS= read -r line; do
  # 解析引导编号和描述
  BOOT_NUM=$(echo "$line" | awk '{print $1}' | sed 's/Boot\([0-9A-Fa-f]\+\)\*/\1/')
  DESCRIPTION=$(echo "$line" | cut -d '*' -f2 | sed 's/^ *//')
  
  # 跳过当前正在使用的引导项（BootCurrent）
  CURRENT_BOOT=$(efibootmgr | grep "BootCurrent" | awk '{print $2}')
  if [ "$BOOT_NUM" == "$CURRENT_BOOT" ]; then
    echo "$INDEX    | $BOOT_NUM   | $DESCRIPTION (当前使用)"
  else
    echo "$INDEX    | $BOOT_NUM   | $DESCRIPTION"
  fi
  
  # 将引导编号存入数组
  ENTRY_ARRAY+=("$BOOT_NUM|$DESCRIPTION")
  INDEX=$((INDEX + 1))
done <<< "$BOOT_ENTRIES"

echo "----------------------------------------"

# 提示用户输入要删除的引导项编号（用逗号分隔）
echo "请输入要删除的引导项编号（例如：2,4,5），或按Enter跳过："
read -p "输入编号: " INPUT

# 检查用户是否有输入
if [ -z "$INPUT" ]; then
  echo "未选择删除任何引导项。"
  exit 0
fi

# 解析输入的编号
IFS=',' read -ra SELECTION <<< "$INPUT"

# 遍历用户选择的编号并删除对应的引导项
for NUM in "${SELECTION[@]}"; do
  # 去除可能的空格
  NUM=$(echo "$NUM" | tr -d ' ')
  
  # 检查输入是否为数字
  if ! [[ "$NUM" =~ ^[0-9]+$ ]]; then
    echo "无效的编号: $NUM。请确保输入的是数字。"
    continue
  fi
  
  # 检查编号是否在范围内
  if [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#ENTRY_ARRAY[@]}" ]; then
    echo "编号 $NUM 超出范围。"
    continue
  fi
  
  # 获取对应的引导编号和描述
  ENTRY="${ENTRY_ARRAY[$((NUM-1))]}"
  BOOT_NUM=$(echo "$ENTRY" | cut -d '|' -f1)
  DESCRIPTION=$(echo "$ENTRY" | cut -d '|' -f2)
  
  # 检查是否是当前正在使用的引导项
  CURRENT_BOOT=$(efibootmgr | grep "BootCurrent" | awk '{print $2}')
  if [ "$BOOT_NUM" == "$CURRENT_BOOT" ]; then
    echo "跳过删除当前正在使用的引导项: $DESCRIPTION (Boot$BOOT_NUM)"
    continue
  fi
  
  # 删除引导项
  echo "正在删除引导项: $DESCRIPTION (Boot$BOOT_NUM)..."
  efibootmgr -b "$BOOT_NUM" -B
  
  if [ $? -eq 0 ]; then
    echo "成功删除引导项: $DESCRIPTION (Boot$BOOT_NUM)"
  else
    echo "删除引导项失败: $DESCRIPTION (Boot$BOOT_NUM)"
  fi
done

echo "操作完成。建议重启系统以应用更改。"
