#!/bin/bash

# --- Interactive Search and Replace Script ---

# 1. Get File Path
read -p "Please enter the file path to operate on: " file_path

# Check if file exists and is a regular file
if [ ! -f "$file_path" ]; then
    echo "Error: File '$file_path' does not exist or is not a regular file."
    exit 1
fi

# 2. Get Search Pattern
read -p "Please enter the text to search for (will be used as the sed search pattern): " search_pattern

# 3. Get Replacement String
read -p "Please enter the replacement text (will be used as the sed replacement content): " replacement_string

echo "-------------------------------------------"
echo ">>> Original content of file '$file_path':"
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

echo ">>> Preview: If replacement is executed, the content will become (not yet saved):"
echo "-------------------------------------------"
# Use sed without -i to preview the changes. Use the same delimiter (@) as the original example.
sed "s@$escaped_search@$escaped_replace@g" "$file_path"
echo "-------------------------------------------"

# 4. Confirmation
read -p "Do you want to perform the above replacement and save changes to '$file_path'? (yes/no): " confirm

# Convert confirmation to lowercase for easier checking
confirm_lower=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')

# 5. Perform Action based on confirmation
if [[ "$confirm_lower" == "yes" || "$confirm_lower" == "y" ]]; then
    echo "Applying changes..."
    # Use sudo sed -i to perform the replacement in-place.
    # Capture potential errors from sudo or sed.
    if sudo sed -i "s@$escaped_search@$escaped_replace@g" "$file_path"; then
        echo "Success: Changes saved to '$file_path'."
        echo "-------------------------------------------"
        echo ">>> Current content of file '$file_path':"
        echo "-------------------------------------------"
        cat "$file_path" # Show final content
        echo "-------------------------------------------"
    else
        echo "Error: An error occurred while applying changes. The file might not have been modified."
        # You might want to check the exit code of sudo sed here for more details
        exit 1
    fi
else
    echo "Operation canceled. File '$file_path' has not been modified."
fi

exit 0
