FROM wurstmeister/kafka:1.0.0

MAINTAINER kevin@dashbase.io

ADD ./bin/docker-entrypoint.sh /docker-entrypoint.sh

CMD ["./docker-entrypoint.sh"]
