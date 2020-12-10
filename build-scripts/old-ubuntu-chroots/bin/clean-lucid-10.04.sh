#!/usr/bin/env bash
apt-mark unmarkauto bc
( ln -s /bin/true /bin/update-grub )
( set -x; env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y -f autoremove linux-virtual linux-image-ec2 linux-ec2 linux-image-2.6.32-73-virtual linux-image-2.6.32-376-ec2 memtest86+ grub-legacy-ec2 grub-pc grub-common )
( rm -f /bin/update-grub )
( set -x; env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y -f autoremove command-not-found command-not-found-data cloud-init cloud-utils dosfstools euca2ools friendly-recovery laptop-detect ntfs-3g openssh-server parted pciutils unattended-upgrades update-motd wpasupplicant wireless-tools ureadahead tasksel tasksel-data ssh-import lshw iptables update-manager openssh-client )
if type deborphan > /dev/null 2>&1; then
	ORPHANED=$(deborphan)
	if [[ -n "$ORPHANED" ]]; then
		env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y -f autoremove $ORPHANED
		ORPHANED=$(deborphan)
		if [[ -n "$ORPHANED" ]]; then
			env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y -f autoremove $ORPHANED
			ORPHANED=$(deborphan)
			if [[ -n "$ORPHANED" ]]; then
				env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y -f autoremove $ORPHANED
			fi
		fi
	fi
fi
env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true aptitude -y purge $(dpkg -l|awk '$1 ~ /^rc/ {print $2}')
env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y clean
env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true apt-get -y autoclean
env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true aptitude -y clean
env DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true aptitude -y autoclean
if type localepurge > /dev/null 2>&1; then
	localepurge
fi
rm -f /var/cache/apt/srcpkgcache.bin /var/cache/apt/pkgcache.bin /var/log/vmbuilder-install.log /var/log/bootstrap.log /var/log/apt/history.log /var/log/apt/term.log /var/log/aptitude /var/log/boot /var/log/btmp /var/log/dmesg /var/log/dpkg.log /var/log/faillog /var/log/fsck/checkfs /var/log/fsck/checkroot /var/log/lastlog /var/log/pycentral.log /var/log/wtmp
rmdir /lost+found /selinux
for i in /etc/.pwd.lock /var/log/*.{0..9} /var/log/*.{0..9}.gz /var/cache/apt/archives/partial/* /var/cache/debconf/*.dat-old /var/lib/dpkg/*-old; do
	[[ -e "$i" ]] && (set -x; rm -f "$i")
done
find /etc -type f -name '*.dpkg-old' -delete
rm -rf /root/.aptitude /root/.debtags /etc/ssh /etc/cloud /boot/grub
rm -f /root/.viminfo
