#!/bin/sh
set -e

sh ./arkime-capture.sh [[ROUTER]] &
sh ./arkime-viewer.sh [[ROUTER]] &
wait
