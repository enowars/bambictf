#!/bin/sh
set -e
elasticsearch="192.168.2.1"

while ! curl -sq http://$elasticsearch:9200; do
    echo "Waiting for elasticsearch to start...";
    sleep 3;
done

echo "Initializing Arkime Elasticsearch"
/opt/arkime/db/db.pl http://$elasticsearch:9200 init
/opt/arkime/bin/arkime_add_user.sh admin "Admin User" admin --admin

sh ./arkime-capture.sh bambiarkime1 &
sh ./arkime-viewer.sh bambiarkime1 &
wait
