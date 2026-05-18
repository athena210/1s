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
echo "user1s ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/user1s

echo "VNC password"
mkdir -p "/home/user1s/.vnc"
cat /run/secrets/admin_password | vncpasswd -f > "/home/user1s/.vnc/passwd"
chown -R "user1s:user1s" "/home/user1s"
chmod 600 "/home/user1s/.vnc/passwd"

echo "Processing HASP config"
jinjanate /wconf/nethasp.ini.j2 -o /opt/1cv8/conf/nethasp.ini --undefined
chmod 644 /opt/1cv8/conf/nethasp.ini

echo "RU keyboard"
mv -f /keyboard.desktop "/home/user1s/.config/autostart/" || true

echo "Starting supervisor"
exec /usr/bin/supervisord -c /supervisord.conf


echo "==========Container shutdown==============="
exit

# sleep inf
