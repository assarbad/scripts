#!/usr/bin/env bash
LOCALNAME="$1"
REMOTEURL="$2"
function syntax_help
{
  echo -e "Syntax:\n\tsvnsync-init <local> <remote>"
  exit 1
}

[[ -n "$LOCALNAME" ]] || syntax_help
[[ -n "$REMOTEURL" ]] || syntax_help

# Set default absolute path if it isn't alreay absolute ...
[[ "${LOCALNAME:0:1}" == "/" ]] || LOCALNAME="$HOME/ext-repos/SVNSYNC/$LOCALNAME"

# Now they definitely shouldn't be identical anymore
[[ "$LOCALNAME" != "$REMOTEURL" ]] || syntax_help

[[ ! -d "$LOCALNAME" ]] || { echo -e "A local folder $LOCALNAME already exists."; exit 1; }
echo "Repo: $LOCALNAME"
svnadmin create "$LOCALNAME"
echo "svnadmin create \"$LOCALNAME\""
echo '#!/bin/sh'|tee "$LOCALNAME/hooks/pre-revprop-change" && chmod +x "$LOCALNAME/hooks/pre-revprop-change"
echo "echo '#!/bin/sh'|tee \"$LOCALNAME/hooks/pre-revprop-change\" && chmod +x \"$LOCALNAME/hooks/pre-revprop-change\""
svnsync init "file://$LOCALNAME" "$REMOTEURL"
echo "svnsync init \"file://$LOCALNAME\" \"$REMOTEURL\""
svnsync sync "file://$LOCALNAME"
echo "svnsync sync \"file://$LOCALNAME\""
