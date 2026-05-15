#!/bin/sh -e

# export TZ="Europe/Moscow"
# export LANG="ru_RU.UTF-8"

if [ -n "$TZ" ]; then
  echo "Trying to set TZ = $TZ"
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
  echo "TZ has been set"
fi


echo "Add default route"
ip route add default via "$CLUSTER_GW"

echo "Add user and group"
getent group user1s || groupadd -g "$DIR_GROUP" -o user1s
getent passwd user1s || useradd -u "$DIR_USER" -g "$DIR_USER" -o -m user1s
#echo "user1s ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/user1s


echo "Starting supervisor"
exec /usr/bin/supervisord -c /supervisord.conf


echo "==========Container shutdown==============="
exit

# sleep inf
