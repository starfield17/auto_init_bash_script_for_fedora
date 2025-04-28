#!/bin/bash

# --- Interactive Search and Replace Script ---

# 1. Get File Path
read -p "请输入要操作的文件路径: " file_path

# Check if file exists and is a regular file
if [ ! -f "$file_path" ]; then
    echo "错误: 文件 '$file_path' 不存在或不是一个普通文件。"
    exit 1
fi

# 2. Get Search Pattern
read -p "请输入要查询的文本 (将作为 sed 的搜索模式): " search_pattern

# 3. Get Replacement String
read -p "请输入要替换成的文本 (将作为 sed 的替换内容): " replacement_string

echo "-------------------------------------------"
echo ">>> 文件 '$file_path' 的原始内容:"
echo "-------------------------------------------"
# Use cat to display original content. Use sudo if the file might require root to read.
# For /etc/apt/sources.list, reading often doesn't require sudo, but writing does.
# Let's assume reading is okay without sudo for now. If not, add sudo here.
cat "$file_path"
echo "-------------------------------------------"

# --- Prepare for sed ---
# Escape special characters for sed, especially the delimiter (@), &, and \
# This simple escaping handles common cases but might not cover all complex regex scenarios.
escaped_search=$(echo "$search_pattern" | sed -e 's/[&@\\]/\\&/g')
escaped_replace=$(echo "$replacement_string" | sed -e 's/[&@\\]/\\&/g')

echo ">>> 预览: 如果执行替换，文件内容将变为 (尚未保存):"
echo "-------------------------------------------"
# Use sed without -i to preview the changes. Use the same delimiter (@) as the original example.
sed "s@$escaped_search@$escaped_replace@g" "$file_path"
echo "-------------------------------------------"

# 4. Confirmation
read -p "是否要执行以上替换并将更改保存到 '$file_path'? (yes/no): " confirm

# Convert confirmation to lowercase for easier checking
confirm_lower=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

# 5. Perform Action based on confirmation
if [[ "$confirm_lower" == "yes" || "$confirm_lower" == "y" ]]; then
    echo "正在应用更改..."
    # Use sudo sed -i to perform the replacement in-place.
    # Capture potential errors from sudo or sed.
    if sudo sed -i "s@$escaped_search@$escaped_replace@g" "$file_path"; then
        echo "成功: 更改已保存到 '$file_path'."
        echo "-------------------------------------------"
        echo ">>> 文件 '$file_path' 当前内容:"
        echo "-------------------------------------------"
        cat "$file_path" # Show final content
        echo "-------------------------------------------"
    else
        echo "错误: 应用更改时发生错误。文件可能未被修改。"
        # You might want to check the exit code of sudo sed here for more details
        exit 1
    fi
else
    echo "操作已取消。文件 '$file_path' 未被修改。"
fi

exit 0
