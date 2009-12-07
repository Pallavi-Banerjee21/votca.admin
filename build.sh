#!/bin/bash

usage="Usage: ${0##*/} [options] progs"
prefix="$HOME/votca"
#mind the spaces
all=" tools csg moo kmc tof "

do_prefix_clean="no"
do_configure="yes"
do_clean="yes"
do_build="yes"
do_install="yes"
do_update="no"

hg_co="hg clone http://dev.votca.org/votca/PROG PROG"

extra_conf=""

gromacs="no"

BLUE="[34;01m"
CYAN="[36;01m"
GREEN="[32;01m"
RED="[31;01m"
OFF="[0m"

die () {
  cecho RED "$*" >&2
  exit 1
}

cecho() {
  local opts color=" BLUE CYAN GREEN RED "
  if [ -z "${1##-*}" ]; then
    opts="$1"
    shift
  fi
  [ -z "$2" ] && die "cecho: Missing argumet"
  [ -n "${color//* $1 *}" ] && die "cecho: Unknown color ($color allowed)"
  color=${!1}
  shift
  echo -n ${color}
  echo -ne "$@"
  echo $opts "${OFF}"
}

prefix_clean() {
  cd $prefix || die "Dir: '$prefix not found'"
  files="$(ls -d bin include lib share 2>/dev/null)"
  if [ -z "$files" ]; then 
    echo "Found nothing to clean"
    cd -
    return
  fi
  echo "I will $(cecho RED remove):"
  echo $files
  cecho RED "CTRL-C to stop it"
  countdown 10
  rm -rf $files
  cecho GREEN "Done, hope you are happy now"
  cd -
}

countdown() {
  [ -z "$1" ] && "countdown: Missing argument"
  [ -n "${1//[0-9]}" ] && "countdown: argument should be a number"
  for ((i=$1;i>0;i--)); do
    cecho -n CYAN "$i "
    sleep 1
  done
  echo
}

show_help () {
  cat << eof
This is the votca build utils to build votca + rest
Give multiple programs to build them. Nothing meaning:$all

Please visit: $(cecho BLUE www.votca.org)

The most recent version can be found at:
$(cecho BLUE http://dev.votca.org/votca/buildutil/raw-file/tip/build.sh)

$usage
OPTIONS:
$(cecho GREEN -h), $(cecho GREEN --help)              Show this help
    $(cecho GREEN --nocolor)           Disable color
$(cecho GREEN -u), $(cecho GREEN --do-update)         Do a update from hg
$(cecho GREEN -c), $(cecho GREEN --clean-out)         Clean out the prefix
    $(cecho GREEN --no-configure)      Don't run ./configure
    $(cecho GREEN --conf-opts) $(cecho CYAN OPTS)    Extra configure options
    $(cecho GREEN --no-clean)          Don't run make clean
    $(cecho GREEN --no-build)          Don't run make
    $(cecho GREEN --no-install)        Don't run make install
    $(cecho GREEN --prefix) $(cecho CYAN \<prefix\>)   use prefix
                        Default: $prefix
$(cecho GREEN -g), $(cecho GREEN --gromacs)           Set gromacs stuff base up your \$GMXLDLIB

Examples:  ${0##*/} tools csg
           ${0##*/} --do-checkout --prefix ~/tof 
           ${0##*/} -cug tools csg
	
Note: for no passwd add the following 4 lines to your ~/.hgrc
[auth]
votca.prefix = http://dev.votca.org/
votca.username = $USER (???)
votca.password = XXXXX

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
   --nocolor)
   unset BLUE CYAN GREEN OFF RED
   shift;;
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
    cecho GREEN "Doing checkout for $prog (CTRL-C to stop)"
    countdown 5
    ${hg_co//PROG/$prog}
  fi

  cd $prog
  if [ "$do_update" == "yes" ]; then
    cecho GREEN "updating from hg repo"
    hg --config extensions.hgext.fetch= fetch
  fi
  cecho GREEN "compiling $prog"
  if [ "$do_configure" == "yes" ]; then
    ./bootstrap.sh 
    ./configure --prefix "$prefix" $extra_conf 
  fi
  if [ "$do_clean" == "yes" ]; then
    cecho GREEN "cleaning $prog"
    make clean
  fi
  if [ "$do_build" == "no" ]; then 
    cd .. 
    continue
  fi
  cecho GREEN "buidling $prog"
  make
  if [ "$do_install" == "yes" ]; then 
    cecho GREEN "installing $prog"
    make install
  fi
  cd ..
  cecho GREEN "done with $prog"
done
set +e

