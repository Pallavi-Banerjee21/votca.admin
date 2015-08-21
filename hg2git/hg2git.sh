#!/bin/bash -e

# Make a crontab like this
#
# SHELL=/bin/bash
# PATH=/people/thnfs/homes/junghans/bin:/usr/bin:/usr/sbin:/sbin:/bin
# #min  hour  day  month  dow  user  command
# 15,45  *     *    *      *    . $HOME/.bashrc; $HOME/votca/src/admin/hg2git/hg2git.sh --push $HOME/votca/src/hg2git >~/.votca_hg2git 2>&1

[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || true

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

cfiles="config/libtool.m4 config/ltmain.sh netbeans/csg_reupdate/dist/Debug/GNU-Linux-x86/csg_reupdate src/libcsg/libcsg.a src/tools/csg_reupdate src/tools/ctp_map_exp src/libkmc/libvotca_kmc.so src/libkmc/calculators/kmcmultiple.h.gch src/tools/ctp_run2 src/libkmc/libvotca_kmc.so.orig src/libkmc/calculators/.nfs0000000000b6eabb0000004c src/libkmc/calculators/kmcstandalone.exe src/libboost/config/libtool.m4 src/libboost/config/ltmain.sh src/tools/votca_property config/ltoptions.m4 CMakeCache.txt src/tools/ctp_test config/lt~obsolete.m4 config/ltsugar.m4 src/libexpat/config/libtool.m4 src/libexpat/config/ltmain.sh"

git_big_files(){
  [[ -d .git ]] || die "Not a git repo"
  #find big files
  # @see http://stubbisms.wordpress.com/2009/07/10/git-script-to-show-largest-pack-objects-and-trim-your-waist-line/

  # set the internal field spereator to line break, so that we can iterate easily over the verify-pack output
  old_IFS="$IFS"
  IFS=$'\n'
  # list all objects including their size, sort by size, take top 10
  objects=`git verify-pack -v .git/objects/pack/pack-*.idx | grep -v chain | grep -v "^non.delta" | sort -k3nr | head -25`

  echo "All sizes are in kB's. The pack column is the size of the object, compressed, inside the pack file."
  output="size,pack,SHA,location"
  for y in $objects; do
    # extract the size in bytes
    size=$(( $(echo $y | awk '{print $3}') / 1024))
    # extract the compressed size in bytes
    compressedSize=$(( $(echo $y | awk '{print $4}') / 1024))
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

for i in *.hg; do
  i="${i%.hg}"
  hg="${i}.hg"
  git="${i}.git"
  [[ -d $hg ]] || hg clone "https://code.google.com/p/votca.$i/" "$hg"
  [[ ! -f ${git}.authors || ! -f ${git}.big_files || ! -f ${git}.tags ]] \
	  || hg incoming -R "$hg" || continue
  hg pull -R "$hg" -u
  [[ -d $git ]] || git init "$git"
  pushd $git
  $hg_fast_export -r ../$hg -A "$authors" --hgtags
  [[ $clean = no ]] || git gc --aggressive --prune=all
  git log | grep "^Author:" | sort -u > ../${git}.authors
  git tag -l | sort -u > ../${git}.tags
  echo "$git" > ../${git}.big_files
  git_big_files >> ../${git}.big_files
  if [[ $push = yes && $clean = no ]]; then
    git push --all
    git push --tags
  fi
  popd
  [[ $clean = yes ]] || continue
  git2=${i}.cgit
  [[ -d $git2 ]] && rm -rf $git2
  git clone $git $git2
  pushd $git2
  [[ -n $cfiles ]] && git filter-branch --index-filter "git rm --cached --ignore-unmatch $cfiles" -- --all
  [[ -z $(git for-each-ref --format="%(refname)" refs/original/) ]] || \
    git for-each-ref --format="%(refname)" refs/original/ | xargs -n 1 git update-ref -d
  git reflog expire --expire=now --all
  git gc --aggressive --prune=all
  git remote set-url origin "git@github.com:votca/$git"
  for t in $(git tag -l); do
     [[ $t = release_* ]] || continue
     git tag v${t#release_} $t
     git tag -d $t
  done
  [[ $push = no ]] || git ls-remote --tags origin | awk '($2 ~ /refs\/tags\/release/){print ":" $2}' | xargs -r git push origin
  [[ $push = no ]] || git push -f --all
  [[ $push = no ]] || git push -f --tags
  echo $git2 > ../${git2}.big_files
  git_big_files >> ../${git2}.big_files
  git tag -l | sort -u > ../${git2}.tags
  popd
  du -sh $git/.git $git2/.git > ${git}.size
done
cat *.git.authors | sort -u > git.authors
cat *.git.tags | sort -u > git.tags
cat *.git.big_files > git.big_files
if [[ $clean = yes ]]; then
  cat *.cgit.tags | sort -u > cgit.tags
  cat *.cgit.big_files > cgit.big_files
  cat *.git.size > cgit.size
fi
