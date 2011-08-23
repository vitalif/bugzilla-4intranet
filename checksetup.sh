#!/bin/sh
LD_PRELOAD=/usr/lib/i386-linux-gnu/libstdc++.so.6:/lib/libuuid.so.1 perl checksetup.pl --no-chmod --no-templates
