while true; do
 
rsync -WSat --remove-source-files --include='*.pcap' root@engine:/pcaps/data/ /pcaps/;

sleep 15;
 
done