#!/bin/bash

usage="Usage: ${0##*/} [options] progs"
prefix="$HOME/csg"
#mind the spaces
all=" tools csg moo kmc tof "

do_prefix_clean="no"
do_configure="yes"
do_clean="yes"
do_build="yes"
do_install="yes"
do_update="no"

svn_co="svn co http://csgth.mpip-mainz.mpg.de/svn/PROG/trunk PROG"

have_hg=" tools csg "
hg_co="hg clone http://dev.votca.org/votca/PROG PROG"

extra_conf=""

gromacs="no"

die () {
  echo -e "$*" >&2
  exit 1
}

prefix_clean() {
  cd $prefix || die "Dir: '$prefix not found'"
  files="$(ls -d bin include lib share 2>/dev/null)"
  if [ -z "$files" ]; then 
    echo "Found nothing to clean"
    cd -
    return
  fi
  echo "I will remove:"
  echo $files
  echo -e "CTRL-C to stop it"
  countdown 10
  rm -rf $files
  echo -e "\nDone, hope you are happy now"
  cd -
}

countdown() {
  [ -z "$1" ] && "countdown: Missing argument"
  [ -n "${1//[0-9]}" ] && "countdown: argument should be a number"
  for ((i=$1;i>0;i--)); do
    echo -n "$i "
    sleep 1
  done
  echo
}

show_help () {
  cat << eof
This is a helper script to build votca + rest
Give progs to compile or nothing meaning "$all"

$usage
OPTIONS:
-h, --help              Show this help
-u, --do-update         Do a update from svn/hg
-c, --clean-out         Clean out the prefix
    --no-configure      Don't run ./configure
    --conf-opts TEXT    Extra configure options
    --no-clean          Don't run make clean
    --no-build          Don't run make
    --no-install        Don't run make install
    --prefix <prefix>   use prefix
                        Default: $prefix
-g, --gromacs           Set gromacs stuff base up your \$GMXLDLIB

Examples:  ${0##*/} tools csg
           ${0##*/} --do-checkout --prefix ~/tof 
           ${0##*/} -cug tools csg

eof
}

# parse arguments

while [ "${1#-}" != "$1" ]; do
 if [ "${1#--}" = "$1" ] && [ -n "${1:2}" ]; then
    #short opt with arguments here: f
    if [ "${1#-[f]}" != "${1}" ]; then
       set -- "${1:0:2}" "${1:2}" "${@:2}"
    else
       set -- "${1:0:2}" "-${1:2}" "${@:2}"
    fi
 fi
 case $1 in
   -h | --help)
    show_help
    exit 0;;
   -c | --clean-out)
    prefix_clean="yes"
    shift 1;;
   -g | --gromacs)
    gromacs="yes"
    shift 1;;
   -u | --do-update)
    do_update="yes"
    shift 1;;
   --no-configure)
   do_configure="no"
    shift 1;;
   --no-clean)
   do_clean="no"
    shift 1;;
   --no-instal)
    do_install="no"
    shift 1;;
   --no-build)
    do_build="no"
    shift 1;;
   --prefix)
    prefix="$2"
    shift 2;;
  *)
   die "Unknown option '$1'"
   exit 1;;
 esac
done

[ -z "$1" ] && set -- $all
[ -z "$prefix" ] && die "Error: prefix is empty"


CPPFLAGS="-I$prefix/include $CPPFLAGS"
LDFLAGS="-L$prefix/lib $LDFLAGS"

if [ "$gromacs" = "yes" ]; then
  LDFLAGS="-L$GMXLDLIB $LDFLAGS"
  CPPFLAGS="-I$GMXLDLIB/../include/gromacs $CPPFLAGS"
fi
export CPPFLAGS LDFLAGS

echo "prefix = $prefix"
echo "CPPFLAGS = $CPPFLAGS"
echo "LDFLAGS = $LDFLAGS"
[ "$prefix_clean" = "yes" ] && prefix_clean

set -e
for prog in "$@"; do
  [ -n "${all//* $prog *}" ] && die "Unknown progamm '$prog', I know$all"

  if [ ! -d "$prog" ]; then
    echo "Doing checkout for $prog (CTRL-C to stop)"
    countdown 5
    if [ -z "${have_hg/* $prog *}" ]; then
      ${hg_co//PROG/$prog}
    else
      ${svn_co//PROG/$prog}
    fi
  fi

  cd $prog
  if [ "$do_update" == "yes" ]; then
    if [ -z "${have_hg/* $prog *}" ]; then
      echo "updating from hg repo"
      hg --config extensions.hgext.fetch fetch
    else
      echo "updating from svn repo"
      svn update
    fi
  fi
  echo "compiling $prog"
  if [ "$do_configure" == "yes" ]; then
    ./bootstrap.sh 
    ./configure --prefix "$prefix" $extra_conf 
  fi
  if [ "$do_clean" == "yes" ]; then
    echo cleaning $prog
    make clean
  fi
  if [ "$do_build" == "no" ]; then 
    cd .. 
    continue
  fi
  make
  [ "$do_install" == "yes" ] && make install
  cd ..
done
set +e
