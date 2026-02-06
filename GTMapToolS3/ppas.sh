#!/bin/sh
DoExitAsm ()
{ echo "An error occurred while assembling $1"; exit 1; }
DoExitLink ()
{ echo "An error occurred while linking $1"; exit 1; }
echo Linking GTMapTool
OFS=$IFS
IFS="
"
/usr/bin/ld -b elf64-x86-64 -m elf_x86_64  --build-id     -L. -o GTMapTool link.res
if [ $? != 0 ]; then DoExitLink GTMapTool; fi
IFS=$OFS
