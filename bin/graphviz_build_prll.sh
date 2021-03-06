#!/bin/bash

# set DIR=ARCHIVE to build stable release
#     DIR=CURRENT (or empty) to build the current snapshot
DIR=$1
ERR=graphviz_build_err
OUT=graphviz_build_out
rm -rf $ERR $OUT

BUILD_HOSTS="
        bld-centos6
        bld-centos6-32
        bld-centos7
        bld-centos7-32
        bld-fedora23
        bld-fedora23-32
        bld-fedora24
        bld-fedora24-32
        bld-fedora25
        bld-fedora25-32
        bld-fedora26
        bld-fedora26-32
        bld-fedora27
        bld-fedora27-32
"
pssh -H "$BUILD_HOSTS" -l gviz -o $OUT -e $ERR -t 12000 -p 4 graphviz-build/redhat/graphviz-bin-rpm.tcl $DIR

BUILD_HOSTS="
	pome
"
pssh -H "$BUILD_HOSTS" -l gviz -o $OUT -e $ERR -t 12000 -p 4 graphviz-build/macosx/graphviz-mountainlion-bin-pkg.sh $DIR

BUILD_HOSTS="
	empire
"
pssh -H "$BUILD_HOSTS" -l gviz -o $OUT -e $ERR -t 12000 -p 4 graphviz-build/macosx/graphviz-lion-bin-pkg.sh $DIR
