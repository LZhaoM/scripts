#!/bin/bash 

# SPDX-License-Identifier: GPL-2.0

# This script configures the UVC Gadget through configfs so the device side of
# a USB connection appears as a UVC specification compliant camera on the host
# side.  It is intended to run on a GNU/Linux system that has USB device-side
# hardware such as boards with an OTG port.

# By itself, the UVC Gadget driver cannot do anything particularly interesting.
# It must be paired with a userspace program that responds to UVC control
# requests and fills buffers to be queued to the V4L2 device that the driver
# creates. See:
# https://origin.kernel.org/doc/html/v6.19/usb/gadget_uvc.html#the-userspace-application

# Requirements:
# https://origin.kernel.org/doc/html/v6.19/usb/gadget_uvc.html#configuring-the-device-kernel

# This script is based on the following two Linux documentation links:
# https://origin.kernel.org/doc/html/v6.19/usb/gadget_uvc.html
# https://origin.kernel.org/doc/html/v6.19/usb/gadget_configfs.html

UDC="g1"
CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget/$UDC"
FUNCTION="$GADGET/functions/uvc.0"

configfs_make()
{
    if [[ ! -e $GADGET ]];
    then
        mkdir -p $GADGET
        pushd $GADGET

        echo "0x1d6b" > "idVendor"  # Linux Foundation
        echo "0x0104" > "idProduct" # Multifunction Composite Gadget
        echo "0x0100" > "bcdDevice" # v1.0.0
        echo "0x0200" > "bcdUSB"    # USB 2.0
        echo "0xEF" > "bDeviceClass"
        echo "0x02" > "bDeviceSubClass"
        echo "0x01" > "bDeviceProtocol"

        popd
    fi
    if [[ ! -e "$GADGET/strings/0x409" ]];
    then
        mkdir -p "$GADGET/strings/0x409"
        pushd "$GADGET/strings/0x409"

        echo "0123456789ABCDEF" > "serialnumber"
        echo "Radxa" > "manufacturer"
        echo "OTG Utils" > "product"

        popd
    fi
    if [[ ! -e "$GADGET/configs/r.1" ]];
    then
        mkdir -p "$GADGET/configs/r.1"
        pushd "$GADGET/configs/r.1"

        echo "500" > "MaxPower"

        popd
    fi
    if [[ ! -e "$GADGET/configs/r.1/strings/0x409" ]];
    then
        mkdir -p "$GADGET/configs/r.1/strings/0x409"
        pushd "$GADGET/configs/r.1/strings/0x409"

        echo "USB Composite Device" > "configuration"

        popd
    fi
}

create_frame() {
        # Example usage:
        # create_frame <width> <height> <group> <format name>

        WIDTH=$1
        HEIGHT=$2
        FORMAT=$3
        NAME=$4

        wdir=$FUNCTION/streaming/$FORMAT/$NAME/${HEIGHT}p

        mkdir -p $wdir
        echo $WIDTH > $wdir/wWidth
        echo $HEIGHT > $wdir/wHeight
        echo $(( $WIDTH * $HEIGHT * 2 )) > $wdir/dwMaxVideoFrameBufferSize
        cat <<EOF > $wdir/dwFrameInterval
666666
100000
5000000
EOF
}

modprobe libcomposite
modprobe usb_f_uvc
configfs_make

mkdir -p $FUNCTION

# You must configure the gadget by telling it which formats you support, as
# well as the frame sizes and frame intervals that are supported for each
# format.
# https://origin.kernel.org/doc/html/v6.19/usb/gadget_uvc.html#formats-and-frames
create_frame 1280 720 mjpeg mjpeg
#create_frame 1920 1080 mjpeg mjpeg
#create_frame 1280 720 uncompressed yuyv
#create_frame 1920 1080 uncompressed yuyv

# Header linking is required
# https://origin.kernel.org/doc/html/v6.19/usb/gadget_uvc.html#formats-and-frames
mkdir $FUNCTION/streaming/header/h
pushd $FUNCTION/streaming/header/h
#ln -s ../../uncompressed/yuyv
ln -s ../../mjpeg/mjpeg
cd ../../class/fs
ln -s ../../header/h
cd ../../class/hs
ln -s ../../header/h
cd ../../class/ss
ln -s ../../header/h
cd ../../../control
mkdir header/h
ln -s header/h class/fs
ln -s header/h class/ss
popd

# https://origin.kernel.org/doc/html/v6.19/usb/gadget_configfs.html#associating-the-functions-with-their-configurations
ln -s $FUNCTION "$GADGET/configs/r.1"
