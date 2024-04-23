#!/bin/bash

set -e
set -x

source manifest

pacman-key --populate

echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen

# Disable parallel downloads
sed -i '/ParallelDownloads/s/^/#/g' /etc/pacman.conf

# Cannot check space in chroot
sed -i '/CheckSpace/s/^/#/g' /etc/pacman.conf

# update package databases
pacman --noconfirm -Syy

# install kernel package
if [ "$KERNEL_PACKAGE_ORIGIN" == "local" ] ; then
	pacman --noconfirm -U --overwrite '*' \
	/own_pkgs/${KERNEL_PACKAGE}-*.pkg.tar.zst 
else
	pacman --noconfirm -S "${KERNEL_PACKAGE}" "${KERNEL_PACKAGE}-headers"
fi

for package in ${OWN_PACKAGES_TO_DELETE}; do
	rm -f /own_pkgs/\${package} || true
done

# install own override packages
pacman --noconfirm -U --overwrite '*' /own_pkgs/*
rm -rf /var/cache/pacman/pkg

# delete packages
for package in ${PACKAGES_TO_DELETE}; do
    echo "Checking if $package is installed"
	if [[ $(pacman -Qq $package) == "$package" ]]; then
		echo "\$package is installed, deleting"
		pacman --noconfirm -Rnsdd $package || true
	fi
done

# install packages
pacman --noconfirm -S --overwrite '*' --disable-download-timeout ${PACKAGES}
rm -rf /var/cache/pacman/pkg

# delete packages
for package in ${PACKAGES_TO_DELETE}; do
    echo "Checking if $package is installed"
	if [[ $(pacman -Qq $package) == "$package" ]]; then
		echo "\$package is installed, deleting"
		pacman --noconfirm -Rnsdd $package || true
	fi
done

# remove AUR packages
for package in ${AUR_PACKAGES_TO_DELETE}; do
	rm -f /extra_pkgs/\${package} || true
done

# install AUR packages
pacman --noconfirm -U --overwrite '*' /extra_pkgs/*
rm -rf /var/cache/pacman/pkg

# enable services
systemctl enable ${SERVICES}

# enable user services
systemctl --global enable ${USER_SERVICES}

# disable root login
passwd --lock root

# create user
groupadd -r autologin
useradd -m ${USERNAME} -G autologin,wheel,i2c,input
echo "${USERNAME}:${USERNAME}" | chpasswd

# set the default editor, so visudo works
echo "export EDITOR=/usr/bin/vim" >> /etc/bash.bashrc

echo "[Seat:*]
autologin-user=${USERNAME}
" > /etc/lightdm/lightdm.conf.d/00-autologin-user.conf

echo "${SYSTEM_NAME}" > /etc/hostname

# enable multicast dns in avahi
sed -i "/^hosts:/ s/resolve/mdns resolve/" /etc/nsswitch.conf

# configure ssh
echo "
AuthorizedKeysFile	.ssh/authorized_keys
PasswordAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
PrintMotd no # pam does that
Subsystem	sftp	/usr/lib/ssh/sftp-server
" > /etc/ssh/sshd_config

echo "
LABEL=frzr_root /var       btrfs subvol=var,rw,noatime,nodatacow,nofail 0 0
LABEL=frzr_root /home      btrfs subvol=home,rw,noatime,nodatacow,nofail 0 0
LABEL=frzr_root /frzr_root btrfs subvol=/,rw,noatime,nodatacow,x-initrd 0 2
overlay         /etc       overlay noauto,x-systemd.requires=/frzr_root,x-systemd.rw-only,lowerdir=/etc,upperdir=/frzr_root/etc,workdir=/frzr_root/.etc,index=off,metacopy=off,comment=etcoverlay    0   0
" > /etc/fstab

echo "
LSB_VERSION=1.4
DISTRIB_ID=${SYSTEM_NAME}
DISTRIB_RELEASE=\"${LSB_VERSION}\"
DISTRIB_DESCRIPTION=${SYSTEM_DESC}
" > /etc/lsb-release

echo "NAME=\"${SYSTEM_DESC}\"
VERSION_CODENAME=sk-chos
VERSION=\"${DISPLAY_VERSION}\"
VERSION_ID=\"${VERSION_NUMBER}\"
VARIANT_ID=sk-chimeraos
BUILD_ID=\"${BUILD_ID}\"
PRETTY_NAME=\"${SYSTEM_DESC} ${DISPLAY_VERSION}\"
ID=\"${SYSTEM_NAME}\"
ID_LIKE=arch
ANSI_COLOR=\"1;31\"
HOME_URL=\"${WEBSITE}\"
DOCUMENTATION_URL=\"${DOCUMENTATION_URL}\"
BUG_REPORT_URL=\"${BUG_REPORT_URL}\"" > /etc/os-release

# install extra certificates
trust anchor --store /extra_certs/*.crt

# run post install hook
postinstallhook

# pre-download
source /postinstall
postinstall_download

# record installed packages & versions
pacman -Q > /manifest

# preserve installed package database
mkdir -p /usr/var/lib/pacman
cp -r /var/lib/pacman/local /usr/var/lib/pacman/

# move kernel image and initrd to a defualt location if "linux" is not used
if [ ${KERNEL_PACKAGE} != 'linux' ] ; then
	mv /boot/vmlinuz-${KERNEL_PACKAGE} /boot/vmlinuz-linux
	mv /boot/initramfs-${KERNEL_PACKAGE}.img /boot/initramfs-linux.img
	mv /boot/initramfs-${KERNEL_PACKAGE}-fallback.img /boot/initramfs-linux-fallback.img
	rm /etc/mkinitcpio.d/${KERNEL_PACKAGE}.preset
fi

# clean up/remove unnecessary files
rm -rf \
/own_pkgs \
/extra_pkgs \
/extra_certs \
/home \
/var \

rm -rf ${FILES_TO_DELETE}

# create necessary directories
mkdir -p /home
mkdir -p /var
mkdir -p /frzr_root
mkdir -p /efi
mkdir -p /nix