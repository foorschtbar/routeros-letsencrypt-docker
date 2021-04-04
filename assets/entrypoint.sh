#!/bin/sh
set -a

echo "+++ Welcome to routeros-letsencrypt +++"

# Run it once to initiate
echo "Run it once to initiate..."
LEGO_MODE=run /app/run.sh

# Starting cron daemon
echo "+++++++++++++++++++++++++++++++++++++++++++++"
echo "Starting cron daemon..."
crond -f -L /dev/stdout