for i in $(seq 1 $1); do openssl rand -base64 16 > ./team$i.txt; done
