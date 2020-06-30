for i in $(seq 1 20); do openssl rand -base64 16 > ./team$i.txt; done
