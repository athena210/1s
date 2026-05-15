#!/bin/bash

admin_container="admin_1s"

# shellcheck disable=SC2016
./cloud_manager.sh exec "$admin_container" bash -c '
    redis-cli -h "$REDIS_IP" --scan --pattern "license*" | while read -r LICVAR ; do
        NUM=$(redis-cli -h "$REDIS_IP" --raw get "$LICVAR")
        [ "$NUM" -lt 1 ] || printf "%d -> %s\n" "$NUM" "${LICVAR#license:}";
    done
'

