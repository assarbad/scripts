#!/usr/bin/env bash
apt-mark unmarkauto bc
apt-get -y -f autoremove linux-virtual linux-image-ec2 linux-ec2 linux-image-2.6.32-73-virtual linux-image-2.6.32-376-ec2 memtest86+ grub-legacy-ec2 grub-pc grub-common
apt-get -y -f autoremove command-not-found command-not-found-data cloud-init cloud-utils dosfstools euca2ools friendly-recovery laptop-detect ntfs-3g openssh-server parted pciutils unattended-upgrades update-motd wpasupplicant wireless-tools ureadahead tasksel tasksel-data ssh-import lshw iptables update-manager
aptitude -y purge $(dpkg -l|awk '$1 ~ /^rc/ {print $2}')
apt-get -y clean
apt-get -y autoclean
aptitude -y clean
aptitude -y autoclean
rm -f /var/cache/apt/srcpkgcache.bin /var/cache/apt/pkgcache.bin
for i in /etc/.pwd.lock /var/log/*.{0..9} /var/log/*.{0..9}.gz /var/cache/apt/archives/partial/* /var/cache/debconf/*.dat-old; do
	[[ -e "$i" ]] && (set -x; rm -f "$i")
done
find /etc -type f -name '*.dpkg-old' -delete
rm -rf /root/.aptitude /root/.debtags /etc/ssh /etc/cloud
rm -f /root/.viminfo
