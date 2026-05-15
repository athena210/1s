#!/bin/bash

DIR_USER=1100
DIR_GROUP=1100


fix() {
    PERM="$1"
    DIR="$2"
    [ -n "$PERM" ] || return 1
    [ -d "$DIR" ] || return 1

    if [ -d "$DIR/lost+found/" ] ; then
        chown -Rf 0:0 "$DIR/lost+found/"
        chmod -Rf 700 "$DIR/lost+found/"
    fi

    find "$DIR" \
        -path "$DIR/lost+found" -prune -o \
        -type d \
        -exec chown "$PERM" {} + \
        -exec chmod 755 {} +

    find "$DIR" \
        -path "$DIR/lost+found" -prune -o \
        -type f \
        -exec chown "$PERM" {} + \
        -exec chmod 644 {} +
}



if \
    [ "$(id -u)" -ne 0 ] || \
    [ "$(id -g)" -ne 0 ]
then
    echo "Must be root."
    exit 1
fi


fix "$DIR_USER:$DIR_GROUP" /srv/1sadmin
fix "$DIR_USER:$DIR_GROUP" /srv/1sdaily
fix "$DIR_USER:$DIR_GROUP" /srv/1sdb1
fix "$DIR_USER:$DIR_GROUP" /srv/1smonthly

# chown -R "$DIR_USER:$DIR_GROUP" ./admin_tools
# chown -R "0:0" ./admin_tools/root
