#!/bin/sh -e

# export TZ="Europe/Moscow"
# export LANG="ru_RU.UTF-8"

if [ -n "$TZ" ]; then
  echo "Trying to set TZ = $TZ"
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
  echo "TZ has been set"
fi

echo "Add user and group"
getent group user1s || groupadd -g "$DIR_GROUP" -o user1s
getent passwd user1s || useradd -u "$DIR_USER" -g "$DIR_USER" -o -m user1s
#echo "user1s ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/user1s

echo "Samba password"
getent group smbauths || groupadd -g 1500 smbauths
getent passwd samba_admin || useradd -K UID_MIN=1500 -g smbauths -d /dev/null -M -N -s /sbin/nologin samba_admin
printf "%s\n%s\n" "$(cat /run/secrets/admin_password)" "$(cat /run/secrets/admin_password)" | pdbedit -a -t -u samba_admin
getent passwd samba_user || useradd -K UID_MIN=1500 -g smbauths -d /dev/null -M -N -s /sbin/nologin samba_user
printf "%s\n%s\n" "$(cat /run/secrets/samba_password)" "$(cat /run/secrets/samba_password)" | pdbedit -a -t -u samba_user

echo "Starting supervisor"
exec /usr/bin/supervisord -c /supervisord.conf


echo "==========Container shutdown==============="
exit

# sleep inf
