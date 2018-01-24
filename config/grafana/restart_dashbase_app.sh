#!/bin/sh

curl -k 'http://admin:admin@grafana:3000/api/plugins/dashbase-app/settings' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"enabled": false}' \
 && curl -k 'http://admin:admin@grafana:3000/api/plugins/dashbase-app/settings' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"enabled": true}' \
 && sleep 356d
