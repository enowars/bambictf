all: vulnbox
ENCRYPTPW="M4k3.L0v3.N0T.W4R<3"
TEAMREGSITE=root@192.168.234.37
STATICFILESPATH=/root/enoteams/static/files/
clean:
	rm -rf output/ || true

baseimage:
	test -f output/baseimage/baseimage.ova || packer build -force baseimage.json

vulnbox: baseimage
	packer build -force vulnbox.json

encryptedvulnbox:
	test -f output/vulnbox/vulnbox.ova || (echo "NO VULNBOX TO ENCRYPT" && exit 1) 
	echo ${ENCRYPTPW} | gpg --batch --yes --passphrase-fd 0 --symmetric --output output/vulnbox/vulnbox.ova.gpg -c output/vulnbox/vulnbox.ova

upload: uploadvulnbox

uploadvulnbox:
	test -f output/vulnbox/vulnbox.ova.gpg || (echo "NO VULNBOX TO UPLOAD" && exit 1) 
	sha256sum output/vulnbox/vulnbox.ova.gpg > output/vulnbox/vulnbox.ova.gpg.sha256
	rsync -avP output/vulnbox/vulnbox.ova.gpg* ${TEAMREGSITE}:${STATICFILESPATH}