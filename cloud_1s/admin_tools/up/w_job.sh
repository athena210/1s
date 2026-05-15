#!/bin/sh -e

SECRETS="./secret.1s_password"

# "BATCH_1S_PROCESSING":  1
# "BATCH_1S_COMMAND":     job.command,
# "BATCH_1S_DB_TYPE":     job.db_type,
# "BATCH_1S_DB_DIR":      job.db_dir,
# "BATCH_1S_UPDATE_DIR":  job.update_dir or ''
#
### Run
# "/opt/1cv8/x86_64/${VERSION_1S}/1cv8" ENTERPRISE /N "$SECRET_1S_USER" /P "$SECRET_1S_PASSWORD" /F "$BATCH_1S_DB_DIR"
### Config
# "/opt/1cv8/x86_64/${VERSION_1S}/1cv8" DESIGNER   /N "$SECRET_1S_USER" /P "$SECRET_1S_PASSWORD" /F "$BATCH_1S_DB_DIR"
### Update
# "/opt/1cv8/x86_64/${VERSION_1S}/1cv8" DESIGNER   /N "$SECRET_1S_USER" /P "$SECRET_1S_PASSWORD" /F "$BATCH_1S_DB_DIR" /UpdateCfg "$BATCH_1S_UPDATE_DIR/1cv8.cfu" /UpdateDBCfg /Out ./logs/f
### Repair
# "/opt/1cv8/x86_64/${VERSION_1S}/1cv8" DESIGNER   /N "$SECRET_1S_USER" /P "$SECRET_1S_PASSWORD" /F "$BATCH_1S_DB_DIR" /IBCheckAndRepair -ReIndex -LogAndRefsIntegrity -RecalcTotals -IBCompression -Rebuild -BadRefCreate -BadDataCreate -RefreshTableLocation -BinaryDataStorageIntegrity -JobsCount 1 /Out ./logs/f

[ -n "$BATCH_1S_PROCESSING" ]   || exit 1
[ -n "$BATCH_1S_DB_DIR" ]       || exit 1
[ -d "$BATCH_1S_DB_DIR" ]       || exit 1
[ -r "$SECRETS" ]               || exit 1

. "$SECRETS"                    || exit 1
[ -n "$SECRET_1S_USER" ]        || exit 1
[ -n "$SECRET_1S_PASSWORD" ]    || exit 1

mkdir -p "./logs"
BIN_1S="/opt/1cv8/x86_64/${VERSION_1S}/1cv8"

BATCH_1S_DB_NAME="$(basename "$BATCH_1S_DB_DIR" )"

case "$BATCH_1S_COMMAND" in
    run)
        "$BIN_1S" ENTERPRISE /N "$SECRET_1S_USER" /P "$SECRET_1S_PASSWORD" /F "$BATCH_1S_DB_DIR"
    ;;
    repair)
        redis-cli -h "$REDIS_IP" PUBLISH "event:command" "$BATCH_1S_DB_NAME reset"
        sleep 3
        "$BIN_1S" DESIGNER /N "$SECRET_1S_USER" /P "$SECRET_1S_PASSWORD" /F "$BATCH_1S_DB_DIR" /DisableStartupDialogs /IBCheckAndRepair -ReIndex -LogAndRefsIntegrity -RecalcTotals -IBCompression -Rebuild -BadRefCreate -BadDataCreate -RefreshTableLocation -BinaryDataStorageIntegrity -JobsCount 1 /Out "./logs/r:${BATCH_1S_DB_NAME}.log"
    ;;
    update)
        redis-cli -h "$REDIS_IP" PUBLISH "event:command" "$BATCH_1S_DB_NAME reset"
        sleep 3
        [ -n "$BATCH_1S_UPDATE_DIR" ] || exit 1
        BATCH_1S_UPDATE_NAME="$(basename "$BATCH_1S_UPDATE_DIR")"
        BATCH_1S_UPDATE_CFU="$BATCH_1S_UPDATE_DIR/1cv8.cfu"
        [ -f "$BATCH_1S_UPDATE_CFU" ] || exit 1

        "$BIN_1S" DESIGNER /N "$SECRET_1S_USER" /P "$SECRET_1S_PASSWORD" /F "$BATCH_1S_DB_DIR" /DisableStartupDialogs /UpdateCfg "$BATCH_1S_UPDATE_CFU" /UpdateDBCfg /Out "./logs/u:${BATCH_1S_DB_NAME}:${BATCH_1S_UPDATE_NAME}.log"
    ;;
    *)
        exit 1
    ;;
esac
