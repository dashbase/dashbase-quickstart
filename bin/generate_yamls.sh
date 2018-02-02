#!/bin/bash

BASEDIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd)"

echo "Running docker-compose -f ... config to generate stack yaml files for Kafka, Core, and Elastic."
echo
docker-compose -f $BASEDIR/kafka-stack.yml -f $BASEDIR/kafka-aws-stack.yml config > $BASEDIR/kafka.yml
docker-compose -f $BASEDIR/core-stack.yml -f $BASEDIR/core-aws-stack.yml config > $BASEDIR/core.yml
docker-compose -f $BASEDIR/elastic-stack.yml -f $BASEDIR/elastic-aws-stack.yml config > $BASEDIR/elastic.yml
echo
echo "Done."