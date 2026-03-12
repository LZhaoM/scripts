#!/bin/bash

# SPDX-License-Identifier: GPL-2.0

# This script is based on the following two Linux documentation links:
# https://origin.kernel.org/doc/html/v6.19/usb/gadget-testing.html#hid-function
# https://origin.kernel.org/doc/html/v6.19/usb/gadget_configfs.html

UDC="g1"
CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget/$UDC"
FUNCTION="$GADGET/functions/hid.0"

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

modprobe libcomposite
modprobe usb_f_hid
configfs_make

mkdir -p $FUNCTION

echo 1 > $FUNCTION/protocol
echo 1 > $FUNCTION/subclass
echo 8 > $FUNCTION/report_length
echo -ne \\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0 > $FUNCTION/report_desc

ln -s $FUNCTION "$GADGET/configs/r.1"
