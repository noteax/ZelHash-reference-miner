#!/bin/bash

. h-manifest.conf

CUSTOM_LOG_BASEDIR=`dirname "$CUSTOM_LOG_BASENAME"`
[[ ! -d $CUSTOM_LOG_BASEDIR ]] && mkdir -p $CUSTOM_LOG_BASEDIR

cmd_line=$(cat tmfile)
zelhash-opencl-miner $cmd_line 2>&1 | tee $CUSTOM_LOG_BASENAME.log