#!/bin/sh
set -a

echo "+++ Welcome to routeros-letsencrypt +++"

# Run it once to initiate
echo "Run it once to initiate..."
/app/run.sh

# Starting cron daemon
echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Starting cron daemon..."
crond -f -L /dev/stdout