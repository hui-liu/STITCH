#!/usr/bin/env bash

set -e
script_dir=`dirname "$0"`
cd "${script_dir}"/../
./scripts/install-r-dependencies.R

export PATH=${PATH}:`pwd`/

# Install bgzip and optionally samtools into dependencies
# symlink them into the STITCH directory

# only bother if library files not presen
one_if_curl_installed=`which curl | wc -l`
one_if_wget_installed=`which wget | wc -l`
ancillary_http="http://www.well.ox.ac.uk/~rwdavies/ancillary/"
samv=1.3.1
bcftoolsv=1.3.1
htslibv=1.3.2
mkdir -p dependencies

# This is no longer required in STITCH 1.3.0
# but leave in for now, can be useful to have easy install
force_install=${1:-nope}
#zero_if_samtools_not_installed=`which samtools | wc -l`
# if [ $force_install == "samtools" ] || [$zero_if_samtools_not_installed == 0 ] || 
if [ $force_install == "samtools" ]
then
    echo install samtools
    cd dependencies
    if [ $one_if_curl_installed == 1 ]
    then
	curl "${ancillary_http}samtools-${samv}.tar.bz2" -o "samtools-${samv}.tar.bz2"
    elif [ $one_if_wget_installed == 1 ]
    then
	wget "${ancillary_http}samtools-${samv}.tar.bz2"
    fi
    bzip2 -df samtools-${samv}.tar.bz2
    tar -xvf samtools-${samv}.tar
    cd samtools-${samv}
    ./configure
    make all
    cd ../../
    ## add soft link
    dir=`pwd`
    rm -f samtools
    ln -s "${dir}/dependencies/samtools-${samv}/samtools" "${dir}/samtools"
fi


force_install=${1:-nope}
if [ $force_install == "bcftools" ]
then
    echo install bcftools
    cd dependencies
    if [ $one_if_curl_installed == 1 ]
    then
	curl "${ancillary_http}bcftools-${bcftoolsv}.tar.bz2" -o "bcftools-${bcftoolsv}.tar.bz2"
    elif [ $one_if_wget_installed == 1 ]
    then
	wget "${ancillary_http}bcftools-${bcftoolsv}.tar.bz2"
    fi
    bzip2 -df bcftools-${bcftoolsv}.tar.bz2
    tar -xvf bcftools-${bcftoolsv}.tar
    cd bcftools-${bcftoolsv}
    make all
    cd ../../
    ## add soft link
    dir=`pwd`
    rm -f bcftools
    ln -s "${dir}/dependencies/bcftools-${bcftoolsv}/bcftools" "${dir}/bcftools"
fi



zero_if_bgzip_not_installed=`which bgzip | wc -l` 
if [ $zero_if_bgzip_not_installed == 0 ] || [ $force_install == "bgzip" ]
then
    echo install bgzip
    cd dependencies
    if [ $one_if_curl_installed == 1 ]
    then
	curl "${ancillary_http}htslib-${htslibv}.tar.bz2" -o "htslib-${htslibv}.tar.bz2"
    elif [ $one_if_wget_installed == 1 ]
    then
	wget "${ancillary_http}htslib-${htslibv}.tar.bz2"
    fi
    bzip2 -df htslib-${htslibv}.tar.bz2
    tar -xvf htslib-${htslibv}.tar
    cd htslib-${htslibv}
    ./configure
    make all
    cd ../../
    ## add soft link
    dir=`pwd`
    rm -f bgzip
    ln -s "${dir}/dependencies/htslib-${htslibv}/bgzip" "${dir}/bgzip"
fi
