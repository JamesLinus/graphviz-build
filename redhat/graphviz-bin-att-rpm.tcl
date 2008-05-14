#!/usr/bin/tclsh

# $Id$ $Revision$

#################################################

set graphviz_host www.graphviz.org
set graphviz_path /pub/graphviz
set redhat_release /etc/redhat-release

################################################
set start_time [clock format [clock seconds]]

if {[catch {exec hostname -f} build_host]} {
	set build_host [exec uname -n]
}
set work $env(HOME)/tmp/gviz/$build_host
set rpmbuild $env(HOME)/rpmbuild/$build_host
file mkdir $work $rpmbuild/BUILD $rpmbuild/SPECS $rpmbuild/RPMS $rpmbuild/SRPMS

set source_dir CURRENT
if {$argc} {
   set source_dir [lindex $argv 0]
}
set path $graphviz_path/ATT_$source_dir

proc getfile {host path sourcefile} { exec scp $host:/$path/$sourcefile . }
proc putfile {host path fn} { exec scp $fn $host:/$path/ }
proc getindex {host path} { exec ssh $host ls $path }

set patterns {
	"Fedora Core release (\[0-9\]+)" ".fc" 0 att_fedora
	"Fedora release (\[0-9\]+).*(Rawhide)" ".fc" 1 att_fedora
	"Fedora release (\[0-9\]+)" ".fc"  0 att_fedora
	"CentOS release (\[0-9\]+)" ".el" 0 att_rhel
	"Red Hat Enterprise Linux Server release (\[0-9\]+)" ".el" 0 att_rhel
	"Red Hat Enterprise Linux ES release (\[0-9\]+)" ".el" 0 att_rhel
	"Red Hat Enterprise Linux AS release (\[0-9\]+)" ".el" 0 att_rhel
	"Red Hat Linux release (\[0-9\]+)" ".rhl" 0 att_rhl
}

# as far as I can tell, rpmbuild --macros doesn't work,
# so we must explicitly set %fedora and %dist and 
# pass them on the rpmbuild command line, to run in an environment
# where ~/.rpmmacros may be shared (e.g. virtual hosts).
proc rpmbuildargs {release} {
	global vers os dist patterns;
	if {! [file readable $release]} {
		puts stderr "cannot read $release, giving up.";
		exit
	}
	set f [open $release r]
	set line [read $f]
	set rc 0
	foreach {pat osprefix offset os} $patterns {
		set rc [regexp $pat $line . vers]
		if {$rc} {
			set vers [expr ($vers + $offset)]
			set dist $osprefix$vers
			break
		}
	}
	if {! $rc} {
		puts stderr "can't determine OS release from $release";
		exit
	}
	close $f
	set rv [concat --define \"dist $dist\" --define \"$os $vers\"]
	return $rv
}

# automatically determine arch and dist
set arch $tcl_platform(machine)

# set rpm options from database
set rpmopt [rpmbuildargs $redhat_release]

#clean up any previous build
foreach f [glob -nocomplain $rpmbuild/RPMS/*/graphviz-*] {file delete -force $f}
foreach f [glob -nocomplain $rpmbuild/*/graphviz*] {file delete -force $f}
foreach f [glob -nocomplain $work/graphviz*] {file delete -force $f}

cd $work

set index [getindex $graphviz_host $path]
foreach {. v} [regexp -all -inline -- {graphviz-([0-9.]*?att).tar.gz} $index] {
  lappend versions $v
}
if {! [info exists versions]} {
    error "no graphviz snapshots found"
}
set version [lindex [lsort -decreasing -dictionary $versions] 0]

set sourcefile graphviz-$version.tar.gz

puts "getting http://$graphviz_host/$path/$sourcefile"

# get sourcefile into local temporary directory
getfile $graphviz_host $path $sourcefile

puts "making..."
# make products
puts "rpmbuild $rpmopt -tb $sourcefile"
catch "exec rpmbuild $rpmopt -tb $sourcefile" buildlog

#set end_build_time [clock format [clock seconds]]

#cd $rpmbuild/BUILD/graphviz-$version/rtest
#catch "exec ./rtest.sh" rtestlog
#cd $work

set end_time [clock format [clock seconds]]

puts  "...done making."

set BUILDLOG graphviz-linux-buildlog-$version$dist.$arch.txt
set f [open $BUILDLOG w]
puts $f $start_time
puts $f ""
puts $f $buildlog
puts $f ""
#puts $f $end_build_time
#puts $f ""
#puts $f $rtestlog
#puts $f ""
puts $f $end_time
close $f

set productfiles [concat \
  [glob -nocomplain $rpmbuild/RPMS/*/graphviz*$version*.rpm] \
  $BUILDLOG]

foreach fn $productfiles {
  putfile $graphviz_host $path $fn
}

puts "done"
