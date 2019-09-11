#!/bin/bash
# set -x

DATE=$(date +%s)
PW="peZi6KIxvNZH7S6IbnbdUR1gJN"
REPOPATH="/packages/"
REPONAME="enowars"
CONTAINERNAME="aptly_aptly_1"

docker exec -i "$CONTAINERNAME" rm -rf "$REPOPATH"
docker exec -i "$CONTAINERNAME" mkdir -p "$REPOPATH"

cd "$REPOPATH"
find . -type f -name '*.deb' -exec docker cp {} "$CONTAINERNAME":"$REPOPATH" \;
cd - >/dev/null 2>&1

if [[ $(docker exec -i "$CONTAINERNAME" aptly repo list -raw) ]]; then
    echo "Repo already exists"
else
    docker exec -i "$CONTAINERNAME" aptly repo create "$REPONAME"
fi

docker exec -i "$CONTAINERNAME" aptly repo add -force-replace=true -remove-files=true "$REPONAME" "$REPOPATH"

docker exec -i "$CONTAINERNAME" aptly snapshot create "$REPONAME"-$DATE from repo "$REPONAME"


if [[ $(docker exec -i "$CONTAINERNAME" aptly publish list -raw) ]]; then
    docker exec -i "$CONTAINERNAME" aptly publish switch -force-overwrite=true -passphrase="$PW" -architectures=all "stretch" "$REPONAME"-$DATE
else
    docker exec -i "$CONTAINERNAME" aptly publish snapshot -force-overwrite=true -distribution="stretch" -passphrase="$PW" -architectures=all "$REPONAME"-$DATE
fi
