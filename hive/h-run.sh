#!/bin/bash

. h-manifest.conf

CUSTOM_LOG_BASEDIR=`dirname "$CUSTOM_LOG_BASENAME"`
[[ ! -d $CUSTOM_LOG_BASEDIR ]] && mkdir -p $CUSTOM_LOG_BASEDIR

zelhash-opencl-miner $(< $CUSTOM_CONFIG_FILENAME) 2>&1 | tee --append $MINER_LOG_BASENAME.log