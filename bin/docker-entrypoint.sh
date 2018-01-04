#!/bin/bash

kafka-console-producer.sh --topic quickstart --broker-list ${KAFKA_BROKER_URL} \
  --producer-property security.protocol=SSL \
  --producer-property ssl.truststore.location=/var/run/keystore \
  --producer-property ssl.keystore.location=/var/run/keystore \
  --producer-property ssl.truststore.password=${KEYSTORE_PASSWORD} \
  --producer-property ssl.keystore.password=${KEYSTORE_PASSWORD} \
  --producer-property ssl.key.password=${KEYSTORE_PASSWORD} < /data/nginx_sample.json
