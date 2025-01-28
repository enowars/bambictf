cd /opt/arkime/viewer
while :
do
  echo "Starting Arkime viewer"
  /opt/arkime/bin/node viewer.js -c /opt/arkime/etc/config.ini --host $1 -n $1
  sleep 5
done
