#!/bin/bash

export RUNDIR="/app/user"

cd $RUNDIR

node_modules/forever/bin/forever start $RUNDIR/prerender/brickServer.js
node_modules/forever/bin/forever --fifo logs 0
