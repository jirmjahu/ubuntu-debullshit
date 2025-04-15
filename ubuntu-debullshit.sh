#!/usr/bin/env bash

disable_ubuntu_report() {
    ubuntu-report send no
    apt remove ubuntu-report -y
}

remove_appcrash_popup() {
    apt remove apport apport-gtk -y
}

remove_snaps() {
    while [ "$(snap list | wc -l)" -gt 0 ]; do
        for snap in $(snap list | tail -n +2 | cut -d ' ' -f 1); do
            snap remove --purge "$snap"
        done
    done

    systemctl stop snapd
    systemctl disable snapd
    systemctl mask snapd
    apt purge snapd -y
    rm -rf /snap /var/lib/snapd
    for userpath in /home/*; do
        rm -rf $userpath/snap
    done
    cat <<-EOF | tee /etc/apt/preferences.d/nosnap.pref
	Package: snapd
	Pin: release a=*
	Pin-Priority: -10
	EOF
}

disable_terminal_ads() {
    sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news
    pro config set apt_news=false
}

update_system() {
    apt update && apt upgrade -y
}

cleanup() {
    apt autoremove -y
}

setup_flathub() {
    apt install flatpak -y
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

gnome_software() {
    apt install -y gnome-software gnome-software-plugin-flatpak
    read -p "Do you want to install the Snap backend for GNOME Software? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        apt install -y gnome-software-plugin-snap
    fi
}

gsettings_wrapper() {
    if ! command -v dbus-launch; then
        sudo apt install dbus-x11 -y
    fi
    sudo -Hu $(logname) dbus-launch gsettings "$@"
}

remove_ubuntu_desktop() {
    apt remove ubuntu-session yaru-theme-* gnome-shell-extension-ubuntu-dock -y
}

setup_vanilla_gnome() {
    apt install qgnomeplatform-qt5 qgnomeplatform-qt6 -y
    apt install vanilla-gnome-desktop gnome-session -y

    # Reset gnome settings
    gsettings reset-recursively org.gnome.desktop.interface
    gsettings reset-recursively org.gnome.desktop.background
    gsettings reset-recursively org.gnome.desktop.screensaver
    gsettings reset-recursively org.gnome.desktop.wm.preferences
    gsettings reset-recursively org.gnome.shell
    gsettings reset-recursively org.gnome.nautilus.preferences
    gsettings reset-recursively org.gnome.nautilus.list-view
    gsettings reset-recursively org.gnome.desktop.input-sources
    gsettings reset-recursively org.gnome.desktop.peripherals.keyboard
    gsettings reset-recursively org.gnome.desktop.interface gtk-theme
    gsettings reset-recursively org.gnome.desktop.interface icon-theme
    gsettings reset-recursively org.gnome.desktop.interface font-name
    gsettings reset-recursively org.gnome.desktop.interface monospace-font-name
    gsettings reset-recursively org.gnome.desktop.interface cursor-theme
}

restore_firefox() {
    apt purge firefox -y
    snap remove --purge firefox
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- > /etc/apt/keyrings/packages.mozilla.org.asc
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list
    echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' > /etc/apt/preferences.d/mozilla
    apt update
    apt install firefox -y
}

install_kde() {
    apt install -y kde-plasma-desktop kde-standard kde-config-sddm sddm kde-style-breeze

    echo "sddm" > /etc/X11/default-display-manager

    systemctl disable gdm3 2>/dev/null || true
    systemctl disable lightdm 2>/dev/null || true
    systemctl enable sddm

    if [ -f /etc/sddm.conf ]; then
        sed -i 's/^Current=.*/Current=breeze/' /etc/sddm.conf
    else
        mkdir -p /etc/sddm.conf.d
        cat <<EOF > /etc/sddm.conf.d/kde_settings.conf
[Theme]
Current=breeze
EOF
    fi
}

replace_desktop() {
    echo
    read -p "Do you want to remove the Ubuntu Desktop (GNOME + Yaru)? (y/n): " rm_ubuntu_desktop
    if [[ "$rm_ubuntu_desktop" == "y" || "$rm_ubuntu_desktop" == "Y" ]]; then
        remove_ubuntu_desktop

        echo
        echo "What desktop environment do you want to install instead?"
        echo "1 - Vanilla GNOME"
        echo "2 - KDE Plasma"
        echo "3 - None"
        read -p "Enter your choice (1/2/3): " de_choice

        case $de_choice in
            1)
                msg 'Installing Vanilla GNOME session'
                setup_vanilla_gnome
                ;;
            2)
                msg 'Installing KDE Plasma desktop'
                install_kde
                ;;
            3)
                msg 'No desktop environment will be installed'
                ;;
            *)
                error_msg 'Invalid input. Skipping desktop install.'
                ;;
        esac
    else
    fi
}

ask_reboot() {
    echo 'Reboot now? (y/n)'
    while true; do
        read choice
        if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
            reboot
            exit 0
        fi
        if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
            break
        fi
    done
}

msg() {
    tput setaf 2
    echo "[*] $1"
    tput sgr0
}

error_msg() {
    tput setaf 1
    echo "[!] $1"
    tput sgr0
}

check_root_user() {
    if [ "$(id -u)" != 0 ]; then
        echo 'Please run the script as root!'
        echo 'We need to do administrative tasks'
        exit
    fi
}

show_menu() {
    echo -e ""
    echo -e "            Ubuntu Debullshit         "
    echo -e ""
    echo 'Choose an action:'
    echo '1 - Apply all optimizations and fixes'
    echo '2 - Disable Ubuntu report'
    echo '3 - Remove app crash popup'
    echo '4 - Remove snaps and snapd'
    echo '5 - Disable terminal ads (for LTS versions)'
    echo '6 - Replace Ubuntu Desktop (with GNOME / KDE / None)'
    echo '7 - Restore Firefox from the Mozilla repository'
    echo '8 - Install Flathub and GNOME Software'
    echo 'q - Exit'
    echo -e ""
    echo
}

main() {
    check_root_user
    while true; do
        show_menu
        read -p 'Enter your choice: ' choice
        case $choice in
            1)
                auto
                msg 'All actions completed!'
                ask_reboot
                ;;
            2)
                disable_ubuntu_report
                msg 'Ubuntu report disabled!'
                ;;
            3)
                remove_appcrash_popup
                msg 'App crash popup removed!'
                ;;
            4)
                remove_snaps
                msg 'Snaps and snapd removed!'
                ask_reboot
                ;;
            5)
                disable_terminal_ads
                msg 'Terminal ads disabled!'
                ;;
            6)
                replace_desktop
                ask_reboot
                ;;
            7)
                restore_firefox
                msg 'Firefox restored from Mozilla repository!'
                ;;
            8)
                update_system
                setup_flathub
                gnome_software
                msg 'Flathub and GNOME Software installed!'
                ask_reboot
                ;;
            q)
                exit 0
                ;;
            *)
                error_msg 'Wrong input!'
                ;;
        esac
    done
}

auto() {
    msg 'Updating system'
    update_system
    msg 'Disabling ubuntu report'
    disable_ubuntu_report
    msg 'Removing annoying app crash popup'
    remove_appcrash_popup
    msg 'Disabling terminal ads'
    disable_terminal_ads
    msg 'Removing snaps and snapd'
    remove_snaps
    msg 'Installing Flathub and GNOME Software'
    setup_flathub
    gnome_software
    msg 'Restoring Firefox from Mozilla repository'
    restore_firefox
    replace_desktop
    cleanup
    msg 'Complete!'
}

main
