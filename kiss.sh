#!/usr/bin/env bash

# ---------------------------------------------------------------------------- #
#     This program is free software: you can redistribute it and/or modify     #
#     it under the terms of the GNU General Public License as published by     #
#       the Free Software Foundation, either version 3 of the License, or      #
#                      (at your option) any later version.                     #
#        This program is distributed in the hope that it will be useful,       #
#        but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#         MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
#                 GNU General Public License for more details.                 #
#       You should have received a copy of the GNU General Public License      #
#     along with this program.  If not, see <https://www.gnu.org/licenses/>    #
# ---------------------------------------------------------------------------- #

# each stage followed by a description that will be displayed status of that said satge.
# an empty message, "", would display no status
STAGES=(
    # print the logo and welcome message
    print_logo ""
    # make sure we have root privilege
    check_root "Checking root ..."
    # make sure we have internet connection
    check_connection "Checking connection ..."
    # update pacman repos
    update_pacman "Updating pacman ..."
    # install reflector to update our mirrorlist,
    # we don't want the installation to take forever
    install_reflector "Installing reflector ..."
    # install whois, we need this for the next step
    install_whois "Installing whois"
    # where are we ? where should we look for best servers ?
    find_country "Determining location ... ["${COUNTRY}"]"
    # update the mirrorlist accordingly
    update_mirrors "Updating mirrorlist ..."
    # enable ntp to automatically update the time and date
    enable_ntp "Enabling Network Time Protocol ..."
    # install the base packages first
    install_base "Installing base packages ..."
    # install all the remaining packages from the PACKAGES list one by one
    # this in itself doesn't have a status msg but each package does
    install_pac ""
    # install fakeroot needed for compiling aur packages
    install_fakeroot "Installing fakeroot ..."
    # install binutils needed for compiling aur pacakges
    install_binutils "Installing binutils ..."
    # install git, we need this to retrieve aur packages
    install_git "Installing git ..."
    # add the required installer user otherwise we can't
    # compile and install aur packages
    useradd_kiss "Adding ArchKISS user ..."
    # install a AUR packages
    install_aur ""
    # install a bootloader, i.e. Grub
    install_grub "Installing bootloader (Grub) ..."
)

# base packages (why are these seperate ? pacstrap.)
PACKAGES_BASE=(
    base
    base-devel
    linux
    linux-headers
    linux-firmware
)

# list of all other packages to be installed (pacman)
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
# (these will most likely have to be compiled)
PACKAGES_AUR=(
    https://aur.archlinux.org/trizen.git
    https://aur.archlinux.org/kwin-decoration-sierra-breeze-enhanced-git.git
    #2 https://aur.archlinux.org/latte-dock-git.git
    https://aur.archlinux.org/ananicy-git.git
    https://aur.archlinux.org/kwin-lowlatency.git
)

# list of all services to enable
SYSTEMD_SERVICES=(
    nvidia-suspend.service
    nvidia-hibernate.service
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
# this means you should mount everything under e.g. /mnt before calling ArchKISS
# everything means:
#                 /<root>
#                 /boot/efi
#                 /<whatever you might want to have mounted automatically>
ROOT="/tmp"

# installer username (a user with this name will be created)
# this user has all the previliges without password requirement
# we need this for compiling aur packages etc...
ARCHKISS_USER="kiss"

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
     ${COL_DEFAULT}█████╗ ██████╗  ██████╗██╗  ██╗ ${RED}██ ▄█▀ ██▓  ██████   ██████
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
    if ! [ "$(id -u)" = 0 ] 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# make sure we are connected
check_connection() {
    if ! ping -c 1 google.com 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# get pacman started
update_pacman() {
    if ! pacman -Sy 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# install reflector to get the mirrorlist updated,
# we don't want this installation to take forever
install_reflector() {
    if ! pacman --needed --noconfirm -S reflector 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# install whois package we need this for the next step
install_whois() {
    if ! pacman --needed --noconfirm -S whois 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# find location/country of user to pass to reflector
find_country() {
    if ! COUNTRY="$(whois "$(curl -sSL ifconfig.me)" | grep -iE -m1 ^country: | cut -d ' ' -f9)" 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# with a bit of luck we should we able to find some better mirrors around
update_mirrors() {
    if ! reflector -c "${COUNTRY}" --latest 5 --sort rate --threads "$(nproc)" --save $MIRRORS_URI 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# enable network time sync
enable_ntp() {
    if ! timedatectl set-ntp true 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# install the base system
install_base() {
    if ! pacstrap "${ROOT}" "${PACKAGES_BASE[@]}" 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# install the packages we need for a properly usable system
# these are in the official repository so we don't have to
# compile them
install_pac() {
    echo -e "\t"
    echo -e "\t----- Installing Official Packages -----"
    echo -e "\t"
    for pac in "${PACKAGES[@]}"; do
        echo -ne "${INDENT}${COL_DEFAULT}${ICO_DEF}${SPACER}${COL_DEFAULT}$pac${COL_DEFAULT}"
        if pacman --needed --noconfirm --root "${ROOT}" -S "$pac" 1>>${LOG_FILE} 2>>${LOG_FILE}; then
            echo -ne "\r"
            echo -e "${INDENT}${GREEN}${ICO_OK}${SPACER}${COL_DEFAULT}$pac${COL_DEFAULT}"
        else
            echo -ne "\r"
            echo -e "${INDENT}${RED}${ICO_ERR}${SPACER}${COL_DEFAULT}$pac${COL_DEFAULT}"
            echo -e "${RED}Installation failed at the above stage${COL_DEFAULT}"
            exit 1
        fi
    done
    echo -e "\t"
    echo -e "\t----------------- Done -----------------"
    echo -e "\t"
}

# install fakeroot package we need this for the next step
install_fakeroot() {
    if ! pacman --needed --noconfirm -S fakeroot 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# install binutils package we need this for the next step
install_binutils() {
    if ! pacman --needed --noconfirm -S binutils 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# install git, we need to pull in the aur packages using git
install_git() {
    if ! pacman --needed --noconfirm -S git 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# adding a none root user with the all the privillages
# is neccessary for compiling aur package (none-root) and installing
# dependencies (root)
useradd_kiss() {
    if ! (
        useradd "${ARCHKISS_USER}" &&
            echo "${ARCHKISS_USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${ARCHKISS_USER}
    ) 1>>${LOG_FILE} 2>>${LOG_FILE}; then
        return 1
    fi
}

# install aur packages using PKGBUILD
install_aur() {
    echo -e "\t"
    echo -e "\t------- Installing AUR Packages --------"
    echo -e "\t"
    for pac in "${PACKAGES_AUR[@]}"; do
        # extract the package name from the aur link
        AUR_PAC_NAME="$(echo ${pac} | cut -d / -f 4 | cut -d . -f 1)"
        echo -ne "${INDENT}${COL_DEFAULT}${ICO_DEF}${SPACER}${COL_DEFAULT}${AUR_PAC_NAME}${COL_DEFAULT}"
        if (
            su "${ARCHKISS_USER}" -c "git clone "${pac}" ${ROOT}/tmp/${AUR_PAC_NAME} && cd ${ROOT}/tmp/${AUR_PAC_NAME} && MAKEFLAGS="-j$(nproc)" makepkg -s --noconfirm --needed"
            pacman --noconfirm --needed --root "${ROOT}" -U ${ROOT}/tmp/${AUR_PAC_NAME}/*.pkg.tar.xz
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
    echo -e "\t"
    echo -e "\t----------------- Done -----------------"
    echo -e "\t"
}

# ---------------------------------------------------------------------------- #
#                              HERE BE DRAGONS !!!                             #
#                     avoid this mess as much as possible,                     #
#                   if you can clean it up knock yourself out                  #
# ---------------------------------------------------------------------------- #

main() {
    # delete the log file if it exists alread
    rm -f ${LOG_FILE}
    # create a logfile and makesure everyone can read/write
    touch ${LOG_FILE} && chmod 777 ${LOG_FILE}

    trap "userdel kiss" SIGINT
    trap "userdel kiss" EXIT

    for ((n = 0; n < ${#STAGES[@]}; n += 2)); do
        # make a note (in the log file) of where we are now
        if (($((n % 2)) == 0)); then
            echo -e "-----------------------------------------------------------" >>${LOG_FILE}
            echo -e " ${STAGES[$n]}                                             " >>${LOG_FILE}
            echo -e "-----------------------------------------------------------" >>${LOG_FILE}
        fi

        # if the stage has a description procced with status update
        if [[ -n ${STAGES[$((n + 1))]} ]]; then
            echo -ne "${INDENT}${COL_DEFAULT}${ICO_DEF}${SPACER}${STAGES[$((n + 1))]}${COL_DEFAULT}"
            if ${STAGES[$n]}; then
                echo -ne "\r"
                echo -e "${INDENT}${GREEN}${ICO_OK}${SPACER}${COL_DEFAULT}${STAGES[$((n + 1))]}${COL_DEFAULT}"
                echo -e "==> no errors encountered\n" >>${LOG_FILE}
            else
                echo -ne "\r"
                echo -e "${INDENT}${RED}${ICO_ERR}${SPACER}${COL_DEFAULT}${STAGES[$((n + 1))]}${COL_DEFAULT}"
                echo -e "${RED}Installation failed at the above stage.${COL_DEFAULT}"
                echo -e "${RED}Take a look at the log here: ${LOG_FILE}${COL_DEFAULT}"
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
