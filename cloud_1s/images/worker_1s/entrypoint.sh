#!/bin/sh -e

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

echo "Font cache for apache user"
export XDG_CACHE_HOME=/home/user1s/.cache/
mkdir -p "$XDG_CACHE_HOME/fontconfig"
chown -R "$DIR_USER:$DIR_GROUP" "$XDG_CACHE_HOME"

echo "Set log directory"
chown -R "$DIR_USER:$DIR_GROUP" /var/log/1s

echo "Processing HASP config"
jinjanate /wconf/nethasp.ini.j2 -o /opt/1cv8/conf/nethasp.ini --undefined
chmod 644 /opt/1cv8/conf/nethasp.ini

echo "Processing app config"
jinjanate /wconf/default.vrd.j2 -o /var/1spub/db/default.vrd --undefined
chmod 644 /var/1spub/db/default.vrd

echo "Processing wsap24 loader config"
jinjanate /wconf/wsap24.load.j2 -o /etc/apache2/mods-available/wsap24.load --undefined
chmod 644 /etc/apache2/mods-available/wsap24.load
ln -snf ../mods-available/wsap24.load /etc/apache2/mods-enabled/wsap24.load

echo "Processing wsap24 module config"
jinjanate /wconf/wsap24.conf.j2 -o /etc/apache2/mods-available/wsap24.conf --undefined
chmod 644 /etc/apache2/mods-available/wsap24.conf
ln -snf ../mods-available/wsap24.conf /etc/apache2/mods-enabled/wsap24.conf

echo "Processing apache envvars"
jinjanate /wconf/envvars.j2 -o /etc/apache2/envvars --undefined
chmod 644 /etc/apache2/envvars

echo "Starting supervisor"
exec /usr/bin/supervisord -c /supervisord.conf

echo "==========Container shutdown==============="
exit

# sleep inf
