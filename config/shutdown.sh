#!/usr/bin/with-contenv bash
# notify the sidecar of imminent shutdown
PORT=${AUTOSCALER_SIDECAR_PORT:-6000}
curl -d '{}' -v 0:$PORT/hook/v1/shutdown
sleep 10

# Add aws ec2 removal code here
