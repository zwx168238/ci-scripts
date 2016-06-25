#!/bin/bash
download_distro()
{
    Distro=$1
    download_url=$2
    arch=$3
    board=$4
    distro=$(echo $distro | tr '[:upper:]' '[:lower:]')
    ARCH=$(echo $arch | tr '[:lower:]' '[:upper:]')
	BOARD=$(echo $board | tr '[:lower:]' '[:upper:]')
    distro_def=${Distro}_$ARCH
	echo $distro_def
    pushd $location
	pushd $distro_loc
	    [ ! -d $BOARD ] && mkdir $BOARD
	    pushd $BOARD
	    dist_name=${distro}$ARCH
	    if [ -d $dist_name ]; then
		sudo rm -rf $dist_name
	    fi
	    sudo mkdir $dist_name
	    wget -P $dist_name -c $download_url/distro/${distro_def}.tar.gz
	    popd
	popd
    popd
}

location=/targetNFS/ubuntu_for_deployment
distro_loc=./sys_setup/distro
distro=$1
download_url=$2
arch=$3
board=$4
echo "Download $distro from $dowload_url"
download_distro $distro  $download_url $arch $board
