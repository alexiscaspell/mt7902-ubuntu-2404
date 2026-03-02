#!/bin/bash -x

echo -n "Build env: "; uname -a
echo "===params==="; echo "'" "$@" "'" ; echo "==========="

OPTIONS=$(getopt -o k: --long kver: -n "$0" -- "$@")
eval set -- "$OPTIONS"

while true ; do
	case "$1" in
		-k|--kver) kernelver=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" ; exit 1 ;;
	esac
done

if [[ -z ${kernelver} ]]; then
    kernelver=$(uname -r)
    echo "No kernel version specified. Using current: $kernelver"
else
    echo "Building for kernel version: $kernelver"
fi

make -C mt76 KVER="$kernelver" V=1
