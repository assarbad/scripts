#!/bin/bash
# vim: set autoindent smartindent ts=4 sw=4 sts=4 filetype=sh:
# In /etc/pam.d/sshd below pam_env and pam_selinux entries:
#    session    optional     pam_exec.so stdout /etc/ssh/ipset_sshd.sh
IPSET=/sbin/ipset
SETNAME=ssh_friends
if [[ "$PAM_TYPE" == "open_session" ]]; then
	if $IPSET list $SETNAME > /dev/null || $IPSET create $SETNAME hash:ip; then
		$IPSET test $SETNAME "[$PAM_RHOST]" 2> /dev/null > /dev/null || $IPSET add $SETNAME "[$PAM_RHOST]"
	fi
	$IPSET test $SETNAME "[$PAM_RHOST]"
fi
