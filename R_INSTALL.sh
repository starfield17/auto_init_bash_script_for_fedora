#!/bin/bash

# Error handling setup
set -e
trap 'echo "Error occurred at line $LINENO. Command: $BASH_COMMAND"' ERR

# Check root privileges
check_root() {
    if [ "$(whoami)" != "root" ]; then
        echo "Please run this script as root"
        exit 1
    fi
}

# Check system type
check_system() {
    source /etc/os-release
    ID=$(echo $ID)
    VERSION_ID=$(echo $VERSION_ID)
    echo "Detected system: $ID $VERSION_ID"
}

# Optimize DNF configuration
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
            echo "$config added to $dnf_conf"
        fi
    done
}

# Configure repositories
configure_repos() {
    bash <(curl -sSL https://linuxmirrors.cn/main.sh)
    
    # case "$ID" in
    #     "fedora")
    #         sed -i 's|^metalink=|#metalink=|g' /etc/yum.repos.d/fedora*.repo
    #         sed -i 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' /etc/yum.repos.d/fedora*.repo
    #         sed -i 's|enabled=1|enabled=0|g' /etc/yum.repos.d/fedora-cisco-openh264.repo
    #         ;;
    #     "almalinux")
    #         # Change AlmaLinux base repo to Aliyun mirror
    #         sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    #             -e 's|^# baseurl=https://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g' \
    #             -i.bak \
    #             /etc/yum.repos.d/almalinux*.repo
            
    #         # If EPEL is installed, modify EPEL repo too
    #         if [ -f /etc/yum.repos.d/epel.repo ]; then
    #             sed -e 's|^metalink=|#metalink=|g' \
    #                 -e 's|^#baseurl=https://download.example/pub|baseurl=https://mirrors.aliyun.com|g' \
    #                 -e 's|^#baseurl=https://download.fedoraproject.org/pub|baseurl=https://mirrors.aliyun.com|g' \
    #                 -i.bak \
    #                 /etc/yum.repos.d/epel*.repo
    #         fi
    #         echo "Updated AlmaLinux repositories to Aliyun mirror"
    #         ;;
    #     "rocky")
    #         sed -e 's|^mirrorlist=|#mirrorlist=|g' \
    #             -e 's|^#baseurl=http://dl.rockylinux.org/$contentdir|baseurl=https://mirrors.ustc.edu.cn/rocky|g' \
    #             -i.bak \
    #             /etc/yum.repos.d/rocky-extras.repo \
    #             /etc/yum.repos.d/rocky.repo
    #         ;;
    #     "ol")
    #         sed -i 's|^baseurl=|#baseurl=|g' /etc/yum.repos.d/oracle-linux-ol*.repo
    #         sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/oracle-linux-ol*.repo
    #         sed -i 's|^#baseurl=https://yum.oracle.com|baseurl=https://mirrors.tuna.tsinghua.edu.cn/oracle|g' /etc/yum.repos.d/oracle-linux-ol*.repo
    #         ;;
    # esac
    # echo "Repositories updated to Chinese mirrors"
}

# Install RPM Fusion
install_rpmfusion() {
    local os_type=$1
    local macro=$2
    echo "Installing RPM Fusion and EPEL for $os_type..."
    dnf install -y epel-release
    dnf install -y "https://mirrors.rpmfusion.org/free/$os_type/rpmfusion-free-release-$(rpm -E %$macro).noarch.rpm" \
                   "https://mirrors.rpmfusion.org/nonfree/$os_type/rpmfusion-nonfree-release-$(rpm -E %$macro).noarch.rpm"
}

# Install base packages
install_base_packages() {
    echo "Installing base packages..."
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
        s-tui
    )

    case "$ID" in
        "rocky"|"almalinux"|"ol")
            base_packages+=(
                cockpit
                cockpit-machines
                cockpit-files
                cockpit-navigator
                cockpit-pcp
                cockpit-storaged
            )
            $INSTALL_CMD "${base_packages[@]}"
            systemctl enable --now cockpit.socket
            echo "Cockpit started, access at: https://$(hostname -I | awk '{print $1}'):9090"
            ;;
        "fedora")
            base_packages+=(
                translate-shell
            )
            $INSTALL_CMD "${base_packages[@]}"
            ;;
        *)
            $INSTALL_CMD "${base_packages[@]}"
            ;;
    esac
}

# Install GUI packages
install_gui_packages() {
    read -p "Install GUI packages? (Y/y/N) " GUIPACK
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
        echo "GUI packages installed"
    fi
}

# Install EDA tools
install_eda_tools() {
    read -p "Install KiCad, QUCS and JLCEDA? (Y/y/N) " kicadin
    if [[ "$kicadin" =~ ^[Yy]$ ]]; then
        case "$ID" in
            "rocky"|"ol"|"almalinux")
                echo "Note: Only JLCEDA can be installed"
                ;;
            *)
                $INSTALL_CMD kicad qucs
                ;;
        esac

        # Install JLCEDA
        wget https://image.lceda.cn/files/lceda-pro-linux-x64-2.2.35.1.zip
        unzip lceda-pro-linux-x64-2.2.35.1.zip
        bash ./install.sh
        rm lceda-pro-linux-x64-2.2.35.1.zip
        echo "EDA tools installed"
    fi
}

# Install Flatpak and tools
install_flatpak() {
    if [ "$PKG_MANAGER" = "dnf" ]; then
        read -p "Install Flatpak and related tools? (Y/y/N) " clouds
        if [[ "$clouds" =~ ^[Yy]$ ]]; then
            dnf install -y flatpak
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            flatpak install -y flathub io.github.peazip.PeaZip com.github.flxzt.rnote
        fi
    fi
}

# Install Steam
install_steam() {
    read -p "Install Steam? (Y/y/N) " inssteam
    if [[ "$inssteam" =~ ^[Yy]$ ]]; then
        case "$PKG_MANAGER" in
            "dnf")
                $INSTALL_CMD steam
                ;;
            "pacman")
                echo "Arch Linux environment, skipping Steam installation"
                ;;
        esac
    fi
}

# Main function
main() {
    check_root
    check_system

    if [ -f /etc/redhat-release ] || [ "$ID" = "ol" ]; then
        case "$ID" in
            rocky|fedora|almalinux|ol)
                echo "Detected $ID Linux"
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
                echo "Unsupported Red Hat distribution"
                exit 1
                ;;
        esac
    elif [ -f /etc/arch-release ]; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="pacman -S --noconfirm"
        UPDATE_CMD="pacman -Syu --noconfirm"
    else
        echo "Unsupported Linux distribution"
        exit 1
    fi

    echo "Using package manager: $PKG_MANAGER"
    
    # Perform system update
    echo "Updating system..."
    $UPDATE_CMD

    # Install packages
    install_base_packages
    install_gui_packages
    # install_eda_tools
    install_flatpak
    # install_steam

    # Install cpolar
    # echo "Installing cpolar..."
    # curl -L https://www.cpolar.com/static/downloads/install-release-cpolar.sh | bash

    # Change default shell
    # echo "Changing default shell to fish..."
    # chsh -s /usr/bin/fish
    # chsh -s /usr/bin/fish "$(whoami)"

    # Configure localization
    echo "Configuring system locale..."
    localectl set-locale LANG=en_US.UTF-8

    echo "Installation and configuration complete!"
}

main "$@"
