#!/bin/bash
set -e -u -o pipefail

shared_dependencies() {
  local EXECUTABLE=$1
  for PACKAGE in $(ldd "$EXECUTABLE" | grep "=> /" | awk '{print $3}'); do 
    LC_ALL=c pacman -Qo $PACKAGE
  done | awk '{print $5}'
}

pkgbuild_prvided() {
  local PKGBUILD=$1
  provides=
  source "$PKGBUILD"
  [[ -z "$provides" ]] && return
  dep_list=
  echo "${provides[@]}"
}

pkgbuild_dependencies() {
  local PKGBUILD=$1
  local EXCLUDE="$2"
  depends=
  source "$PKGBUILD"
  [[ -z "$depends" ]] && return
  dep_list=
  for DEPEND in ${depends[@]}; do
	[[ -n "$DEPEND" ]] || continue
    dep=`echo "$DEPEND" | sed "s/[>=<].*$//"`
	[[ -n "$dep" ]] || continue 
	echo "$EXCLUDE" | grep -wq "$dep" && continue
	dep_list="$dep_list $dep"
  done

  echo "$dep_list"
}

download_pkgbuild() {
	local PACKAGE=$1
	local PKGBUILD_TARGET=$2

	rsync rsync://rsync.archlinux.org/abs/i686/core/$PACKAGE/PKGBUILD $PKGBUILD_TARGET ||\
		rsync rsync://rsync.archlinux.org/abs/any/core/$PACKAGE/PKGBUILD $PKGBUILD_TARGET
}

# Main
{
  
#  shared_dependencies "/usr/bin/pacman"
  pkg_list=
  pkg_provided_list=
  added_list=pacman
#  pkgbuild_dir=`mktemp -d`
  pkgbuild_dir=/tmp/pkgbuild
  mkdir -p  "$pkgbuild_dir"
  echo "pkgbuild_dir=$pkgbuild_dir"
  while [[ -n "$added_list" ]]; do
	pkg_list="$pkg_list $added_list"
	echo "current pkglist is $pkg_list"
	newly_added_list="$added_list"
	echo "newly_added_list is $newly_added_list"
	added_list=

	for pkg in $newly_added_list; do
	  echo "checking pkg $pkg"
	  download_pkgbuild "$pkg" "$pkgbuild_dir/$pkg"
      pkg_provided_list="$pkg_provided_list `pkgbuild_prvided "$pkgbuild_dir/$pkg"`"
      added_list="$added_list `pkgbuild_dependencies "$pkgbuild_dir/$pkg" " $pkg_list $added_list $pkg_provided_list"` "
	done

  	added_list=`echo -n $added_list | sed '/^$/d' | sort | uniq`
  done

  echo "$pkg_list"
}
