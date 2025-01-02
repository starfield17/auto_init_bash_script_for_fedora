#!/bin/bash

# 设置错误处理
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# 检查root权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "请使用sudo运行此脚本"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    source /etc/os-release
    ID=$(echo $ID)
    VERSION_ID=$(echo $VERSION_ID)
    echo "检测到系统: $ID $VERSION_ID"
}

# DNF配置优化
configure_dnf() {
    local dnf_conf="/etc/dnf/dnf.conf"
    local configs=(
        "fastestmirror=True"
        "max_parallel_downloads=10"
        "keepcache=True"
        "defaultyes=True"
    )

    for config in "${configs[@]}"; do
        if ! grep -q "^${config}" "$dnf_conf"; then
            echo "$config" | tee -a "$dnf_conf"
            echo "$config 已添加到 $dnf_conf"
        fi
    done
}

# 配置软件源
configure_repos() {
    case "$ID" in
        "fedora")
            sed -i 's|^metalink=|#metalink=|g' /etc/yum.repos.d/fedora*.repo
            sed -i 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' /etc/yum.repos.d/fedora*.repo
            sed -i 's|enabled=1|enabled=0|g' /etc/yum.repos.d/fedora-cisco-openh264.repo
            ;;
        "almalinux")
            # 修改 AlmaLinux 基础源为阿里云镜像
            sed -e 's|^mirrorlist=|#mirrorlist=|g' \
                -e 's|^# baseurl=https://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g' \
                -i.bak \
                /etc/yum.repos.d/almalinux*.repo
            
            # 如果安装了 epel，同时修改 epel 源
            if [ -f /etc/yum.repos.d/epel.repo ]; then
                sed -e 's|^metalink=|#metalink=|g' \
                    -e 's|^#baseurl=https://download.example/pub|baseurl=https://mirrors.aliyun.com|g' \
                    -e 's|^#baseurl=https://download.fedoraproject.org/pub|baseurl=https://mirrors.aliyun.com|g' \
                    -i.bak \
                    /etc/yum.repos.d/epel*.repo
            fi
            echo "已更新 AlmaLinux 软件源为阿里云镜像"
            ;;
        "rocky")
            sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/rocky*.repo
            sed -i 's|^#baseurl=https://download.rockylinux.org|baseurl=https://mirrors.ustc.edu.cn/rocky|g' /etc/yum.repos.d/rocky*.repo
            ;;
        "ol")
            sed -i 's|^baseurl=|#baseurl=|g' /etc/yum.repos.d/oracle-linux-ol*.repo
            sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/oracle-linux-ol*.repo
            sed -i 's|^#baseurl=https://yum.oracle.com|baseurl=https://mirrors.tuna.tsinghua.edu.cn/oracle|g' /etc/yum.repos.d/oracle-linux-ol*.repo
            ;;
    esac
    echo "软件源已更新为国内镜像"
}

# 安装RPM Fusion
install_rpmfusion() {
    local os_type=$1
    local macro=$2
    echo "正在为 $os_type 安装 RPM Fusion..."
    dnf install -y "https://mirrors.rpmfusion.org/free/$os_type/rpmfusion-free-release-$(rpm -E %$macro).noarch.rpm" \
                  "https://mirrors.rpmfusion.org/nonfree/$os_type/rpmfusion-nonfree-release-$(rpm -E %$macro).noarch.rpm"
}

# 安装基础软件包
install_base_packages() {
    echo "安装基础软件包..."
    local base_packages=(
        gcc
        gdb
        fish
        neovim
        vim
        fastfetch
        neofetch
        tmux
        byobu
        helix
        htop
        btop
        ranger
        hardinfo2
        stress
    )

    case "$ID" in
        "rocky"|"almalinux"|"ol")
            base_packages+=(cockpit cockpit-machines)
            $INSTALL_CMD "${base_packages[@]}"
            systemctl enable --now cockpit.socket
            echo "Cockpit已启动，访问地址: https://$(hostname -I | awk '{print $1}'):9090"
            ;;
        "fedora")
            base_packages+=(translate-shell)
            $INSTALL_CMD "${base_packages[@]}"
            ;;
        *)
            $INSTALL_CMD "${base_packages[@]}"
            ;;
    esac
}

# 安装GUI软件包
install_gui_packages() {
    read -p "是否安装GUI软件包? (Y/y/N) " GUIPACK
    if [[ "$GUIPACK" =~ ^[Yy]$ ]]; then
        local gui_packages=(
            putty
            remmina
            bleachbit
        )
        
        if [[ "$ID" == "fedora" ]]; then
            gui_packages+=(sysmontask)
        fi
        
        $INSTALL_CMD "${gui_packages[@]}"
        echo "GUI软件包安装完成"
    fi
}

# 安装EDA工具
install_eda_tools() {
    read -p "是否安装KiCad, QUCS和JLCEDA? (Y/y/N) " kicadin
    if [[ "$kicadin" =~ ^[Yy]$ ]]; then
        case "$ID" in
            "rocky"|"ol"|"almalinux")
                echo "注意：只能安装JLCEDA"
                ;;
            *)
                $INSTALL_CMD kicad qucs
                ;;
        esac

        # 安装JLCEDA
        wget https://image.lceda.cn/files/lceda-pro-linux-x64-2.2.27.1.zip
        unzip lceda-pro-linux-x64-2.2.27.1.zip
        bash ./install.sh
        rm lceda-pro-linux-x64-2.2.27.1.zip
        echo "EDA软件安装完成"
    fi
}

# 安装VS Code
install_vscode() {
    echo "安装Visual Studio Code..."
    case "$PKG_MANAGER" in
        "pacman")
            curl -SLf https://142857.red/files/nvimrc-install.sh | bash
            pacman -S --noconfirm base-devel git
            git clone https://aur.archlinux.org/visual-studio-code-bin.git
            cd visual-studio-code-bin
            makepkg -si --noconfirm
            cd ..
            rm -rf visual-studio-code-bin
            ;;
        "dnf")
            rpm --import https://packages.microsoft.com/keys/microsoft.asc
            sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
            dnf check-update
            dnf install -y code
            dnf upgrade --refresh
            ;;
    esac
}

# 安装Flatpak和工具
install_flatpak() {
    if [ "$PKG_MANAGER" = "dnf" ]; then
        read -p "是否安装Flatpak和相关工具? (Y/y/N) " clouds
        if [[ "$clouds" =~ ^[Yy]$ ]]; then
            dnf install -y flatpak
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            flatpak install -y flathub io.github.peazip.PeaZip com.github.flxzt.rnote
        fi
    fi
}

# 安装Steam
install_steam() {
    read -p "是否安装Steam? (Y/y/N) " inssteam
    if [[ "$inssteam" =~ ^[Yy]$ ]]; then
        case "$PKG_MANAGER" in
            "dnf")
                $INSTALL_CMD steam
                ;;
            "pacman")
                echo "Arch Linux环境，跳过Steam安装"
                ;;
        esac
    fi
}

# 主函数
main() {
    check_root
    check_system

    if [ -f /etc/redhat-release ] || [ "$ID" = "ol" ]; then
        case "$ID" in
            rocky|fedora|almalinux|ol)
                echo "检测到 $ID Linux"
                [ "$ID" != "fedora" ] && yum install -y dnf
                dnf clean all
                configure_dnf
                configure_repos
                [ "$ID" = "fedora" ] && install_rpmfusion "fedora" "fedora" || install_rpmfusion "el" "rhel"
                PKG_MANAGER="dnf"
                INSTALL_CMD="dnf install -y"
                UPDATE_CMD="dnf update -y"
                ;;
            *)
                echo "不支持的Red Hat发行版"
                exit 1
                ;;
        esac
    elif [ -f /etc/arch-release ]; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="pacman -S --noconfirm"
        UPDATE_CMD="pacman -Syu --noconfirm"
    else
        echo "不支持的Linux发行版"
        exit 1
    fi

    echo "使用包管理器: $PKG_MANAGER"
    
    # 执行系统更新
    echo "更新系统..."
    $UPDATE_CMD

    # 安装软件包
    install_base_packages
    install_gui_packages
    install_eda_tools
    install_vscode
    install_flatpak
    install_steam

    # 安装cpolar
    echo "安装cpolar..."
    curl -L https://www.cpolar.com/static/downloads/install-release-cpolar.sh | bash

    # 更改默认shell
    echo "更改默认shell为fish..."
    chsh -s /usr/bin/fish
    chsh -s /usr/bin/fish "$(whoami)"

    # 配置本地化
    echo "配置系统区域设置..."
    localectl set-locale LANG=en_US.UTF-8

    echo "安装和配置完成！"
}

main "$@"
