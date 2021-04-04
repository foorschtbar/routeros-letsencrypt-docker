#!/bin/sh
set -a

#RUN it once to initiate
LEGO_MODE=run /app/run.sh

crond -f