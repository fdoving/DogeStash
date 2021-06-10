#!/bin/bash
# Quick hack made to build Dogecoin from git, with depends.
# Made for ubuntu, might work on debian and alike.
# It's best if you understand it, before using it.
# Best used in a docker or similar.
#
# USAGE: ./build-from-git.sh <platform> <branch> <makethreads>
# where platform is one of: windows, osx, linux, arm32v7

# PREF = prefix to WORKPRE. Set this and the rest will be automagic.
# WORKPRE = the directory where everything happens. we cd $WORKDIR before cloning from git.
# GITDIR is the name of the directory we clone into, from git. 
# GITBRANCH is the branch we checkout from git.
# BUILDFOR is the first and only argument to this command, it's linux, windows, arm32v7 or osx.
# THREADS is number of threads we try to use. Some, like openssl, forces -j1. I use distcc. typical should be set to around available cores.
# BASEREF should be set to release for releases, does not matter what else it is when it's not releases.

BASEREF=dev
RELEASEDIR=/root/dogerelease/
PREF=/dogebuild/
GITDIR=dogecoin
GITURL=https://github.com/fdoving/dogecoin
GITBRANCH=$2
WORKPRE=$PREF/
WORKDIR=$WORKPRE/$GITDIR/
THREADS=$3
SCRIPTDIR=`pwd`/scripts/

if [ $# -lt 3 ]
  then
    echo "USAGE: $0 <platform> <git-branch> <make-threads>"
    echo "Example: $0 linux,osx,windows master 8"
	exit 1
fi

# make sure we have git
apt update
apt install git

# checkout git, modify to your own usage.
# if you want to start clean every time uncomment next line.
# rm -rf $WORKPRE
	mkdir -p $WORKPRE
	cd $WORKPRE
	git clone $GITURL
	cd $GITDIR
	git checkout $GITBRANCH
	git pull

build () {
    BUILDFOR=$1
    WORKDIR=$WORKPRE/$1
    cd $WORKDIR
    # install depends from apt.
    DEBIAN_FRONTEND=noninteractive \
    $SCRIPTDIR/00-install-deps.sh $BUILDFOR
    # build or copy depends. Increase number of threads -j2 with -jTHREADS
    echo "Setting threads to $THREADS in 02-copy-build*...."
    sed -i.old 's/\-j2/\-j'$THREADS'/g' $SCRIPTDIR/02-copy-build-dependencies.sh
    $SCRIPTDIR/02-copy-build-dependencies.sh $BUILDFOR $WORKDIR
    echo "Reverting threads in 02-copy-build*...."
    cp $SCRIPTDIR/02-copy-build-dependencies.sh.old \
    $SCRIPTDIR/02-copy-build-dependencies.sh
    # setup environment
    $SCRIPTDIR/03-export-path.sh $BUILDFOR $WORKDIR
    # autogen
    $WORKDIR/autogen.sh
    # configure build
    $SCRIPTDIR/04-configure-build.sh $BUILDFOR $WORKDIR
    # build
    make -j$THREADS
    # run tests
#    $SCRIPTDIR/05-binary-checks.sh $BUILDFOR
    # we need this to build packages for osx. Should be pushed to master depends.
    if [ $1 == "osx" ]
      then
    	apt install -y python3-pip
	pip3 install ds_store
    fi

    # package
#    $SCRIPTDIR/06-package.sh $BUILDFOR $WORKDIR $BASEREF
#    # copy packages to 
#    mkdir -p $RELEASEDIR
#    cp $WORKDIR/release/* $RELEASEDIR
#    echo "Products copied to $RELEASEDIR"
    echo "The end."


#    cd $WORKDIR
#    rm -rf release stage
#    make clean

}

split_list () {
    build_targets=$(echo $1|tr ',' ' ')
}

# make list of build targets
split_list $1

# copy git-dir
for target in $build_targets;do cp -r $WORKDIR $WORKPRE/$target;done 
# pull in all dirs
for target in $build_targets;do cd $WORKPRE/$target;git pull;done 

# build loop
for target in $build_targets;do build $target; done


