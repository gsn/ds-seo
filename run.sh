#!/bin/bash

ps auxw | grep forever | grep -v grep > /dev/null

if [ $? != 0 ]
then
  /usr/bin/pkill -f phantom > /dev/null
  /usr/bin/pkill -f forever > /dev/null
  /usr/bin/pkill -f phantom > /dev/null
  /usr/bin/pkill -f node > /dev/null
fi

export RUNDIR="/app/user"

cd $RUNDIR

node_modules/forever/bin/forever start $RUNDIR/prerender/brickServer.js
node_modules/forever/bin/forever --fifo logs 0
