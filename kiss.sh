#!/usr/bin/env bash

# list of all stages to go through in order
# altering the order in which each fucntion is called can result in total failure
# each function is followed by a short description used display status, if
# the string is empty no status update will be displayed
# feel free to add to this
STAGES=(
    #1- print the logo and welcome message
    print_logo ""
    #2- make sure we have root privilege
    check_root "Checking root ..."
    #3- make sure we have internet connection
    check_connection "Checking connection ..."
    #4- update pacman repos
    update_pacman "Updating pacman ..."
    #5- install reflector to update our mirrorlist, we don't want the installation to take forever
    install_reflector "Installing reflector ..."
    #6- where are we ? where should we look for best servers ?
    find_country "Determining location ..."
    #7- update the mirrorlist accordingly
    update_mirrors "Updating mirrorlist ..."
    #8- enable ntp to automatically update the time and date
    enable_ntp "Enabling Network Time Protocol ..."
    #9- install the base packages first
    #install_base "Installing base packages ..."
    #10- install all the remaining packages from the PACKAGES list one by one
    # this in itself doesn't have a status update but each package does
    #install_pac ""
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
)

# list of all AUR packages to be installed
PACKAGES_AUR=()

#----------------------------------------------------------------
#
#                          Default Stuff
#
#----------------------------------------------------------------

# default pacman mirrorlist uri
MIRRORS_URI="/etc/pacman.d/mirrorlist"

# where to save the logs ?
LOG_FILE="/tmp/archkiss.log"

# default instllation route, default /mnt
MNT="/tmp"

# COLORS
RED="\e[91m"
WHITE="\e[97m"
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

#----------------------------------------------------------------
#
#                     Precedures Go Here
#
#----------------------------------------------------------------

print_logo() {
    echo -e "\n"
    echo -e "
    ${WHITE} █████╗ ██████╗  ██████╗██╗  ██╗ ${RED}██ ▄█▀ ██▓  ██████   ██████${WHITE}
    ${WHITE}██╔══██╗██╔══██╗██╔════╝██║  ██║ ${RED}██▄█▒ ▓██▒▒██    ▒ ▒██    ▒${WHITE}
    ${WHITE}███████║██████╔╝██║     ███████║${RED}▓███▄░ ▒██▒░ ▓██▄   ░ ▓██▄${WHITE}
    ${WHITE}██╔══██║██╔══██╗██║     ██╔══██║${RED}▓██ █▄ ░██░  ▒   ██▒  ▒   ██▒${WHITE}
    ${WHITE}██║  ██║██║  ██║╚██████╗██║  ██║${RED}▒██▒ █▄░██░▒██████▒▒▒██████▒▒${WHITE}
                                    ${RED}▒ ▒▒ ▓▒░▓  ▒ ▒▓▒ ▒ ░▒ ▒▓▒ ▒ ░${WHITE}
    ${COL_DEFAULT}An Arch Linux installer brought ${RED}░ ░▒ ▒░ ▒ ░░ ░▒  ░ ░░ ░▒  ░ ░${WHITE}
    ${COL_DEFAULT}to you by Kamyab Sherafat,      ${RED}░ ░░ ░  ▒ ░░  ░  ░  ░  ░  ░${WHITE}
    ${COL_DEFAULT}github.com/k4my4b               ${RED}░  ░    ░        ░        ░${WHITE}
    "
    echo -e "\n"
}

# make sure we have root privilege
check_root() {
    if [[ ! $EUID -eq 0 ]]; then
        return 1
    fi
}

# make sure we are connected
check_connection() {
    if ! ping -c 3 google.com 1>>$LOG_FILE 2>>$LOG_FILE; then
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
    if ! COUNTRY=$(whois $(curl -sSL ifconfig.me) | grep -iE -m1 ^country: | cut -d ' ' -f9) 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# with a bit of luck we should we able to find some better mirrors around
update_mirrors() {
    if ! (reflector -c ${COUNTRY} --sort score --threads $(nproc) --save $MIRRORS_URI) 1>>$LOG_FILE 2>>$LOG_FILE; then
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
    if ! pacstrap $MNT ${PACKAGES_BASE[@]} 1>>$LOG_FILE 2>>$LOG_FILE; then
        return 1
    fi
}

# install the rest of the packges this doesm't mean that these are non-essential
install_pac() {
    echo -e "\t---------------------------------------"
    echo -e "\t          Installing Packages          "
    echo -e "\t---------------------------------------"
    for pac in ${PACKAGES[@]}; do
        echo -ne "${INDENT}${GREEN}${ICO_DEF}${SPACER}${WHITE}$pac${COL_DEFAULT}"
        if pacstrap $MNT $pac 1>>$LOG_FILE 2>>$LOG_FILE; then
            echo -ne "\r"
            echo -e "${INDENT}${GREEN}${ICO_OK}${SPACER}${WHITE}$pac${COL_DEFAULT}"
        else
            echo -ne "\r"
            echo -e "${INDENT}${GREEN}${ICO_ERR}${SPACER}${WHITE}$pac${COL_DEFAULT}"
            echo -e "${RED}Installation failed at the above stage"
            exit 1
        fi
    done
}

# install trizen from aur using PKGBUILD
install_trizen() {
    git clone https://aur.archlinux.org/trizen.git /tmp/trizen && cd /tmp/trizen && makepkg -s && pacman --root /tmp -U trizen-*.pkg.tar.xz
}

#----------------------------------------------------------------
#
#                        HERE BE DRAGONS !!!
#
#----------------------------------------------------------------

# avoid this mess as much as possible, if you can clean it up knock yourself out
main() {
    # create a logfile and makesure everyone and read/write
    touch $LOG_FILE && chmod 666 $LOG_FILE

    for ((n = 0; n < ${#STAGES[@]}; n += 2)); do
        # make a note (in the log file) of where we are now
        if (($((n % 2)) == 0)); then
            # echo -ne "${LOG_DELIMITER}\n# \n${LOG_DELIMITER}" >>$LOG_FILE
            echo -e "-----------------------------------------------------------" >>$LOG_FILE
            echo -e " ${STAGES[$n]}                                             " >>$LOG_FILE
            echo -e "-----------------------------------------------------------" >>$LOG_FILE
        fi

        # if the stage has a description procced with status update
        if [[ ! -z ${STAGES[$((n + 1))]} ]]; then
            echo -ne "${INDENT}${WHITE}${ICO_DEF}${SPACER}${STAGES[$((n + 1))]}${COL_DEFAULT}"
            if ${STAGES[$n]}; then
                echo -ne "\r"
                echo -e "${INDENT}${GREEN}${ICO_OK}${SPACER}${WHITE}${STAGES[$((n + 1))]}${COL_DEFAULT}"
                echo -e ">> no errors encountered\n" >>$LOG_FILE
            else
                echo -ne "\r"
                echo -e "${INDENT}${RED}${ICO_ERR}${SPACER}${WHITE}${STAGES[$((n + 1))]}${COL_DEFAULT}"
                echo -e "${RED}Installation failed at the above stage"
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
