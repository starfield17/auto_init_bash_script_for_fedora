curl -sLf https://spacevim.org/install.sh | bash
#setconfig
#!/usr/bin/env bash

# Function to detect Python environment
detect_python_env() {
    # Get Python executable path
    PYTHON_PATH=$(which python3 || which python)
    if [ -z "$PYTHON_PATH" ]; then
        echo "Error: Python not found"
        exit 1
    }
pip install pynvim
    # Get Python version
    PYTHON_VERSION=$($PYTHON_PATH -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    
    # Get site-packages directory
    SITE_PACKAGES=$($PYTHON_PATH -c 'import site; print(site.getsitepackages()[0])')
    
    # Set PYTHON3_HOST_PROG
    PYTHON3_HOST_PROG=$PYTHON_PATH
}

# Function to write fish config
write_fish_config() {
    CONFIG_FILE="$HOME/.config/fish/config.fish"
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Create backup if file exists
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        echo "Created backup at ${CONFIG_FILE}.backup"
    fi
    
    # Write new configuration
    cat << EOF >> "$CONFIG_FILE"

# Python environment configuration
if test -z "\$PYTHONPATH"
    set -x PYTHONPATH "$SITE_PACKAGES"
else
    set -x PYTHONPATH "\$PYTHONPATH:$SITE_PACKAGES"
end
set -x PYTHON3_HOST_PROG "$PYTHON3_HOST_PROG"
EOF
    
    echo "Updated fish configuration at $CONFIG_FILE"
}

# Function to write bash config
write_bash_config() {
    CONFIG_FILE="$HOME/.bashrc"
    
    # Create backup if file exists
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
        echo "Created backup at ${CONFIG_FILE}.backup"
    fi
    
    # Write new configuration
    cat << EOF >> "$CONFIG_FILE"

# Python environment configuration
export PYTHONPATH="\${PYTHONPATH:+\$PYTHONPATH:}$SITE_PACKAGES"
export PYTHON3_HOST_PROG="$PYTHON3_HOST_PROG"
EOF
    
    echo "Updated bash configuration at $CONFIG_FILE"
}

# Main script
echo "Python Environment Configuration Script"
echo "======================================"

# Detect Python environment
detect_python_env

# Show detected configuration
echo "Detected configuration:"
echo "Python Path: $PYTHON_PATH"
echo "Python Version: $PYTHON_VERSION"
echo "Site Packages: $SITE_PACKAGES"
echo "Python3 Host Program: $PYTHON3_HOST_PROG"
echo

# Prompt for shell choice
echo "Which shell configuration would you like to update?"
echo "1) Fish"
echo "2) Bash"
echo "3) Both"
read -p "Enter your choice (1-3): " SHELL_CHOICE

case $SHELL_CHOICE in
    1)
        write_fish_config
        ;;
    2)
        write_bash_config
        ;;
    3)
        write_fish_config
        write_bash_config
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo
echo "Configuration complete!"
echo "Please restart your shell or run 'source ~/.config/fish/config.fish' (for fish)"
echo "or 'source ~/.bashrc' (for bash) to apply the changes."
