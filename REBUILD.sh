#!/bin/bash

set -euo pipefail

# 检查系统类型
if [ -f /etc/os-release ]; then
    source /etc/os-release
else
    echo "无法检测到 /etc/os-release 文件。"
    exit 1
fi

ID=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
VERSION_ID=$(echo "$VERSION_ID" | tr -d '"')

# 定义包管理器相关变量
declare PKG_MANAGER=""
declare INSTALL_CMD=""
declare UPDATE_CMD=""
declare ADD_REPO_CMD=""
declare ENABLE_REPO_CMD=""

# 配置包管理器和命令
configure_pkg_manager() {
    case "$ID" in
        fedora|almalinux|rocky)
            PKG_MANAGER="dnf"
            INSTALL_CMD="sudo dnf install -y"
            UPDATE_CMD="sudo dnf update -y"
            ;;
        ubuntu|debian|kali)
            PKG_MANAGER="apt"
            INSTALL_CMD="sudo apt-get install -y"
            UPDATE_CMD="sudo apt-get update && sudo apt-get upgrade -y"
            ;;
        opensuse*|suse)
            PKG_MANAGER="zypper"
            INSTALL_CMD="sudo zypper install -y"
            UPDATE_CMD="sudo zypper refresh && sudo zypper update -y"
            ;;
        arch)
            PKG_MANAGER="pacman"
            INSTALL_CMD="sudo pacman -S --noconfirm"
            UPDATE_CMD="sudo pacman -Syu --noconfirm"
            ;;
        *)
            echo "Unsupported Linux distribution: $ID"
            exit 1
            ;;
    esac
    echo "使用的包管理器是: $PKG_MANAGER"
}

# 配置 DNF（仅适用于 Fedora、AlmaLinux、Rocky）
configure_dnf() {
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        if ! grep -q "^fastestmirror=True" /etc/dnf/dnf.conf; then
            echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf
            echo "fastestmirror 已成功添加到 /etc/dnf/dnf.conf"
        else
            echo "fastestmirror 已经存在于 /etc/dnf/dnf.conf 中"
        fi

        if ! grep -q "^max_parallel_downloads=4" /etc/dnf/dnf.conf; then
            echo "max_parallel_downloads=4" | sudo tee -a /etc/dnf/dnf.conf
            echo "max_parallel_downloads=4 已成功添加到 /etc/dnf/dnf.conf"
        else
            echo "max_parallel_downloads=4 已经存在于 /etc/dnf/dnf.conf 中"
        fi
    fi
}

# 配置仓库（适用于 Fedora、AlmaLinux、Rocky、openSUSE）
configure_repos() {
    case "$ID" in
        fedora)
            sudo sed -i 's|^metalink=|#metalink=|g' /etc/yum.repos.d/fedora*.repo
            sudo sed -i 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' /etc/yum.repos.d/fedora*.repo
            sudo sed -i 's|enabled=1|enabled=0|g' /etc/yum.repos.d/fedora-cisco-openh264.repo
            ;;
        almalinux)
            sudo sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/almalinux*.repo
            sudo sed -i 's|^#baseurl=https://repo.almalinux.org|baseurl=https://mirrors.nju.edu.cn/download/AlmaLinux|g' /etc/yum.repos.d/almalinux*.repo
            ;;
        rocky)
            sudo sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/rocky*.repo
            sudo sed -i 's|^#baseurl=https://download.rockylinux.org|baseurl=https://mirrors.ustc.edu.cn/rocky|g' /etc/yum.repos.d/rocky*.repo
            ;;
        opensuse*|suse)
            # 这里可以添加 openSUSE 的镜像配置
            echo "配置 openSUSE 仓库（如有需要）"
            ;;
        *)
            echo "无需配置额外的仓库。"
            ;;
    esac
}

# 安装 RPMFusion（仅适用于 Fedora、AlmaLinux、Rocky）
install_rpmfusion() {
    if [[ "$PKG_MANAGER" == "dnf" ]]; then
        echo "Installing RPMFusion for $1 with macro $2"
        sudo dnf install -y "https://mirrors.rpmfusion.org/free/$1/rpmfusion-free-release-$(rpm -E %$2).noarch.rpm" \
                            "https://mirrors.rpmfusion.org/nonfree/$1/rpmfusion-nonfree-release-$(rpm -E %$2).noarch.rpm"
    fi
}

# 安装必要的软件包
install_essential_packages() {
    echo "Installing essential packages..."
    local packages_common=(curl wget g++ gcc gdb fish neovim vim translate-shell fastfetch neofetch tmux byobu htop btop ranger cockpit cockpit-machines)
    local packages_fedora=(cpu-x)
    local packages_ubuntu=(cpu-x)
    local packages_zypper=()

    case "$ID" in
        rocky|almalinux)
            $INSTALL_CMD "${packages_common[@]}"
            ;;
        fedora)
            $INSTALL_CMD "${packages_common[@]}" "${packages_fedora[@]}"
            ;;
        ubuntu|debian|kali)
            $INSTALL_CMD "${packages_common[@]}"
            ;;
        arch)
            $INSTALL_CMD "${packages_common[@]}"
            ;;
        opensuse*|suse)
            $INSTALL_CMD "${packages_common[@]}"
            ;;
        *)
            echo "Unsupported distribution for installing essential packages."
            exit 1
            ;;
    esac
}

# 启用并启动 Cockpit
enable_cockpit() {
    sudo systemctl enable --now cockpit.socket
    sudo systemctl status cockpit.socket > cockpit.status
    echo "Cockpit 已启动，你可以通过 http://your_ip_address:9090 访问你的机器。"
}

# 安装 cpolar
install_cpolar() {
    echo "安装 cpolar..."
    curl -L https://www.cpolar.com/static/downloads/install-release-cpolar.sh | sudo bash
}

# 安装 GUI 包
install_gui_packages() {
    read -p "是否安装需要 GUI 的软件包？(Y/y/N) " GUIPACK
    if [[ "$GUIPACK" =~ ^[Yy]$ ]]; then
        local gui_packages=(putty remmina bleachbit)
        case "$PKG_MANAGER" in
            fedora)
                gui_packages+=(sysmontask)
                ;;
            rocky|almalinux|ubuntu|debian|kali|arch|opensuse*|suse)
                # 根据需要添加特定发行版的 GUI 包
                ;;
        esac
        $INSTALL_CMD "${gui_packages[@]}"
        echo "GUI 软件包安装完成。"
    fi
}

# 更改默认 shell 为 fish
change_default_shell() {
    echo "更改默认 shell 为 fish..."
    sudo chsh -s /usr/bin/fish
    chsh -s /usr/bin/fish
}

# 安装 KiCad, QUCS 和 JLCEDA
install_eda_software() {
    read -p "是否安装 KiCad, QUCS 和 JLCEDA？(Y/y) " kicadin
    if [[ "$kicadin" =~ ^[Yy]$ ]]; then
        case "$ID" in
            rocky)
                echo "仅支持安装 JLCEDA。"
                ;;
            fedora|almalinux|rocky|ubuntu|debian|kali)
                $INSTALL_CMD kicad qucs
                ;;
            arch)
                $INSTALL_CMD kicad qucs
                ;;
            opensuse*|suse)
                $INSTALL_CMD kicad qucs
                ;;
            *)
                echo "Unsupported distribution for EDA software installation."
                ;;
        esac

        wget https://image.lceda.cn/files/lceda-pro-linux-x64-2.2.27.1.zip
        unzip lceda-pro-linux-x64-2.2.27.1.zip
        sudo bash ./install.sh
        rm lceda-pro-linux-x64-2.2.27.1.zip
        echo "EDA 软件安装完成。"
    fi
}

# 安装 Visual Studio Code
install_vscode() {
    echo "安装 Visual Studio Code..."
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        curl -SLf https://142857.red/files/nvimrc-install.sh | bash
        sudo pacman -S --noconfirm base-devel git
        git clone https://aur.archlinux.org/visual-studio-code-bin.git
        cd visual-studio-code-bin
        makepkg -si --noconfirm
        cd ..
        rm -rf visual-studio-code-bin
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf check-update
        sudo dnf install -y code
        sudo dnf upgrade --refresh
        read -p "是否安装 Flatpak 及其工具？(Y/y) " clouds
        if [[ "$clouds" =~ ^[Yy]$ ]]; then
            sudo dnf install -y flatpak
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            flatpak install -y flathub io.github.peazip.PeaZip com.github.flxzt.rnote
        fi
    elif [[ "$PKG_MANAGER" == "apt" ]]; then
        sudo apt update
        sudo apt install -y software-properties-common apt-transport-https wget
        wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
        sudo apt update
        sudo apt install -y code
        read -p "是否安装 Flatpak 及其工具？(Y/y) " clouds
        if [[ "$clouds" =~ ^[Yy]$ ]]; then
            sudo apt install -y flatpak
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            flatpak install -y flathub io.github.peazip.PeaZip com.github.flxzt.rnote
        fi
    elif [[ "$PKG_MANAGER" == "zypper" ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo zypper addrepo https://packages.microsoft.com/yumrepos/vscode vscode
        sudo zypper refresh
        sudo zypper install -y code
    fi
}

# 安装 Steam
install_steam() {
    read -p "是否安装 Steam？(Y/y) " inssteam
    if [[ "$inssteam" =~ ^[Yy]$ ]]; then
        case "$PKG_MANAGER" in
            pacman)
                echo "你的环境是 Arch，跳过安装 Steam。"
                ;;
            dnf|apt|zypper)
                $INSTALL_CMD steam
                ;;
            *)
                echo "Unsupported distribution for Steam installation."
                ;;
        esac
    fi
}

# 配置本地化
configure_locales() {
    echo "配置本地化..."
    case "$PKG_MANAGER" in
        dnf|apt|pacman|zypper)
            sudo localectl set-locale LANG=en_US.UTF-8
            ;;
        *)
            echo "Unsupported package manager for locale configuration."
            exit 1
            ;;
    esac
}

# 主流程
main() {
    configure_pkg_manager
    case "$PKG_MANAGER" in
        dnf)
            configure_dnf
            configure_repos
            install_rpmfusion "${ID}" "${ID}"
            ;;
        apt)
            # 可以添加 Debian/Ubuntu 的仓库配置
            echo "配置 APT 仓库（如有需要）"
            ;;
        zypper)
            configure_repos
            ;;
        arch)
            configure_repos
            ;;
        *)
            echo "无需配置额外的仓库。"
            ;;
    esac

    $UPDATE_CMD
    install_essential_packages
    enable_cockpit
    install_cpolar
    install_gui_packages
    change_default_shell
    install_eda_software
    install_vscode
    install_steam
    configure_locales

    echo "安装和配置完成！"
}

# 执行主流程
main
