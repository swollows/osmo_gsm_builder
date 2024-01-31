#!/bin/bash

# 001. Pre-Initialization

SCRIPT_LOCATION_DIR=`pwd`
SRC_DIR="/usr/src"
OSMOCOM_REPO="https://downloads.osmocom.org/pakcages/osmocom:nightly/xUbuntu_22.04"
OSMOCOM_CONF="/etc/osmocom"
OSMOCOM_SRC="/usr/src/osmocom"
UHD_IMAGES_DIR="/usr/share/uhd/images/"
LD_LIBRARY_PATH="/usr/local/lib/"

OSMOCOM_REPO_LIST=("libosmocore" "libosmo-abis" "libosmo-netif" "libosmo-dsp" "libsmpp34" "libosmo-sccp" "libgtpnl" "osmo-trx" "osmo-bts" "osmo-bsc" "osmo-msc" "osmo-hlr" "osmo-mgw")
OSMOCOM_REPO_VERSION=("1.9.0" "1.5.0" "1.4.0" "0.4.0" "1.14.3" "1.8.0" "1.2.5" "1.6.0" "1.7.0" "1.11.0" "1.11.1" "1.7.0" "1.12.1")
ARR_LEN=${#OSMOCOM_REPO_LIST[@]}

for (( idx=0; idx<$ARR_LEN; idx++ ))
    do
        echo "${OSMOCOM_REPO_LIST[$idx]}"
        echo "${OSMOCOM_REPO_VERSION[$idx]}"

        cd ${OSMOCOM_SRC}/${OSMOCOM_REPO_LIST[$idx]}-${OSMOCOM_REPO_VERSION[$idx]}

        make clean
done

cd ${SRC_DIR}

rm -rf ${OSMOCOM_SRC}/*
mkdir -p ${OSMOCOM_CONF}/db ${OSMOCOM_CONF}/log ${OSMOCOM_SRC}

export UHD_IMAGES_DIR=${UHD_IMAGES_DIR}
export LD_LIGRARY_PATH=${LD_LIBRARY_PATH}

if [[ -z `cat /etc/bash.bashrc | grep UHD_IMAGES_DIR` ]]; then
        echo -e "\nexport UHD_IMAGES_DIR=${UHD_IMAGES_DIR}" >> /etc/bash.bashrc
else
        echo "env UHD_IMAGES_DIR is already set"
fi

if [[ -z `cat /etc/bash.bashrc | grep LD_LIBRARY_PATH` ]]; then
	echo -e "\nexport LD_LIBRARY_PATH=${LD_LIBRARY_PATH}" >> /etc/bash.bashrc
else
        echo "env LD_LIBRARY_PATH is already set"
fi

source /etc/bash.bashrc

# 002. Ubuntu APT Package List Update & Package Upgrade
apt-get update && apt-get upgrade

# 003. Ubuntu USRP Driver Repository Add
add-apt-repository -y ppa:ettusresearch/uhd

# 004. Update USRP Driver Repo to APT
apt-get update && apt-get upgrade

# 005. Install USRP Driver & Essential Packages to Build (or Install) Osmocom
apt-get install -y libuhd-dev uhd-host git build-essential libtool \
libtalloc-dev libsctp-dev shtool autoconf automake git-core pkg-config \
make gcc gnutls-dev libmnl-dev libpcsclite-dev liburing-dev libusb-1.0-0-dev \
libortp-dev dahdi-source dahdi-linux libssl-dev sqlite3 libsqlite3-dev libgtp-dev \
libsofia-sip-ua-glib-dev libc-ares-dev tmux python3-uhd

apt-get remove -y dahdi-dkms

# 007. Download UHD Driver Images
uhd_images_downloader

# 008. Clone And Build Essential Osmocom Repo
rm -rf ${OSMOCOM_SRC}/*

for (( idx=0; idx<$ARR_LEN; idx++ ))
    do
	echo "${OSMOCOM_REPO_LIST[$idx]}"
	echo "${OSMOCOM_REPO_VERSION[$idx]}"
         
        cd ${OSMOCOM_SRC}
        git clone -b ${OSMOCOM_REPO_VERSION[$idx]} https://github.com/osmocom/${OSMOCOM_REPO_LIST[$idx]} "/usr/src/osmocom/${OSMOCOM_REPO_LIST[$idx]}-${OSMOCOM_REPO_VERSION[$idx]}"
        cd "${OSMOCOM_REPO_LIST[$idx]}-${OSMOCOM_REPO_VERSION[$idx]}"
         
        autoreconf -i

        if [[ "${OSMOCOM_REPO_LIST[$idx]}" == "osmo-trx" ]]; then
            ./configure --with-uhd
        elif [[ "${OSMOCOM_REPO_LIST[$idx]}" == "osmo-bts" ]]; then
            ./configure --enable-trx
        else
            ./configure
        fi

        make -j$(nproc)
        make install -j$(nproc)
        ldconfig -i
done

# 009. Copy & Paste Custom Osmocom Settings
cp ${SCRIPT_LOCATION_DIR}/conf_bak/* /etc/osmocom/
