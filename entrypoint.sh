#!/bin/sh
set -x

# Force user and group because lighttpd runs as webdav
USERNAME=webdav
GROUP=webdav

# Only allow read access by default
READWRITE=${READWRITE:=false}

# Add user if it does not exist
if ! id -u "${USERNAME}" >/dev/null 2>&1; then
    addgroup -g ${USER_GID:=2222} ${GROUP}
    adduser -G ${GROUP} -D -H -u ${USER_UID:=2222} ${USERNAME}
fi

chown webdav /var/log/lighttpd

# Force the /webdav directory to be owned by webdav/webdav otherwise we won't be
# able to write to it. This is ok if you mount from volumes, perhaps less if you
# mount from the host, so do this conditionally.
OWNERSHIP=${OWNERSHIP:=false}
if [ "$OWNERSHIP" -eq "true" ]; then
    chown -R webdav /webdav
    chgrp -R webdav /webdav
fi

# Setup whitelisting addresses. Adresses that are whitelisted will not need to
# enter credentials to access the webdav storage.
if [ -n "$WHITELIST" ]; then
    sed -i "s/WHITELIST/${WHITELIST}/" /etc/lighttpd/webdav.conf
fi

# Reflect the value of READWRITE into the lighttpd configuration
# webdav.is-readonly. Do this at all times, no matters what was in the file (so
# that THIS shell decides upon the R/W status and nothing else.)
if [ "$READWRITE" = true ]; then
    sed -i "s/is-readonly = \"\\w*\"/is-readonly = \"disable\"/" /etc/lighttpd/webdav.conf
else
    sed -i "s/is-readonly = \"\\w*\"/is-readonly = \"enable\"/" /etc/lighttpd/webdav.conf
fi

# Copy good default configuration files if we had none.
if [ ! -f /config/htpasswd ]; then
    cp /etc/lighttpd/htpasswd /config/htpasswd
fi

if [ ! -f /config/webdav.conf ]; then
    cp /etc/lighttpd/webdav.conf /config/webdav.conf
fi

# Run in foreground, see: https://redmine.lighttpd.net/issues/2731
mkfifo -m 600 /tmp/lighttpd.log
cat <> /tmp/lighttpd.log 1>&2 &
chown webdav /tmp/lighttpd.log
lighttpd -D -f /etc/lighttpd/lighttpd.conf 2>&1
