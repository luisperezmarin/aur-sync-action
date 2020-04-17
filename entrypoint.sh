#!/bin/bash

set -o errexit -o pipefail -o nounset

PACKAGE_NAME=$INPUT_PACKAGE_NAME
COMMIT_USERNAME=$INPUT_COMMIT_USERNAME
COMMIT_EMAIL=$INPUT_COMMIT_EMAIL
SSH_PRIVATE_KEY=$INPUT_SSH_PRIVATE_KEY
GITHUB_REPO=$INPUT_GITHUB_REPO

export HOME=/home/builder

ssh-keyscan -t ed25519 aur.archlinux.org >> $HOME/.ssh/known_hosts

echo -e "${SSH_PRIVATE_KEY//_/\\n}" > $HOME/.ssh/aur

chmod 600 $HOME/.ssh/aur*

git config --global user.name "$COMMIT_USERNAME"
git config --global user.email "$COMMIT_EMAIL"

AUR_REPO_URL="ssh://aur@aur.archlinux.org/${PACKAGE_NAME}.git"

echo "---------------- $AUR_REPO_URL ----------------"

cd /tmp
git clone "$AUR_REPO_URL"
cd "$PACKAGE_NAME"

echo "------------- DIFF VERSION ----------------"

RELEASE_VER=`curl -s https://api.github.com/repos/${GITHUB_REPO}/releases | jq -r .[0].tag_name`
NEW_PKGVER="${RELEASE_VER:1}" # remove character 'v'
CURRENT_VER=`grep pkgver .SRCINFO | awk -F '=' '{print $2}' | tr -d "[:space:]"`

# diff version
echo "release version is "$NEW_PKGVER
echo "current version is "$CURRENT_VER
if [[ $NEW_PKGVER = $CURRENT_VER ]]; then
  echo "already up-to-date!";
  echo "------------- SYNC DONE ----------------"
  exit 0
fi


echo "------------- BUILDING PKG $PACKAGE_NAME ----------------"

sed -i "s/pkgver=.*$/pkgver=${NEW_PKGVER}/" PKGBUILD
sed -i "s/pkgrel=.*$/pkgrel=1/" PKGBUILD
perl -i -0pe "s/sha256sums=[\s\S][^\)]*\)/$(makepkg -g 2>/dev/null)/" PKGBUILD

# Test build
makepkg -c

# Update srcinfo
makepkg --printsrcinfo > .SRCINFO


echo "------------- BUILD DONE ----------------"

# Update aur
git add PKGBUILD .SRCINFO
git commit --allow-empty  -m "Update to $NEW_RELEASE"
git push

echo "------------- SYNC DONE ----------------"
