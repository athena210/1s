#!/bin/bash

db_storage=/srv/1sdb1
start_config="/home/user1s/.1C/1cestart/ibases.v8i"

if \
    [ -z "$DIR_USER" ] || \
    [ -z "$DIR_GROUP" ] || \
    [ "$DIR_USER" != "$(id -u)" ] || \
    [ "$DIR_GROUP" != "$(id -g)" ]
then
    echo "Must be started from container."
    exit 1
fi

rec() {
    DB_PATH="$1"
    TITLE=$(basename "$DB_PATH")
    envsubst <<-EOF
[$TITLE]
Connect=File="$DB_PATH";
App=ThickClient
EOF
}

mv -f "$start_config" "${start_config}.bak"
find "$db_storage" \
    -path "$db_storage/lost+found" -prune -o \
    -name "a8b" -type d -prune -o \
    -name "a8z" -type d -prune -o \
    -type f -iname "1cv8.1cd" -print | \
    sort | while read -r fname
do
    rec "$(dirname "$fname")" | sed 's/$/\r/g' >> "$start_config"
done
