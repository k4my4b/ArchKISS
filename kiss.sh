#!/usr/bin/env bash

# ---------------------------------------------------------------------------- #
#                   list of all stages to go through in order                  #
#    altering the order in which each fucntion is called can result in total   #
#       failure. Each function is followed by a short description used to      #
#                            display status message.                           #
#           If the string is empty no status update will be displayed          #
#                           feel free to add to this                           #
# ---------------------------------------------------------------------------- #

STAGES=(
    # print the logo and welcome message
    print_logo ""
    # make sure we have root privilege
    check_root "Checking root ..."
    # make sure we have internet connection
    check_connection "Checking connection ..."
    # update pacman repos
    update_pacman "Updating Pacman ..."
    # install reflector to update our mirrorlist, we don't want the installation to take forever
    install_reflector "Installing Reflector ..."
    # where are we ? where should we look for best servers ?
    find_country "Determining location ... ["${COUNTRY}"]"
    # update the mirrorlist accordingly
    update_mirrors "Updating mirrorlist ..."
    # enable ntp to automatically update the time and date
    enable_ntp "Enabling Network Time Protocol ..."
    # install the base packages first
    install_base "Installing base packages ..."
    # install all the remaining packages from the PACKAGES list one by one
    # this in itself doesn't have a status update but each package does
    install_pac ""
    # install a AUR packages
    install_aur ""
    # install a bootloader, i.e. Grub
    install_grub "Installing bootloader (Grub) ..."
)

# base packages
PACKAGES_BASE=(
    base
    base-devel
    linux
    linux-headers
    linux-firmware
)

# list of all other packages to be installed
PACKAGES=(
    # Nvidia stuff
    nvidia-dkms
    nvidia-settings
    ffnvcodec-headers
    libvdpau
    libxnvctrl
    nvidia-utils
    nvtop
    # Xorg stuff
    xorg
    xorg-xinit
    # SDDM
    sddm
    # KDE plasma
    plasma-meta
    # fonts
    ttf-roboto
    # <https://wiki.archlinux.org/index.php/Improving_performance#irqbalance> MUST ENABLE THE SERVICE
    irqbalance
)

# list of all AUR packages to be installed
PACKAGES_AUR=(
    https://aur.archlinux.org/trizen.git
    https://aur.archlinux.org/kwin-decoration-sierra-breeze-enhanced-git.git
    https://aur.archlinux.org/latte-dock-git.git
    https://aur.archlinux.org/ananicy-git.git
    https://aur.archlinux.org/kwin-lowlatency.git
)

# list of all services to enable
SYSTEMD_SERVICES=(
    irqbalance.service
)

# ---------------------------------------------------------------------------- #
#                                 Default Stuff                                #
# ---------------------------------------------------------------------------- #

# default pacman mirrorlist uri
MIRRORS_URI="/etc/pacman.d/mirrorlist"

# where to save the logs ?
LOG_FILE="/tmp/archkiss.log"

# default instllation route, default /mnt
MNT="/tmp"

# COLORS
RED="\e[91m"
GREEN="\e[92m"
COL_DEFAULT="\e[39m"

# status icons
ICO_DEF="☐"
ICO_OK="☑"
ICO_ERR="☒"

# spacer between status icon and description could be a space, a kiss a heart you name it
SPACER=" "

# default intendtaion i.e one tab before status print
INDENT="\t"

# ---------------------------------------------------------------------------- #
#                              Precedures Go Here                              #
# ---------------------------------------------------------------------------- #

print_logo() {
    echo -e "\n"
    echo -e "
    ${COL_DEFAULT} █████╗ ██████╗  ██████╗██╗  ██╗ ${RED}██ ▄█▀ ██▓  ██████   ██████
    ${COL_DEFAULT}██╔══██╗██╔══██╗██╔════╝██║  ██║ ${RED}██▄█▒ ▓██▒▒██    ▒ ▒██    ▒
    ${COL_DEFAULT}███████║██████╔╝██║     ███████║${RED}▓███▄░ ▒██▒░ ▓██▄   ░ ▓██▄
    ${COL_DEFAULT}██╔══██║██╔══██╗██║     ██╔══██║${RED}▓██ █▄ ░██░  ▒   ██▒  ▒   ██▒
    ${COL_DEFAULT}██║  ██║██║  ██║╚██████╗██║  ██║${RED}▒██▒ █▄░██░▒██████▒▒▒██████▒▒
                                    ${RED}▒ ▒▒ ▓▒░▓  ▒ ▒▓▒ ▒ ░▒ ▒▓▒ ▒ ░
    ${COL_DEFAULT}An Arch Linux installer brought ${RED}░ ░▒ ▒░ ▒ ░░ ░▒  ░ ░░ ░▒  ░ ░
    ${COL_DEFAULT}to you by Kamyab Sherafat,      ${RED}░ ░░ ░  ▒ ░░  ░  ░  ░  ░  ░
    ${COL_DEFAULT}github.com/k4my4b               ${RED}░  ░    ░        ░        ░
    "
    echo -e "${COL_DEFAULT}\n"
}

# make sure we have root privilege
check_root() {
    if ! [ "$(id -u)" = 0 ] 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# make sure we are connected
check_connection() {
    if ! ping -c 1 google.com 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# get pacman started
update_pacman() {
    if ! pacman -Syy 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# install reflector to get the mirrorlist updated, we don't want this installation to take forever
install_reflector() {
    if ! pacman -S --needed --noconfirm reflector 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# find location/country of user to pass to reflector
find_country() {
    if ! COUNTRY="$(whois "$(curl -sSL ifconfig.me)" | grep -iE -m1 ^country: | cut -d ' ' -f9)" 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# with a bit of luck we should we able to find some better mirrors around
update_mirrors() {
    if ! reflector -c "${COUNTRY}" --sort score --threads "$(nproc)" --save $MIRRORS_URI 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# enable network time sync
enable_ntp() {
    if ! timedatectl set-ntp true 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# install the base system
install_base() {
    if ! pacstrap "$MNT" "${PACKAGES_BASE[@]}" 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# install the rest of the packges this doesm't mean that these are not essential
install_pac() {
    echo -e "\t"
    echo -e "\t----- Installing Official Packages -----"
    echo -e "\t"
    for pac in "${PACKAGES[@]}"; do
        echo -ne "${INDENT}${COL_DEFAULT}${ICO_DEF}${SPACER}${COL_DEFAULT}$pac${COL_DEFAULT}"
        if pacstrap "${ROOT}" "$pac" 1>>$LOG_FILE 2>>$LOG_FILE; then
            echo -ne "\r"
            echo -e "${INDENT}${GREEN}${ICO_OK}${SPACER}${COL_DEFAULT}$pac${COL_DEFAULT}"
        else
            echo -ne "\r"
            echo -e "${INDENT}${RED}${ICO_ERR}${SPACER}${COL_DEFAULT}$pac${COL_DEFAULT}"
            echo -e "${RED}Installation failed at the above stage${COL_DEFAULT}"
            exit 1
        fi
    done
}

# install aur packages using PKGBUILD
install_aur() {
    echo -e "\t"
    echo -e "\t------- Installing AUR Packages --------"
    echo -e "\t"
    for pac in "${PACKAGES_AUR[@]}"; do
        # extract the package name from the aur link
        AUR_PAC_NAME="$(echo $pac | cut -d / -f 4 | cut -d . -f 1)"
        echo -ne "${INDENT}${COL_DEFAULT}${ICO_DEF}${SPACER}${COL_DEFAULT}${AUR_PAC_NAME}${COL_DEFAULT}"
        if (
            useradd kiss &&
                su kiss -c "
                git clone "$pac" /tmp/${AUR_PAC_NAME} &&
                cd /tmp/${AUR_PAC_NAME} &&
                makepkg -s &&
                exit &&"
            userdel kiss &&
                pacman --root ${ROOT} -U *.pkg.tar.xz
        ); then
            echo -ne "\r"
            echo -e "${INDENT}${GREEN}${ICO_OK}${SPACER}${COL_DEFAULT}${AUR_PAC_NAME}${COL_DEFAULT}"
        else
            echo -ne "\r"
            echo -e "${INDENT}${RED}${ICO_ERR}${SPACER}${COL_DEFAULT}${AUR_PAC_NAME}${COL_DEFAULT}"
            echo -e "${RED}Installation failed at the above stage${COL_DEFAULT}"
            exit 1
        fi
    done
}

# ---------------------------------------------------------------------------- #
#                              HERE BE DRAGONS !!!                             #
#                     avoid this mess as much as possible,                     #
#                   if you can clean it up knock yourself out                  #
# ---------------------------------------------------------------------------- #

main() {
    # delete the log file if it exists alread
    rm -f $LOG_FILE
    # create a logfile and makesure everyone can read/write
    touch $LOG_FILE && chmod 777 $LOG_FILE

    for ((n = 0; n < ${#STAGES[@]}; n += 2)); do
        # make a note (in the log file) of where we are now
        if (($((n % 2)) == 0)); then
            echo -e "-----------------------------------------------------------" >>$LOG_FILE
            echo -e " ${STAGES[$n]}                                             " >>$LOG_FILE
            echo -e "-----------------------------------------------------------" >>$LOG_FILE
        fi

        # if the stage has a description procced with status update
        if [[ -n ${STAGES[$((n + 1))]} ]]; then
            echo -ne "${INDENT}${COL_DEFAULT}${ICO_DEF}${SPACER}${STAGES[$((n + 1))]}${COL_DEFAULT}"
            if ${STAGES[$n]}; then
                echo -ne "\r"
                echo -e "${INDENT}${GREEN}${ICO_OK}${SPACER}${COL_DEFAULT}${STAGES[$((n + 1))]}${COL_DEFAULT}"
                echo -e "==> no errors encountered\n" >>$LOG_FILE
            else
                echo -ne "\r"
                echo -e "${INDENT}${RED}${ICO_ERR}${SPACER}${COL_DEFAULT}${STAGES[$((n + 1))]}${COL_DEFAULT}"
                echo -e "${RED}Installation failed at the above stage.${COL_DEFAULT}"
                echo -e "${RED}Take a look at the log here: $LOG_FILE${COL_DEFAULT}"
                exit 1
            fi
        else
            # otherwise do it quitely ...
            ${STAGES[$n]}
        fi
    done
}

# must make the call otherwise nothing will happen
main
