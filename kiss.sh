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
)

# list of all packages to be installed
PACKAGEES=(
)

# where to save the logs ?
LOG_FIEL="install.log"
LOG_DELIMITER="#-----------------------------------------------------------"

# default instllation route
MNT="/mnt"

# COLORS
RED="\e[91m"
WHITE="\e[97m"
GREEN="\e[92m"
COL_DEFAULT="\e[39m"

# default pacman mirrorlist uri
MIRRORS_URI="/etc/pacman.d/mirrorlist"

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
    if ! ping -c 3 google.com 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        return 1
    fi
}

# get pacman started
update_pacman() {
    if ! pacman -Syy 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        return 1
    fi
}

# install reflector to get the mirrorlist updated, we don't want this installation to take forever
install_reflector() {
    if ! pacman -S --needed --noconfirm reflector 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        return 1
    fi
}

# find location/country of user to pass to reflector
find_country() {
    if ! COUNTRY=$(whois $(curl -sSL ifconfig.me) | grep -iE -m1 ^country: | cut -d ' ' -f9) 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        return 1
    fi
}

# with a bit of luck we should we able to find some better mirrors around
update_mirrors() {
    if ! (reflector -c GB --sort score --threads $(nproc) --save $MIRRORS_URI) 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        return 1
    fi
}

# enable network time sync
enable_ntp() {
    if ! timedatectl set-ntp true 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        return 1
    fi
}

#----------------------------------------------------------------
#
#                         HEART OF THINGS
#
#----------------------------------------------------------------

# HERE BE DRAGONS !!!
# avoid this mess as much as possible, if you can clean it up knock yourself out
main() {
    for((n=0;n<${#STAGES[@]}; n+=2));
    do
        # make a note of where we are the log file
        if (( $((n % 2 )) == 0 )); then
            echo -e "${LOG_DELIMITER}\n# ${STAGES[$n]}\n${LOG_DELIMITER}" >> $LOG_FIEL
        fi
        
        # if the stage has a description procced with status update
        if [[ ! -z ${STAGES[$((n+1))]} ]]; then
            echo -ne "\t${WHITE}  ${STAGES[$((n+1))]}${COL_DEFAULT}"
            if ${STAGES[$n]}; then
                echo -ne "\r"
                echo -e "\t${GREEN}☑ ${WHITE}${STAGES[$((n+1))]}${COL_DEFAULT}"
                echo -e ">> no errors encountered\n" >> $LOG_FIEL
            else
                echo -ne "\r"
                echo -e "\t${RED}☒ ${WHITE}${STAGES[$((n+1))]}${COL_DEFAULT}"
                echo -e "${RED}Installation failed at the above stage"
                exit 1
            fi
        else
            # otherwise don't ...
            ${STAGES[$n]}
        fi
    done
}

# must make the call otherwise nothing will happen
main