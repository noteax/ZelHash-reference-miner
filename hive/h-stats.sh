#!/bin/bash

get_miner_uptime() {
  local tmp=$(cat $LOG_NAME | grep " Performance" | head -n 1 | cut -d " " -f1 | sed 's/:$//')
  local start=$(date +%s -d "$tmp")
  local now=$(date +%s)
  echo $((now - start))
}

get_cards_hashes(){
  local card_hashes=`cat $LOG_NAME | grep -a Performance: | tail -n 1 | sed -n "s/^.*Performance: \(.*\) |.*$/\1/p" | sed "s/ sol\/s/,/g" | sed 's/,$//'`
  echo $card_hashes
}

get_total_hashes(){
  local total=`cat $LOG_NAME | grep -a Total | tail -n 1 | awk '{ printf $(NF-1)"\n" }' | awk '{ printf $1/1000"\n" }'`
  echo $total
}

get_log_time_diff(){
  local getLastLogTime=$(cat $LOG_NAME | grep " Performance" | tail -n 1 | cut -d " " -f1 | sed 's/:$//')
  local logTime=`date --date="$getLastLogTime" +%s`
  local curTime=`date +%s`
  echo `expr $curTime - $logTime`
}


################# Start #################

. /hive/miners/custom/zelhash-opencl-miner/h-manifest.conf
LOG_NAME="$CUSTOM_LOG_BASENAME.log"

stats=""
khs=0

# Calc log freshness
diffTime=$(get_log_time_diff)
maxDelay=120

if [ "$diffTime" -lt "$maxDelay" ]; then
  khs=$(get_total_hashes)
  stats="
    { 
	  \"hs\": [$(get_cards_hashes)],
	  \"hs_units\": \"hs\", 
	  \"uptime\": $(get_miner_uptime),
	  \"ver\": \"1.0.0\"
    }
  "
fi

