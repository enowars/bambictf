#!/bin/bash

scp -i ~/.ssh/priv_key_for_moloch $1 root@192.168.0.3:/pcaps

rm $1

echo done $(date) -- $1

