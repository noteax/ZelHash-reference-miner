#!/bin/bash

. h-manifest.conf

CUSTOM_LOG_BASEDIR=`dirname "$CUSTOM_LOG_BASENAME"`
[[ ! -d $CUSTOM_LOG_BASEDIR ]] && mkdir -p $CUSTOM_LOG_BASEDIR

zelhash-opencl-miner --server $CUSTOM_URL --user $CUSTOM_TEMPLATE 2>&1 | tee $CUSTOM_LOG_BASENAME.log