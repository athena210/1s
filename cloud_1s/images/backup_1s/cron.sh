#!/bin/sh -e

backup_daily_dir="${STORAGE_DAILY:-/srv/1sdaily}"
backup_daily_num="${STORAGE_DAILY_NUM:-3}"
backup_monthly_dir="${STORAGE_MONTHLY:-/srv/1smonthly}"
LIST_SRC_FILE="${LIST_SRC_FILE:-/bak.list}"

# time format: 'day@hour:minute'
# every number is zero leading if short
# most specific or monthly match have priority over less specific or daily
time_daily="${CRON_TIME_DAILY:-"*@05:00"}"
time_monthly="${CRON_TIME_MONTHLY:-"01@05:00"}"


### start_backup:
#
#
# start_backup daily [basename]
#    Архивирует и забирает из буфера рабочие базы (w) - все или только заданную.
#    Результат кладет в daily хранилище, затем убирает в нем лишние архивы.
# start_backup monthly [basename]
#    Архивирует и забирает из буфера рабочие базы (w) - все или только заданную.
#    Результат кладет в monthly хранилище.
# start_backup once [basename]
#    Архивирует и забирает из буфера архивные базы (a) - все или только заданную.
#    Результат кладет в monthly хранилище.
#
# Когда архивы скопированы из буфера, каталог базы в буфере удаляется.
#
# Буфер наполняется агентом. Агент не разбирает буфер.
#
### LIST_SRC format:
# 1) buf - архивы, сделанные в др месте.
#    src - локальные базы. архивировать.
#
# 2) a - архивные базы. обрабатывать только по команде
#    w - рабочие базы. Обрабатывать ежедневно и ежемесячно
#
# 3) по этому пути лежат каталоги с базами
#
# Пример:
#buf w /dir1
#src a /dir2
#src w /dir3
#
###


archive_the_base() {
    BASE_DIR="$1"
    DST_DIR="$2"
    [ -d "$BASE_DIR" ] || return 1
    [ -d "$DST_DIR" ] || return 1
    ar_name="$(date '+%Y-%m-%d_%H-%M-%S').7z"
    if ! 7za a -mx=1 -bd "$DST_DIR/$ar_name" "$BASE_DIR"
    then
        rm -f "$DST_DIR/$ar_name" || true
        return 1
    fi
    return 0
}


remove_olds() {
    SAVE_LAST="$1"
    DIR="$2"
    if ! ([ "$SAVE_LAST" -eq "$SAVE_LAST" ] 2>/dev/null && [ "$SAVE_LAST" -gt 0 ]) ; then
        echo "ERROR: SAVE_LAST must be positive integer ($SAVE_LAST)"
        return 1
    fi
    [ -d "$DIR" ] || return 0
    res=0
    ls -1v "$DIR/"*.7z 2> /dev/null | head -n "-${SAVE_LAST}" | \
        while read -r FILE ; do
            rm -f "$FILE" || res=1
        done
    return "$res"
}


get_free_space_gb() {
    DIR="$1"
    [ -d "$DIR" ] || return 1

    stats="$(df -B1G "$DIR" | tail -1)"
    free="$(echo "$stats" | awk '{print $4}')"

    [ -n "$free" ] || return 1
    echo "$free"
    return 0
}


start_backup() {

    COMMAND="${1:-empty_command}"
    BASE_NAME="${2:-empty_name}"
    DST_PATH=""

    case "$COMMAND" in
        daily)
            DST_PATH="$backup_daily_dir"
            ;;
        monthly|once)
            DST_PATH="$backup_monthly_dir"
            ;;
        *)
            echo "Error: command is (${1:-EMPTY}). Must be daily, monthly or once"
            echo "Usage:"
            echo "  help"
            return
            ;;
    esac

    ( \
        [ -n "$DST_PATH" ] && \
        [ -d "$DST_PATH" ] && \
        [ -n "$LIST_SRC_FILE" ] && \
        [ -f "$LIST_SRC_FILE" ] \
    ) || return

    redis-cli -h "$REDIS_IP" PUBLISH "event:command" "all reset"
    sleep 3

    cat "$LIST_SRC_FILE" | \
    sed 's/^[[:space:]]*//' | \
    sed '/^$/d' | \
    sed '/^#/d' | \
    while read -r TYPE STATUS SRC_PATH JUNK ; do

        ( \
            [ -n "$SRC_PATH" ] && \
            [ -d "$SRC_PATH" ] && \
            [ -n "$TYPE" ] && \
            [ -n "$STATUS" ] \
        ) || continue

        stor_name="$(basename "$SRC_PATH")"

        ls -1 "$SRC_PATH" | \
            while read -r DIR ; do

                ([ "$BASE_NAME" = "empty_name" ] || [ "$DIR" = "$BASE_NAME" ]) || continue

                case "$TYPE" in
                    src)
                        if (([ "$COMMAND" = "daily" ]   && [ "$STATUS" = "w" ]) || \
                            ([ "$COMMAND" = "monthly" ] && [ "$STATUS" = "w" ]) || \
                            ([ "$COMMAND" = "once" ]    && [ "$STATUS" = "a" ]))
                        then
                            mkdir -p "$DST_PATH/$stor_name/$DIR"
                            archive_the_base "$SRC_PATH/$DIR" "$DST_PATH/$stor_name/$DIR" || echo "ERROR: archive failed $DST_PATH/$stor_name/$DIR"
                            [ "$COMMAND" != "daily" ] || remove_olds "$backup_daily_num" "$DST_PATH/$stor_name/$DIR"
                        fi
                        ;;
                    buf)
                        if (([ "$COMMAND" = "daily" ]   && [ "$STATUS" = "w" ]) || \
                            [ "$COMMAND" = "monthly" ] || \
                            [ "$COMMAND" = "once" ])
                        then
                            mkdir -p "$DST_PATH/$stor_name/$DIR"
                            (cp -f "$SRC_PATH/$DIR"/*.7z "$DST_PATH/$stor_name/$DIR" && rm -rf "$SRC_PATH/$DIR") || echo "ERROR: cant deal with buf $DST_PATH/$stor_name/$DIR"
                            [ "$COMMAND" != "daily" ] || remove_olds "$backup_daily_num" "$DST_PATH/$stor_name/$DIR"
                        fi
                        ;;
                esac
            done
    done

    gbleft="$(get_free_space_gb "$DST_PATH")" || true
    echo "$gbleft GB left"
}


#####################


#start_backup daily
#exit 0


if \
    [ -z "$DIR_USER" ] || \
    [ -z "$DIR_GROUP" ] || \
    [ "$DIR_USER" != "$(id -u)" ] || \
    [ "$DIR_GROUP" != "$(id -g)" ]
then
    echo "Must be started from container."
    exit 1
fi


while true ; do

    time_now="$(date '+%d@%H:%M')"
    case "$time_now" in
        $time_monthly)
            start_backup monthly
        ;;
        $time_daily)
            start_backup daily
        ;;
    esac

    sleep 20

done
