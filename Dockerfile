FROM alpine:3.4
MAINTAINER Jeroen Geusebroek <me@jeroengeusebroek.nl>

ENV PACKAGE_LIST="lighttpd lighttpd-mod_webdav lighttpd-mod_auth" \
    REFRESHED_AT='2015-01-21'

RUN apk add --no-cache ${PACKAGE_LIST}

VOLUME [ "/config", "/webdav" ]

ADD files/* /etc/lighttpd/
ADD ./entrypoint.sh /entrypoint.sh

EXPOSE 80

RUN chmod u+x  /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]