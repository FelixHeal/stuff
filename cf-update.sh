#!/bin/bash

echo `date --rfc-3339=ns`": Checking for new version"
FORCE_INSTALL=false
INSTALLED_VERSION=`cloudflared -v | cut -d ' ' --fields=3`
NEW_VERSION=$(curl --silent https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
re_semver='^[0-9]{0,255}.[0-9]{0,255}.[0-9]{0,255}$'
if ! [[ $INSTALLED_VERSION =~ $re_semver ]]; then
    echo "Error: REGEX failed to validate installed version of cloudflared" >&2; exit 1
fi
if ! [[ $NEW_VERSION =~ $re_semver ]]; then
    echo "Error: REGEX failed to validate new version of cloudflared" >&2; exit 1
fi

semver_split_installed=( ${INSTALLED_VERSION//./ } )
major_installed="${semver_split_installed[0]}"
minor_installed="${semver_split_installed[1]}"
patch_installed="${semver_split_installed[2]}"

semver_split_new=( ${NEW_VERSION//./ } )
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
    read -r -p "`date --rfc-3339=ns`: Do you want to upgrade to version: $NEW_VERSION from existing version: $INSTALLED_VERSION? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
      #echo "running prompted upgrade"
      runupgrade
    else
      echo `date --rfc-3339=ns`": Not upgrading. Exiting..."
    fi
  fi
}


runupgrade () {
  echo `date --rfc-3339=ns`": Starting upgrade from $INSTALLED_VERSION to $NEW_VERSION now..."

  cd /home/pi/cloudflared
  echo `date --rfc-3339=ns`": Downloading new version"
  wget https://github.com/cloudflare/cloudflared/releases/download/$NEW_VERSION/cloudflared-linux-arm -O $NEW_VERSION-cloudflared-linux-arm
  #wget https://bin.equinox.io/c/VdrWdbjqyF/cloudflared-stable-linux-arm.tgz -O $NEW_VERSION-cloudflared-stable-linux-arm.tgz
  #echo `date --rfc-3339=ns`": Extracting new version"
  #tar -xzf $NEW_VERSION-cloudflared-stable-linux-arm.tgz
  echo `date --rfc-3339=ns`": Stopping cloudflared service and patching"
  sudo systemctl stop cloudflared
  #sudo cp ./cloudflared /usr/local/bin
  sudo cp ./$NEW_VERSION-cloudflared-linux-arm /usr/local/bin/cloudflared
  sudo chmod +x /usr/local/bin/cloudflared
  sudo systemctl start cloudflared
  echo `date --rfc-3339=ns`": Done patching. Recyling service."
  cloudflared -v
  sudo systemctl status cloudflared
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
