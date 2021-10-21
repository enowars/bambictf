for i in $(seq 1 $1); do openssl rand -hex 12 > ./team$i.txt; done
