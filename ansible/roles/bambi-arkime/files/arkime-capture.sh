cd /opt/arkime
while :
do
  echo "Starting Arkime capture"
  /opt/arkime/bin/capture -c /opt/arkime/etc/config.ini -R /pcaps -m --host $1 -n $1
  sleep 5
done