#!/bin/bash

set -e  # 在脚本遇到错误时立即退出

# 获取发行版信息
if [ -f /etc/os-release ]; then
    source /etc/os-release
    DISTRO_ID=$ID
    DISTRO_NAME=$NAME
else
    echo "无法检测到操作系统类型。"
    exit 1
fi

# 定义包管理器相关变量
PKG_MANAGER=""
INSTALL_CMD=""
UPDATE_CMD=""
ENABLE_REPO_CMD=""
ADD_REPO_CMD=""

# 配置 DNF（适用于基于 Fedora 的系统）
configure_dnf() {
    if [ -x "$(command -v dnf)" ]; then
        echo "配置 DNF..."
        sudo tee -a /etc/dnf/dnf.conf > /dev/null <<EOL
fastestmirror=True
max_parallel_downloads=4
EOL
        echo "DNF 配置已更新。"
    fi
}

# 配置 YUM/DNF 仓库（RPM 基系统）
configure_rpm_repos() {
    case "$DISTRO_ID" in
        fedora)
            sudo sed -i 's/^metalink=/#metalink=/g' /etc/yum.repos.d/fedora*.repo
            sudo sed -i 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' /etc/yum.repos.d/fedora*.repo
            sudo sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/fedora-cisco-openh264.repo
            ;;
        almalinux | rocky)
            sudo sed -i 's/^mirrorlist=/#mirrorlist=/g' /etc/yum.repos.d/*almalinux*.repo
            if [ "$DISTRO_ID" == "almalinux" ]; then
                sudo sed -i 's|^#baseurl=https://repo.almalinux.org|baseurl=https://mirrors.nju.edu.cn/download/AlmaLinux|g' /etc/yum.repos.d/*almalinux*.repo
            else
                sudo sed -i 's|^#baseurl=https://download.rockylinux.org|baseurl=https://mirrors.ustc.edu.cn/rocky|g' /etc/yum.repos.d/*rocky*.repo
            fi
            ;;
    esac
}

# 安装 RPMFusion 仓库
install_rpmfusion() {
    echo "安装 RPMFusion 仓库..."
    sudo dnf install -y \
        "https://mirrors.rpmfusion.org/free/${1}/rpmfusion-free-release-$(rpm -E %${2}).noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/${1}/rpmfusion-nonfree-release-$(rpm -E %${2}).noarch.rpm"
    echo "RPMFusion 仓库已安装。"
}

# 配置 APT（适用于 Debian、Ubuntu、Kali）
configure_apt() {
    echo "更新 APT 配置..."
    sudo apt update && sudo apt upgrade -y
    echo "APT 已更新。"
}

# 配置 Zypper（适用于 openSUSE）
configure_zypper() {
    echo "更新 Zypper 仓库..."
    sudo zypper refresh
    echo "Zypper 仓库已刷新。"
}

# 安装必要的软件包
install_packages() {
    echo "安装基本软件包..."
    sudo $INSTALL_CMD curl wget gcc gdb fish neovim vim translate-shell fastfetch neofetch tmux byobu htop btop ranger cockpit cockpit-machines
    echo "基本软件包已安装。"
}

# 安装可选的 GUI 软件包
install_gui_packages() {
    echo "安装 GUI 软件包..."
    case "$PKG_MANAGER" in
        apt)
            sudo $INSTALL_CMD putty remmina bleachbit
            ;;
        pacman)
            sudo $INSTALL_CMD putty remmina bleachbit
            ;;
        dnf | zypper)
            sudo $INSTALL_CMD putty remmina bleachbit
            ;;
    esac
    echo "GUI 软件包安装完成。"
}

# 更改默认 shell 为 fish
change_default_shell() {
    echo "更改默认 shell 为 fish..."
    sudo chsh -s "$(which fish)"
    echo "默认 shell 已更改为 fish。"
}

# 安装 EDA 软件
install_eda() {
    read -p "是否安装 KiCad, QUCS 和 JLCEDA? (Y/y): " install_eda_choice
    if [[ "$install_eda_choice" =~ ^[Yy]$ ]]; then
        case "$DISTRO_ID" in
            rocky)
                echo "Rocky Linux 仅支持安装 JLCEDA。"
                ;;
            fedora | almalinux | ubuntu | debian | kali)
                sudo $INSTALL_CMD kicad qucs -y
                wget https://image.lceda.cn/files/lceda-pro-linux-x64-2.2.32.3.1.zip
                unzip lceda-pro-linux-x64-2.2.32.3.1.zip
                sudo bash ./install.sh
                rm lceda-pro-linux-x64-2.2.32.3.1.zip
                echo "EDA 软件安装完成。"
                ;;
            *)
                echo "不支持的发行版。"
                ;;
        esac
    fi
}

# 安装 Visual Studio Code
install_vscode() {
    echo "安装 Visual Studio Code..."
    case "$PKG_MANAGER" in
        pacman)
            curl -SLf https://142857.red/files/nvimrc-install.sh | bash
            sudo pacman -S --noconfirm base-devel git
            git clone https://aur.archlinux.org/visual-studio-code-bin.git
            cd visual-studio-code-bin
            makepkg -si --noconfirm
            cd ..
            rm -rf visual-studio-code-bin
            ;;
        dnf)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
            sudo dnf check-update
            sudo dnf install -y code
            sudo dnf upgrade --refresh -y
            ;;
        apt)
            sudo apt update
            sudo apt install -y wget gpg
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
            sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
            sudo sh -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
            sudo apt update
            sudo apt install -y code
            ;;
        zypper)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            sudo zypper addrepo --name "Visual Studio Code" https://packages.microsoft.com/yumrepos/vscode vscode
            sudo zypper refresh
            sudo zypper install -y code
            ;;
    esac
    echo "Visual Studio Code 安装完成。"
}

# 安装 Flatpak 和相关工具，并配置清华镜像源
install_flatpak_tools() {
    read -p "是否安装 Flatpak 及其工具? (Y/y): " install_flatpak_choice
    if [[ "$install_flatpak_choice" =~ ^[Yy]$ ]]; then
        echo "安装 Flatpak..."
        case "$PKG_MANAGER" in
            dnf | zypper | apt | pacman)
                sudo $INSTALL_CMD flatpak
                ;;
            *)
                echo "不支持的包管理器: $PKG_MANAGER"
                exit 1
                ;;
        esac

        echo "配置 Flatpak 使用清华镜像源..."
        
        # 删除默认的 flathub 仓库（如果存在）
        if flatpak remote-list | grep -q flathub; then
            sudo flatpak remote-delete flathub
            echo "已删除默认的 flathub 仓库。"
        fi

        # 添加清华镜像源
        sudo flatpak remote-add --if-not-exists flathub https://mirrors.tuna.tsinghua.edu.cn/flathub/flathub.flatpakrepo
        echo "已添加清华镜像源作为 flathub。"

        echo "Flatpak 及其清华镜像工具安装完成。"
    fi
}

# 安装 Steam
install_steam() {
    read -p "是否安装 Steam? (Y/y): " install_steam_choice
    if [[ "$install_steam_choice" =~ ^[Yy]$ ]]; then
        case "$PKG_MANAGER" in
            dnf | zypper)
                sudo $INSTALL_CMD steam
                ;;
            apt)
                sudo $INSTALL_CMD steam
                ;;
            pacman)
                echo "Arch 环境中使用 Steam，请使用 'sudo pacman -S steam' 手动安装。"
                ;;
        esac
        echo "Steam 安装完成。"
    fi
}

# 配置本地化
configure_locales() {
    echo "配置本地化设置..."
    sudo localectl set-locale LANG=en_US.UTF-8
    echo "本地化配置完成。"
}

# 安装 Cockpit 并启动
install_cockpit() {
    echo "安装并启动 Cockpit..."
    sudo $INSTALL_CMD cockpit
    sudo systemctl enable --now cockpit.socket
    echo "Cockpit 已启动，您可以通过 http://your_ip_address:9090 访问。"
}

# 安装 cpolar
install_cpolar() {
    echo "安装 cpolar..."
    curl -L https://www.cpolar.com/static/downloads/install-release-cpolar.sh | sudo bash
    echo "cpolar 安装完成。"
}

# 主逻辑
main() {
    echo "检测到的发行版: $DISTRO_NAME"

    case "$DISTRO_ID" in
        fedora | almalinux | rocky)
            PKG_MANAGER="dnf"
            INSTALL_CMD="sudo dnf install -y"
            UPDATE_CMD="sudo dnf update -y"
            configure_dnf
            configure_rpm_repos
            install_rpmfusion "${DISTRO_ID}" "rhel"
            ;;
        ubuntu | debian | kali)
            PKG_MANAGER="apt"
            INSTALL_CMD="sudo apt install -y"
            UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
            ;;
        arch)
            PKG_MANAGER="pacman"
            INSTALL_CMD="sudo pacman -S --noconfirm"
            UPDATE_CMD="sudo pacman -Syu --noconfirm"
            ;;
        opensuse-* | opensuse)
            PKG_MANAGER="zypper"
            INSTALL_CMD="sudo zypper install -y"
            UPDATE_CMD="sudo zypper update -y"
            ;;
        *)
            echo "不支持的发行版: $DISTRO_NAME"
            exit 1
            ;;
    esac

    echo "使用的包管理器是: $PKG_MANAGER"

    # 更新和升级软件包列表
    echo "更新和升级软件包列表..."
    $UPDATE_CMD

    # 安装 Cockpit
    install_cockpit

    # 安装基本软件包
    install_packages

    # 启动和安装 cpolar
    install_cpolar

    # 安装可选的 GUI 软件包
    read -p "是否安装需要 GUI 的软件包? (Y/y/N) " GUIPACK
    if [[ "$GUIPACK" =~ ^[Yy]$ ]]; then
        install_gui_packages
    fi

    # 更改默认 shell 为 fish
    change_default_shell

    # 安装 EDA 软件
    install_eda

    # 安装 Visual Studio Code
    install_vscode

    # 安装 Flatpak 及其工具
    install_flatpak_tools

    # 安装 Steam
    install_steam

    # 配置本地化
    configure_locales

    echo "安装和配置完成！"
}

# 执行主逻辑
main
