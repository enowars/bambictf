#!/bin/sh
set -e

sh ./arkime-capture.sh [[ARKIME]] &
sh ./arkime-viewer.sh [[ARKIME]] &
wait
