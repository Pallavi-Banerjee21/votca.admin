#!/bin/bash -e

# Make a crontab like this
#
# SHELL=/bin/bash
# PATH=/people/thnfs/homes/junghans/bin:/usr/bin:/usr/sbin:/sbin:/bin
# #min  hour  day  month  dow  user  command
# 15,45  *     *    *      *    . $HOME/.bashrc; $HOME/votca/src/admin/hg2git/hg2git.sh --push $HOME/votca/src/hg2git >~/.votca_hg2git 2>&1

# before enabling --push, so something like
# git remote add origin git@github.com:votca/csgapps.git
die() {
  echo "$@" >&2
  exit 1
}

push=no
clean=no

[[ $1 = --help ]] && echo "${0##*/} [--push] [--clean] DIR"
[[ $1 = --push ]] && push="yes" && shift
[[ $1 = --clean ]] && clean="yes" && shift
[[ -n $1 ]] || die "Missing dir"
[[ -d $1 ]] || die "Argument is not a dir"

authors="${VOTCA_AUTHORS:=${0%/*}/authors}"
authors=$(realpath $authors)
[[ -f $authors ]] || die "Could find authors file"

hg_fast_export=$(type -p hg-fast-export) || die "Could not find hg-fast-export"

cd "$1"

cfiles="config/libtool.m4 config/ltmain.sh netbeans/csg_reupdate/dist/Debug/GNU-Linux-x86/csg_reupdate src/libcsg/libcsg.a src/tools/csg_reupdate"

git_big_files(){
  [[ -d .git ]] || die "Not a git repo"
  #find big files
  # @see http://stubbisms.wordpress.com/2009/07/10/git-script-to-show-largest-pack-objects-and-trim-your-waist-line/

  # set the internal field spereator to line break, so that we can iterate easily over the verify-pack output
  old_IFS="$IFS"
  IFS=$'\n'
  # list all objects including their size, sort by size, take top 10
  objects=`git verify-pack -v .git/objects/pack/pack-*.idx | grep -v chain | sort -k3nr | head`

  echo "All sizes are in kB's. The pack column is the size of the object, compressed, inside the pack file."
  output="size,pack,SHA,location"
  for y in $objects; do
    # extract the size in bytes
    size=$((`echo $y | cut -f 5 -d ' '`/1024))
    # extract the compressed size in bytes
    compressedSize=$((`echo $y | cut -f 6 -d ' '`/1024))
    # extract the SHA
    sha=`echo $y | cut -f 1 -d ' '`
    # find the objects location in the repository tree
    other=`git rev-list --all --objects | grep $sha`
    #lineBreak=`echo -e "\n"`
    output="${output}\n${size},${compressedSize},${other}"
  done
  echo -e $output | column -t -s ', '
  IFS="$old_IFS"
}

for i in tools csg csg-manual csgapps csg-tutorials; do
  hg="${i}.hg"
  git="${i}.git"
  [[ -d $hg ]] || hg clone "https://code.google.com/p/votca.$i/" "$hg"
  hg incoming -R "$hg" || continue
  hg pull -R "$hg" -u
  [[ -d $git ]] || git init "$git"
  pushd $git
  $hg_fast_export -r ../$hg -A "$authors"
  [[ $clean = no ]] || git gc --aggressive --prune=all
  git log | grep "^Author:" | sort -u > ../${git}.authors
  git_big_files > ../${git}.big_files
  [[ $push = no ]] || git push --all
  popd
  [[ $clean = yes ]] || continue
  git2=${i}.clean.git
  [[ -d $git2 ]] && rm -rf $git2
  git clone $git $git2
  pushd $git2
  [[ -n $cfiles ]] && git filter-branch --index-filter "git rm --cached --ignore-unmatch $cfiles" -- --all
  git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
  git reflog expire --expire=now --all
  git gc --aggressive --prune=all
  git_big_files > ../${git2}.big_files
  popd
  du -sh $git $git2 > ${git}.size
done
cat *.git.authors | sort -u > git.authors
