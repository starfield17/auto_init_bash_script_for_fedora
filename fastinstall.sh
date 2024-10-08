#!/bin/bash
# 检查系统类型
if [ -f /etc/redhat-release ]; then
source /etc/os-release
if [[ "$ID" == "rocky" ]]; then
echo "This is Rocky Linux."
sudo yum install -y dnf
sudo dnf install -y yum-utils
sudo dnf install -y https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm
sudo dnf install -y https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf config-manager --set-enabled crb
sudo dnf install epel-release epel-next-release
elif [[ "$ID" == "fedora" ]]; then
    echo "This is Fedora."
else
    echo "This is neither Rocky Linux nor Fedora."
fi
PKG_MANAGER="dnf"
INSTALL_CMD="sudo dnf install -y"
UPDATE_CMD="sudo dnf update -y"
# 检查是否已经存在 "fastestmirror=True"
if ! grep -q "^fastestmirror=True" /etc/dnf/dnf.conf; then
sudo echo "fastestmirror=True" >> /etc/dnf/dnf.conf
echo "fastestmirror 已成功添加到 /etc/dnf/dnf.conf"
else
echo "fastestmirror 已经存在于 /etc/dnf/dnf.conf 中"
fi
elif [ -f /etc/arch-release ]; then
PKG_MANAGER="pacman"
INSTALL_CMD="sudo pacman -S --noconfirm"
UPDATE_CMD="sudo pacman -Syu --noconfirm"
else
echo "未知的Linux发行版"
exit 1
fi
echo "使用的包管理器是: $PKG_MANAGER"
# 更新和升级软件包列表
echo "Updating and upgrading package lists..."
$UPDATE_CMD
# 安装必要的软件包
echo "Installing essential packages..."       
$INSTALL_CMD curl wget  g++ gcc gdb fish neovim vim translate-shell fastfetch neofetch tmux htop cpu-x ranger cockpit cockpit-machines -y
sudo systemctl enable --now cockpit.socket
systemctl status cockpit.socket
echo "cockpit started ,you can see you machine at your ip_address:9090"
read -p "install packages need GUI?(Y/y/N)" GUIPACK
if [[ "$GUIPACK" =~ ^[Yy]$ ]]; then
$INSTALL_CMD  putty remmina bleachbit sysmontask -y
echo "GUI_PACKAGES install complete."
fi
# 更改默认shell为fish
echo "Changing default shell to fish..."
sudo chsh -s /usr/bin/fish
chsh -s /usr/bin/fish
read -p "Install KiCad, QUCS, and JLCEDA? (Y/y): " kicadin
if [[ "$kicadin" =~ ^[Yy]$ ]]; then
    $INSTALL_CMD kicad qucs -y
    wget https://image.lceda.cn/files/lceda-pro-linux-x64-2.2.27.1.zip
    unzip lceda-pro-linux-x64-2.2.27.1.zip
    sudo bash ./install.sh
    rm lceda-pro-linux-x64-2.2.27.1.zip
    echo "EDA software installation completed"
fi
#安装Visual Studio Code
echo "Installing Visual Studio Code..."
if [ "$PKG_MANAGER" = "pacman" ]; then
sudo pacman -S base-devel
sudo pacman -S git
elif [ "$PKG_MANAGER" = "dnf" ]; then
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'  
sudo dnf check-update
sudo dnf install code -y
sudo dnf upgrade --refresh
read -p "Install flatpak and some TOOLS? (Y/y): " clouds
if [[ "$clouds" =~ ^[Yy]$ ]]; then
sudo dnf install flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
#flatpak install -y flathub com.netease.CloudMusic
flatpak install -y flathub io.github.peazip.PeaZip
flatpak install -y flathub com.github.flxzt.rnote
fi 
#sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
#sudo dnf config-manager --add-repo https://packages.microsoft.com/yumrepos/edge
#sudo dnf install microsoft-edge-stable
fi
read -p "Install Steam? (Y/y): " inssteam
if [[ "$inssteam" =~ ^[Yy]$ ]]; then
if [ "$PKG_MANAGER" = "pacman" ]; then
echo "your environment is arch,skip."
elif [ "$PKG_MANAGER" = "dnf" ]; then
sudo dnf install steam -y
fi
fi
# 配置本地化
echo "Configuring locales..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
sudo dpkg-reconfigure locales
else
sudo localectl set-locale LANG=en_US.UTF-8
fi
echo "Installation and setup complete!"
