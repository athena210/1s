#!/bin/sh


FILE_DB_LIST=./db.list

LIST_ADD=$(cat << EOF
x gate_1s
x samba_1s
x backup_1s
x redis_1s
hasp6.nrcorp.ru admin_1s
EOF
)


# convert ip to integer
ip2long() {
    IFS=. read -r a b c d <<EOF
$1
EOF
    echo "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
}


# convert integer to ip
long2ip() {
    echo "$(( ($1 >> 24) & 255 )).$(( ($1 >> 16) & 255 )).$(( ($1 >> 8) & 255 )).$(( $1 & 255 ))"
}


get_free_ip() {
    NET_NAME="cluster_net"
    RESERVED_NUM=6

    # Get network cidr (10.0.0.0/24)
    CIDR=$(docker network inspect "$NET_NAME" --format '{{(index .IPAM.Config 0).Subnet}}')
    #'
    [ -n "$CIDR" ] || return 1

    # split ip and mask
    IP_PART="${CIDR%/*}"
    MASK="${CIDR#*/}"


    # net starts from this integer
    NET_LONG=$(ip2long "$IP_PART")

    # do search from start+reserved
    START_LONG=$(( NET_LONG + RESERVED_NUM ))

    # net ends on this integer
    HOSTS=$(( 1 << (32 - MASK) ))
    END_LONG=$(( NET_LONG + HOSTS - 2 ))


    # get ocuppied ip addresses
    USED_LONGS=""
    for ip in $(docker network inspect "$NET_NAME" --format '{{range .Containers}}{{.IPv4Address}}{{println}}{{end}}' | cut -d/ -f1); do
        USED_LONGS="$USED_LONGS $(ip2long "$ip")"
    done

    # loop looking a free one
    candidate=$START_LONG
    while [ "$candidate" -le "$END_LONG" ]; do
        is_busy=0
        for used in $USED_LONGS; do
            if [ "$candidate" -eq "$used" ]; then
                is_busy=1
                break
            fi
        done

        if [ "$is_busy" -eq 0 ]; then
            long2ip "$candidate"
            return 0
        fi
        candidate=$((candidate + 1))
    done

    return 1
}


#is_system() {
#    BASE_NAME="$1"
#    if \
#        [ "$BASE_NAME" = "gate_1s" ] || \
#        [ "$BASE_NAME" = "redis_1s" ] || \
#        [ "$BASE_NAME" = "admin_1s" ] || \
#        [ "$BASE_NAME" = "samba_1s" ] || \
#        [ "$BASE_NAME" = "backup_1s" ]
#    then
#        return 0
#    fi
#    return 1
#}


####################################################



if \
    [ "$(id -u)" -ne 0 ] || \
    [ "$(id -g)" -ne 0 ]
then
    echo "Must be root."
    exit 1
fi


if [ ! -f "$FILE_DB_LIST" ] ; then
    echo "No db list found ($FILE_DB_LIST)"
    exit 1
fi


COMMAND="${1:-empty_command}"
NAME="${2:-empty_name}"

case "$COMMAND" in
    start|stop|status|logs|exec)
        ;;

    net)
        docker network inspect cluster_net | jq -r '
            .[] | .Containers | to_entries | map({
                ip: .value.IPv4Address | split("/")[0],
                name: .value.Name,
                sort_key: .value.IPv4Address | split("/")[0] | split(".") | map(tonumber)
            })
            | sort_by(.sort_key)
            | .[] | "\(.ip)\t\(.name)"'

        ;;

    *)
        echo "Error: command is (${1:-EMPTY}). Must be start, stop, net or status"
        echo "Usage:"
        echo "  help"
        exit 1
        ;;
esac

tmpfile=$(mktemp) || exit 1

{
    cat "$FILE_DB_LIST"
    echo "$LIST_ADD"
} | \
    sed 's/^[[:space:]]*//' | \
    sed '/^$/d' | \
    sed '/^#/d' \
    > "$tmpfile"
exec 3< "$tmpfile"

while read -r HASP_SERVER BASE_DIR JUNK <&3; do
    BASE_NAME="$(basename "$BASE_DIR")"
    SERVICE_NAME="worker_1s"
    if [ -z "$HASP_SERVER" ] ; then
        echo "No hasp server specified for $BASE_NAME"
        continue
    fi

    case "$COMMAND" in
        start)
            CLUSTER_IP=$(get_free_ip)
            CLUSTER_IP_FOUND=$?
            if [ "$CLUSTER_IP_FOUND" -ne 0 ] ; then
                echo "Can not find any free ip"
                exit 1
            fi
            instance_class=workers

            if \
                [ "$BASE_NAME" = "gate_1s" ] || \
                [ "$BASE_NAME" = "redis_1s" ] || \
                [ "$BASE_NAME" = "samba_1s" ] || \
                [ "$BASE_NAME" = "backup_1s" ]
            then
                BASE_DIR=x
                HASP_SERVER=x
                CLUSTER_IP=x
                SERVICE_NAME="$BASE_NAME"
                instance_class=system
            fi

            if [ "$BASE_NAME" = "admin_1s" ] ; then
                BASE_DIR=x
                CLUSTER_IP=x
                SERVICE_NAME="$BASE_NAME"
                instance_class=system
            fi

            if  [ "$NAME" = "$BASE_NAME" ] || \
                [ "$NAME" = "empty_name" ] || \
                [ "$NAME" = "$instance_class" ]
            then
                BASE_NAME="$BASE_NAME" BASE_DIR="$BASE_DIR" HASP_SERVER="$HASP_SERVER" CLUSTER_IP="$CLUSTER_IP" \
                    docker compose -p "$BASE_NAME" -f compose-templates.yml up -d "$SERVICE_NAME" || true
            fi
            ;;

        stop)
            BASE_DIR=x
            HASP_SERVER=x
            CLUSTER_IP=x
            instance_class=workers

            if \
                [ "$BASE_NAME" = "gate_1s" ] || \
                [ "$BASE_NAME" = "redis_1s" ] || \
                [ "$BASE_NAME" = "samba_1s" ] || \
                [ "$BASE_NAME" = "backup_1s" ] || \
                [ "$BASE_NAME" = "admin_1s" ]
            then
                SERVICE_NAME="$BASE_NAME"
                instance_class=system
            fi

            if  [ "$NAME" = "$BASE_NAME" ] || \
                [ "$NAME" = "empty_name" ] || \
                [ "$NAME" = "$instance_class" ]
            then
                BASE_NAME="$BASE_NAME" BASE_DIR="$BASE_DIR" HASP_SERVER="$HASP_SERVER" CLUSTER_IP="$CLUSTER_IP" \
                    docker compose -p "$BASE_NAME" -f compose-templates.yml down "$SERVICE_NAME" || true
            fi
            ;;

        logs)
            BASE_DIR=x
            HASP_SERVER=x
            CLUSTER_IP=x

            if [ "$NAME" = "empty_name" ] ; then
                echo "ERROR. The name must be specified for logs"
                exit 1
            fi

            if \
                [ "$BASE_NAME" = "gate_1s" ] || \
                [ "$BASE_NAME" = "redis_1s" ] || \
                [ "$BASE_NAME" = "samba_1s" ] || \
                [ "$BASE_NAME" = "backup_1s" ] || \
                [ "$BASE_NAME" = "admin_1s" ]
            then
                SERVICE_NAME="$BASE_NAME"
            fi

            if  [ "$NAME" = "$BASE_NAME" ] ; then
                BASE_NAME="$BASE_NAME" BASE_DIR="$BASE_DIR" HASP_SERVER="$HASP_SERVER" CLUSTER_IP="$CLUSTER_IP" \
                    docker compose -p "$BASE_NAME" -f compose-templates.yml logs "$SERVICE_NAME"
            fi
            ;;

        exec)
            BASE_DIR=x
            HASP_SERVER=x
            CLUSTER_IP=x

            if [ "$NAME" = "empty_name" ] ; then
                echo "ERROR. The name must be specified for exec"
                exit 1
            fi

            if \
                [ "$BASE_NAME" = "gate_1s" ] || \
                [ "$BASE_NAME" = "redis_1s" ] || \
                [ "$BASE_NAME" = "samba_1s" ] || \
                [ "$BASE_NAME" = "backup_1s" ] || \
                [ "$BASE_NAME" = "admin_1s" ]
            then
                SERVICE_NAME="$BASE_NAME"
            fi

            if  [ "$NAME" = "$BASE_NAME" ] ; then

                [ "$#" -lt 2 ] || shift 2
                BASE_NAME="$BASE_NAME" BASE_DIR="$BASE_DIR" HASP_SERVER="$HASP_SERVER" CLUSTER_IP="$CLUSTER_IP" \
                    docker compose -p "$BASE_NAME" -f compose-templates.yml exec "$SERVICE_NAME" "$@"
            fi
            ;;

        status)
            echo "status"
            ;;

    esac

done

exec 3<&-
rm -f "$tmpfile"
