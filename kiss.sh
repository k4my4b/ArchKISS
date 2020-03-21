#!/usr/bin/env bash

# list of all functions to go through in order
# altering the order in which each fucntion is called can result in total failure
# feel free to add to this
FUNCTIONS=(
    #1- print the logo and welcome message
    print_logo
    #2- make sure we have root privilege
    check_root
    #3- update pacman repos
    update_pacman
    #4- install reflector to update our mirrorlist, we don't want the installation to take forever
    install_reflector
    #5- where are we ? where should we look for best servers ?
    find_country
    #6- update the mirrorlist accordingly
    update_mirrors
)

# list of all packages to be installed
PACKAGEES=(

)

#where to save the logs ? 
LOG_FIEL="install.log"
LOG_DELIMITER="#-----------------------------------------------------------"

#COLORS
RED="\e[91m"
WHITE="\e[97m"
GREEN="\e[92m"
COL_DEFAULT="\e[39m"

#default pacman mirrorlist uri
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
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}\t☑ ${WHITE}Checking for root${COL_DEFAULT}"
    else
        echo -e "${RED}\t☒ ${WHITE}Checking for root"
        echo -e "${RED}This script must be run as root${COL_DEFAULT}"
        exit 1
    fi
}

# get pacman started
update_pacman() {
    if pacman -Syy 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        echo -e "${GREEN}\t☑ ${WHITE}Updating pacman${COL_DEFAULT}"
    else
        echo -e "${RED}\t☒ ${WHITE}Updating pacman${COL_DEFAULT}"
        echo -e "Installation failed at this point, Sorry!"
        exit 1
    fi
}

# install reflector to get the mirrorlist updated, we don't want this installation to take forever
install_reflector() {
    if pacman -S --needed --noconfirm reflector 1>> $LOG_FIEL 2>> $LOG_FIEL; then 
        echo -e "${GREEN}\t☑ ${WHITE}Installing reflector${COL_DEFAULT}"
    else 
        echo -e "${RED}\t☒ ${WHITE}Installing reflector${COL_DEFAULT}"
        echo -e "Installation failed at this point, Sorry!"
        exit 1
    fi
}

# find location/country of user to pass to reflector
find_country() {
    if COUNTRY=$(whois $(curl -sSL ifconfig.me) | grep -iE ^country: | cut -d ' ' -f9) 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        echo -e "${GREEN}\t☑ ${WHITE}Getting location [${GREEN}$COUNTRY${WHITE}]${COL_DEFAULT}"
    else 
        echo -e "${RED}\t☒ ${WHITE}Getting location${COL_DEFAULT}"
        echo -e "Installation failed at this point, Sorry!"
        exit 1
    fi
}

# with a bit of luck we should we able to find some better mirrors around
update_mirrors() {
    if (reflector -c GB --sort score --threads $(nproc) --save $MIRRORS_URI) 1>> $LOG_FIEL 2>> $LOG_FIEL; then
        echo -e "${GREEN}\t☑ ${WHITE}Updating mirrors${COL_DEFAULT}"
    else 
        echo -e "${RED}\t☒ ${WHITE}Updating mirrors${COL_DEFAULT}"
        echo -e "Installation failed at this point, Sorry!"
        exit 1
    fi
}

#----------------------------------------------------------------
#
#                           START HERE
#
#----------------------------------------------------------------

for func in ${FUNCTIONS[@]}
do 
    echo -e "${LOG_DELIMITER}\n# $func\n${LOG_DELIMITER}" >> $LOG_FIEL
    $func && echo -e ">> no errors encountered\n" >> $LOG_FIEL || echo -e "\n" >> $LOG_FIEL
done