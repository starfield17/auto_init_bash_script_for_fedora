#!/bin/bash
# Check system type
source /etc/os-release
ID=$(echo $ID)
configure_dnf() {
	if ! grep -q "^fastestmirror=True" /etc/dnf/dnf.conf; then
		echo "fastestmirror=True" | sudo tee -a /etc/dnf/dnf.conf
		echo "fastestmirror successfully added to /etc/dnf/dnf.conf"
	else
		echo "fastestmirror already exists in /etc/dnf/dnf.conf"
	fi
 	if ! grep -q "^max_parallel_downloads=4" /etc/dnf/dnf.conf; then
		echo "max_parallel_downloads=4" | sudo tee -a /etc/dnf/dnf.conf
		echo "max_parallel_downloads=4 successfully added to /etc/dnf/dnf.conf"
	else
		echo "max_parallel_downloads=4 already exists in /etc/dnf/dnf.conf"
	fi
}
configure_repos() {
  if [ "$ID" == "fedora" ]; then
    	sudo sed -i 's|^metalink=|#metalink=|g' /etc/yum.repos.d/fedora*.repo
    	sudo sed -i 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.ustc.edu.cn/fedora|g' /etc/yum.repos.d/fedora*.repo
    	sudo sed -i 's|enabled=1|enabled=0|g' /etc/yum.repos.d/fedora-cisco-openh264.repo
  elif [ "$ID" == "almalinux" ]; then
  	sudo sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/almalinux*.repo
    	sudo sed -i 's|^#baseurl=https://repo.almalinux.org|baseurl=https://mirrors.nju.edu.cn/download/AlmaLinux|g' /etc/yum.repos.d/almalinux*.repo
  elif [ "$ID" == "rocky" ]; then
    	sudo sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/rocky*.repo
    	sudo sed -i 's|^#baseurl=https://download.rockylinux.org|baseurl=https://mirrors.ustc.edu.cn/rocky|g' /etc/yum.repos.d/rocky*.repo
  fi
}
install_rpmfusion() {
	echo "Installing RPMFusion for $1 with macro $2"
	sudo dnf install -y "https://mirrors.rpmfusion.org/free/$1/rpmfusion-free-release-$(rpm -E %$2).noarch.rpm" \
	"https://mirrors.rpmfusion.org/nonfree/$1/rpmfusion-nonfree-release-$(rpm -E %$2).noarch.rpm"
}
if [ -f /etc/redhat-release ]; then
	case "$ID" in
	rocky)
	echo "This is Rocky Linux."
	sudo yum install -y dnf
	sudo dnf clean all
	configure_dnf
	configure_repos
	install_rpmfusion "el" "rhel"
	;;
	fedora)
	echo "This is Fedora."
 	sudo dnf clean all
	configure_dnf
	configure_repos
	install_rpmfusion "fedora" "fedora"
	;;
	almalinux)
	echo "This is AlmaLinux."
	sudo yum install -y dnf
	sudo dnf clean all
	configure_dnf
	configure_repos
	install_rpmfusion "el" "rhel"
	;;
	*)
	echo "This redhat-release is neither Rocky Linux, Fedora, nor AlmaLinux."
	exit 1
	;;
	esac
	PKG_MANAGER="dnf"
	INSTALL_CMD="sudo dnf install -y"
	UPDATE_CMD="sudo dnf update -y"
elif [ -f /etc/arch-release ]; then
	PKG_MANAGER="pacman"
	INSTALL_CMD="sudo pacman -S --noconfirm"
	UPDATE_CMD="sudo pacman -Syu --noconfirm"
else
	echo "Unknown Linux distribution"
	exit 1
fi
echo "Package manager being used: $PKG_MANAGER"
# Update and upgrade package lists
echo "Updating and upgrading package lists..."
$UPDATE_CMD
# Install essential packages
echo "Installing essential packages..."
if [[ "$ID" == "rocky" ]] || [[ "$ID" == "almalinux" ]]; then
	$INSTALL_CMD gcc gdb fish neovim vim fastfetch neofetch tmux byobu helix htop btop ranger cockpit cockpit-machines -y
elif [[ "$ID" == "fedora" ]]; then
	$INSTALL_CMD gcc gdb fish neovim vim translate-shell fastfetch helix tmux byobu htop btop ranger -y
else
	$INSTALL_CMD fish neovim vim zsh fastfetch neofetch tmux byobu htop ranger btop -y
fi
sudo systemctl enable --now cockpit.socket
systemctl status cockpit.socket > cockpit.socket
echo "Cockpit started, you can see your machine at your ip_address:9090"
echo "Installing cpolar..."
curl -L https://www.cpolar.com/static/downloads/install-release-cpolar.sh | sudo bash
read -p "Install packages that need GUI? (Y/y/N) " GUIPACK
if [[ "$GUIPACK" =~ ^[Yy]$ ]]; then
	if [[ "$ID" == "rocky" ]] || [[ "$ID" == "almalinux" ]]; then
		$INSTALL_CMD putty remmina bleachbit -y
	elif [[ "$ID" == "fedora" ]]; then
		$INSTALL_CMD putty remmina bleachbit sysmontask -y
	else
		$INSTALL_CMD putty remmina bleachbit -y
	fi
	echo "GUI_PACKAGES installation complete."
fi
# Change default shell to fish
echo "Changing default shell to fish..."
sudo chsh -s /usr/bin/fish
chsh -s /usr/bin/fish
read -p "Install KiCad, QUCS, and JLCEDA? (Y/y): " kicadin
if [[ "$kicadin" =~ ^[Yy]$ ]]; then
	if [[ "$ID" == "rocky" ]]; then
		echo "Only JLCEDA can be installed"
	elif [[ "$ID" == "fedora" ]]; then
		$INSTALL_CMD kicad qucs -y
	else
		$INSTALL_CMD kicad qucs -y
	fi
	wget https://image.lceda.cn/files/lceda-pro-linux-x64-2.2.27.1.zip
	unzip lceda-pro-linux-x64-2.2.27.1.zip
	sudo bash ./install.sh
	rm lceda-pro-linux-x64-2.2.27.1.zip
	echo "EDA software installation completed"
fi
# Install Visual Studio Code
echo "Installing Visual Studio Code..."
if [ "$PKG_MANAGER" = "pacman" ]; then
    curl -SLf https://142857.red/files/nvimrc-install.sh | bash
    sudo pacman -S --noconfirm base-devel git
    git clone https://aur.archlinux.org/visual-studio-code-bin.git
    cd visual-studio-code-bin
    makepkg -si --noconfirm
    cd ..
    rm -rf visual-studio-code-bin
elif [ "$PKG_MANAGER" = "dnf" ]; then
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
	sudo dnf check-update
	sudo dnf install code -y
	sudo dnf upgrade --refresh
	read -p "Install flatpak and some TOOLS? (Y/y): " clouds
	if [[ "$clouds" =~ ^[Yy]$ ]]; then
	    sudo dnf install -y flatpak
	    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
	    flatpak install -y flathub io.github.peazip.PeaZip com.github.flxzt.rnote
	fi
fi
read -p "Install Steam? (Y/y): " inssteam
if [[ "$inssteam" =~ ^[Yy]$ ]]; then
	if [ "$PKG_MANAGER" = "pacman" ]; then
		echo "Your environment is Arch, skipping."
	elif [ "$PKG_MANAGER" = "dnf" ]; then
		sudo dnf install steam -y
	fi
fi
# Configure localization
echo "Configuring locales..."
if [ "$PKG_MANAGER" = "dnf" ]; then
    sudo localectl set-locale LANG=en_US.UTF-8
elif [ "$PKG_MANAGER" = "pacman" ]; then
    sudo localectl set-locale LANG=en_US.UTF-8
else
    echo "Unsupported package manager: $PKG_MANAGER"
    exit 1
fi
cat cockpit.socket
rm cockpit.socket
echo "Installation and setup complete!"
