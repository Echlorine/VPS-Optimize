#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script!!!"
    exit 1
fi

Optimize_Ver='1.0'
. include/init.sh

Get_Dist_Name

if [ "${DISTRO}" = "unknow" ]; then
    Echo_Red "Unable to get Linux distribution name, or do NOT support the current distribution."
    exit 1
fi

change_passwd(){
    passwd $1
}

add_user(){
    adduser $1
    chmod u+w /etc/sudoers
    echo "$1    ALL=(ALL:ALL) ALL" >> /etc/sudoers
    chmod u-w /etc/sudoers
}

sshd_root(){
    Login_Count
    if [ ${user_num} -lt 2 ]; then
        Echo_Red "Only root can login, you should add new non-root user first."
        return $?
    fi
    [ ! `grep -EL "^ *PermitRootLogin yes" "/etc/ssh/sshd_config"` ] && sed -i 's/^ *PermitRootLogin yes/#PermitRootLogin yes/g' /etc/ssh/sshd_config
}

sshd_port(){
    [ ! `grep -EL "^ *Port 22" "/etc/ssh/sshd_config"` ] && sed -i 's/^ *Port 22/#Port 22/g' /etc/ssh/sshd_config
    if [ ! `grep -EL "^ *# *Port 22" "/etc/ssh/sshd_config"` ]; then
        sed -i '/^ *# *Port 22/i\Port '${sshd_port}'' /etc/ssh/sshd_config
    fi
    # sed -i '/Port '${sshd_port}'/a\Protocol 2' /etc/ssh/sshd_config
}

add_swap(){
    Disk_Avail=$(($(df -mP /var | tail -1 | awk '{print $4}' | sed s/[[:space:]]//g)/1024))

    DD_Count='1024'
    if [[ "${MemTotal}" -lt 1024 ]]; then
        DD_Count='1024'
        if [[ "${Disk_Avail}" -lt 5 ]]; then
            enable_swap='n'
        fi
    elif [[ "${MemTotal}" -ge 1024 && "${MemTotal}" -le 2048 ]]; then
        DD_Count='2048'
        if [[ "${Disk_Avail}" -lt 13 ]]; then
            enable_swap='n'
        fi
    elif [[ "${MemTotal}" -ge 2048 && "${MemTotal}" -le 4096 ]]; then
        DD_Count='4096'
        if [[ "${Disk_Avail}" -lt 17 ]]; then
            enable_swap='n'
        fi
    elif [[ "${MemTotal}" -ge 4096 && "${MemTotal}" -le 16384 ]]; then
        DD_Count='8192'
        if [[ "${Disk_Avail}" -lt 19 ]]; then
            enable_swap='n'
        fi
    elif [[ "${MemTotal}" -ge 16384 ]]; then
        DD_Count='8192'
        if [[ "${Disk_Avail}" -lt 27 ]]; then
            enable_swap='n'
        fi
    fi
    Swap_Total=$(free -m | grep Swap | awk '{print  $2}')
    if [[ "${enable_swap}" != "n" && "${Swap_Total}" -le 512 && ! -s /swapfile ]]; then
        echo "Add Swap file..."
        [ $(cat /proc/sys/vm/swappiness) -eq 0 ] && sysctl vm.swappiness=10
        dd if=/dev/zero of=/swapfile bs=1M count=${DD_Count}
        chmod 0600 /swapfile
        echo "Enable Swap..."
        /sbin/mkswap /swapfile
        if [ $? -eq 0 ]; then
            cp -a /etc/fstab /etc/fstab.bk
            [ `grep -L '/swapfile'    '/etc/fstab'` ] && echo "/swapfile none swap defaults 0 0" >>/etc/fstab
        else
            rm -f /swapfile
            echo "Add Swap Failed!"
        fi
    fi
}

sysctl_config(){
    [ ! `grep -EL "^ *vm.swappiness *=" "/etc/sysctl.conf"` ] && sed -i '/^ *vm.swappiness *=/d' /etc/sysctl.conf
    [ ! `grep -EL "^ *vm.vfs_cache_pressure *=" "/etc/sysctl.conf"` ] && sed -i '/^ *vm.vfs_cache_pressure *=/d' /etc/sysctl.conf
    [ ! `grep -EL "^ *net.core.rmem_max *=" "/etc/sysctl.conf"` ] && sed -i '/^ *net.core.rmem_max *=/d' /etc/sysctl.conf
    [ ! `grep -EL "^ *net.core.wmem_max *=" "/etc/sysctl.conf"` ] && sed -i '/^ *net.core.wmem_max *=/d' /etc/sysctl.conf
    cat >> /etc/sysctl.conf << EOF
# swappiness
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# UDP buffer
net.core.rmem_max = 16777216
net.core.wmem_max = 4194304
EOF
}

clear
echo "+------------------------------------------------------------------------+"
echo "|      Optimize V${Optimize_Ver} for ${DISTRO} Linux Server, Written by Echlorine.      |"
echo "+------------------------------------------------------------------------+"
echo "|                      A tool to optimize your VPS.                      |"
echo "+------------------------------------------------------------------------+"

Print_Sys_Info

Echo_Yellow "Do you want to change your password?"
read -p "Default no, Enter your choice [Y/n]: " passwd_choice
[[ ${passwd_choice} = "" ]] && echo "No input, do not change the password."
[[ ${passwd_choice} = "N" || ${passwd_choice} = "n" ]] && echo "do not change the password."
[[ ${passwd_choice} = "Y" || ${passwd_choice} = "y" ]] && echo "You choose to change the password."

Echo_Yellow "Do you want to add new non-root user?"
read -p "Default no, Enter your choice [Y/n]: " user_choice
[[ ${user_choice} = "" ]] && echo "No input, do not add new non-root user."
[[ ${user_choice} = "N" || ${user_choice} = "n" ]] && echo "do not add new non-root user."
[[ ${user_choice} = "Y" || ${user_choice} = "y" ]] && echo "You choose to add new non-root user."

Echo_Yellow "Do you want to permit root to login in?"
read -p "Default Yes, Enter your choice [Y/n]: " sshd_root
[[ ${sshd_root} = "" ]] && echo "No input, permit root to login in."
[[ ${sshd_root} = "N" || ${sshd_root} = "n" ]] && echo "do not permit root to login in."
[[ ${sshd_root} = "Y" || ${sshd_root} = "y" ]] && echo "You choose to permit root to login in."

Echo_Yellow "Which port do you want to login in?"
read -p "Default 22, Enter the ssh port (22 ~ 65535): " sshd_port
[[ ${sshd_port} = "" ]] && sshd_port="22"
echo "You will login in through port ${sshd_port}."

Echo_Yellow "Do you want to enable swap?"
read -p "Default Yes, Enter your choice [Y/n]: " enable_swap
[[ ${enable_swap} = "" ]] && echo "No input, enable swap."
[[ ${enable_swap} = "N" || ${enable_swap} = "n" ]] && echo "do not enable swap."
[[ ${enable_swap} = "Y" || ${enable_swap} = "y" ]] && echo "You choose to enable swap."

Press_Start
if [[ "${passwd_choice}" = "Y" || "${passwd_choice}" = "y" ]]; then
    Echo_Yellow "start change the world..."
    change_passwd
fi

if [[ "${user_choice}" = "Y" || "${user_choice}" = "y" ]]; then
    printf "\e[0;33mEnter the username of the new non-root user: \e[0m"
    read user_name
    if [[ "${user_name}" != "" ]]; then
        add_user ${user_name}
    else
        echo "illegal user"
    fi
fi

if [[ "${sshd_root}" = "N" || "${sshd_root}" = "n" ]]; then
    sshd_root
fi

sshd_port

if [[ "${enable_swap}" = "Y" || "${enable_swap}" = "y" ]]; then
    add_swap
fi

sysctl_config