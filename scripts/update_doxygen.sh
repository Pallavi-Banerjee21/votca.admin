#! /bin/bash -e

# Make a crontab like this
#
# SHELL=/bin/bash
# PATH=/people/thnfs/homes/junghans/bin:/usr/bin:/usr/sbin:/sbin:/bin
# #min  hour  day  month  dow  user  command
# */30  *     *    *      *    . $HOME/.bashrc; $HOME/votca/src/admin/scripts/update_doxygen.sh $HOME/votca/src/doxygen >~/.votca_devdoc 2>&1

url="https://code.google.com/p/votca.doxygen/"
burl="https://code.google.com/p/votca/"
sim=75
author="Doxygen builder <devs@votca.org>"
msg="Documentation update"

[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || true

die () {
  echo -e "$*"
  exit 1
}

[ -z "$1" ] && die "${0##*/}: missing argument add the path where to build the docu"

[ -d "$1" ] || die "Argument is not a dir"
cd "$1"

if [ -d buildutil ]; then
  cd buildutil
  hg pull $burl
  hg update
  cd ..
else
  hg clone $burl buildutil 
fi

[ -d devdoc ] || hg clone $url devdoc

cd devdoc
hg pull || die "hg pull failed"
hg update || die "hg up failed"
rm -f *
cd ..

./buildutil/build.sh --no-wait --dev --just-update --devdoc tools csg ctp moo kmc || die "build of docu failed"

cd devdoc
hg addremove -s $sim
hg commit -u "$author" -m "$msg" && hg push $url

