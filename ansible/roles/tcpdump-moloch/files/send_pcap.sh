#!/bin/bash

scp -i ~/.ssh/moloch_key $1 root@192.168.0.3:/pcaps

rm $1

echo done $(date) -- $1

