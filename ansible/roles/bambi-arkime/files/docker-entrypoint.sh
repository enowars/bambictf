#!/bin/sh
set -e

sh ./arkime-capture.sh bambiarkime1 &
sh ./arkime-viewer.sh bambiarkime1 &
wait
