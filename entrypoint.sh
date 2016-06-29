#!/bin/sh
set -x

# Force user and group because lighttpd runs as webdav
if [ -z "$USERNAME" ]; then
    USERNAME=webdav
fi
if [ -z "$GROUP" ]; then
    GROUP=webdav
fi

# Only allow read access by default
READWRITE=${READWRITE:=false}

# Add user and group if they do not exist
if ! getent group "${GROUP}" >/dev/null 2>&1; then
    addgroup -g ${USER_GID:=2222} ${GROUP}
fi
if ! id -u "${USERNAME}" >/dev/null 2>&1; then
    adduser -G ${GROUP} -D -H -u ${USER_UID:=2222} ${USERNAME}
fi

chown ${USERNAME}:${GROUP} /var/log/lighttpd

# Create directory to hold locks
mkdir /locks
chown ${USERNAME}:${GROUP} /locks

# Force the /webdav directory to be owned by webdav/webdav otherwise we won't be
# able to write to it. This is ok if you mount from volumes, perhaps less if you
# mount from the host, so do this conditionally.
OWNERSHIP=${OWNERSHIP:=false}
if [ "$OWNERSHIP" == "true" ]; then
    chown -R ${USERNAME}:${GROUP} /webdav
fi

# Push further username and group name into the lighttpd configuration so they
# match what was decided upon through the configuration variables.
sed -i "s/server.username\\s*=\\s*\"\\w*\"/server.username = \"$USERNAME\"/g" /etc/lighttpd/lighttpd.conf
sed -i "s/server.groupname\\s*=\\s*\"\\w*\"/server.groupname = \"$GROUP\"/g" /etc/lighttpd/lighttpd.conf

# Setup whitelisting addresses. Adresses that are whitelisted will not need to
# enter credentials to access the webdav storage.
if [ -n "$WHITELIST" ]; then
    sed -i "s/WHITELIST/${WHITELIST}/" /etc/lighttpd/webdav.conf
fi

# Reflect the value of READWRITE into the lighttpd configuration
# webdav.is-readonly. Do this at all times, no matters what was in the file (so
# that THIS shell decides upon the R/W status and nothing else.)
if [ "$READWRITE" == "true" ]; then
    sed -i "s/is-readonly = \"\\w*\"/is-readonly = \"disable\"/g" /etc/lighttpd/webdav.conf
else
    sed -i "s/is-readonly = \"\\w*\"/is-readonly = \"enable\"/g" /etc/lighttpd/webdav.conf
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
exec lighttpd -D -f /etc/lighttpd/lighttpd.conf 2>&1
