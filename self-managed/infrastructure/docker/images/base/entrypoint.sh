#!/bin/bash

# Start Dropbear SSH server
dropbear -s -g -F -R -E -p 22 > /tmp/dropbear.log 2>&1 &

# Run the command if specified
if [ "$#" -ne 0 ]; then
  echo "Running command: $@"
  exec "$@" &

  # Block using tail so the trap will fire
  tail -f /dev/null &
  PID=$!
  wait $PID
else
  ## If no command is passed runs forever
  while :; do
    sleep 1
  done
fi
