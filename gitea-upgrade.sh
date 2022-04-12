#!/bin/bash

#export GITEAUPGRADETMP=$(mktemp -d)

#cd $GITEAUPGRADETMP

FORCE_INSTALL=false
export INSTALLEDVERSION=`/usr/local/bin/gitea --version | grep -E -o "(([0-9])+(\.){0,1})+" | head -1`
#/usr/local/bin/gitea doctor --config /etc/gitea/app.ini --work-path /var/lib/gitea --custom-path /var/lib/gitea/custom --all

#echo $INSTALLEDVERSION

NEWVERSION=$(curl --silent https://api.github.com/repos/go-gitea/gitea/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# remove first char, as gitea tag is not valid semver
export NEWVERSION="${NEWVERSION:1}"

#echo $NEWVERSION

re_semver='^[0-9]{0,255}.[0-9]{0,255}.[0-9]{0,255}$'


if ! [[ $INSTALLEDVERSION =~ $re_semver ]]; then
    echo "Error: REGEX failed to validate installed version of gitea" >&2; exit 1
fi
if ! [[ $NEWVERSION =~ $re_semver ]]; then
    echo "Error: REGEX failed to validate new version of gitea" >&2; exit 1
fi

semver_split_installed=( ${INSTALLEDVERSION//./ } )
major_installed="${semver_split_installed[0]}"
minor_installed="${semver_split_installed[1]}"
patch_installed="${semver_split_installed[2]}"

semver_split_new=( ${NEWVERSION//./ } )
major_new="${semver_split_new[0]}"
minor_new="${semver_split_new[1]}"
patch_new="${semver_split_new[2]}"

while getopts f option
do
case "${option}"
in
  f) FORCE_INSTALL=true;;
esac
done

midichlorians_test () {
  echo `date --rfc-3339=ns`": New $1 version detected!"
  if [ $FORCE_INSTALL = true ]; then
    #echo "running forced upgrade"
    runupgrade
  else
    read -r -p "`date --rfc-3339=ns`: Do you want to upgrade to version: $NEWVERSION from existing version: $INSTALLEDVERSION? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      #echo "running prompted upgrade"
      runupgrade
    else
      echo `date --rfc-3339=ns`": Not upgrading. Exiting..."
    fi
  fi
}


runupgrade () {
  echo `date --rfc-3339=ns`": Starting upgrade from $INSTALLEDVERSION to $NEWVERSION now..."

  export GITEAUPGRADETMP=$(mktemp -d)
  #cd $GITEAUPGRADETMP
#  cd /home/pi/cloudflared
  echo `date --rfc-3339=ns`": Downloading new version"
  wget -O $GITEAUPGRADETMP/gitea  https://dl.gitea.io/gitea/$NEWVERSION/gitea-$NEWVERSION-linux-amd64
  chmod +x $GITEAUPGRADETMP/gitea
  export DOWNLOADEDVERSION=`$GITEAUPGRADETMP/gitea --version | grep -E -o "(([0-9])+(\.){0,1})+" | head -1`
  if ! [[ $NEWVERSION != $GITEAUPGRADETMP ]]; then
    echo `date --rfc-3339=ns`": Exiting. Download error."
    exit 1
  fi
  echo `date --rfc-3339=ns`": Stopping gitea service and patching"
  sudo systemctl stop gitea.service
  cp $GITEAUPGRADETMP/gitea /usr/local/bin/gitea
  chmod +x /usr/local/bin/gitea
  chown git:git /usr/local/bin/gitea
  sudo systemctl start gitea.service
  echo `date --rfc-3339=ns`": Done patching. Recyling service."
  gitea --version
  systemctl status gitea.service gitea.main.socket
  echo `date --rfc-3339=ns`": Exiting updater."
}


if   [ $major_new -gt $major_installed ]; then
    midichlorians_test Major $1; exit 1
elif [ $minor_new -gt $minor_installed ]; then
#    midichlorians_test Minor;  exit 1
    midichlorians_test Minor $1; exit 1
elif [ $patch_new -gt $patch_installed ]; then
    midichlorians_test Patch $1; exit 1
fi

echo `date --rfc-3339=ns`": Nothing to upgrade"
