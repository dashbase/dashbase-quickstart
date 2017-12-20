#!/usr/bin/env bash

# This scripts extracts User ID from dashbase-license.yml and sets it as KAFKA_TOPIC,
# and also generates keystore and sets its password in KEYSTORE_PASSWORD.

if [[ -z "$1" ]]
then
  echo "
Missing your dashbase.io email.
Usage:

  ./bin/prepare.sh <email>"
  exit 1
fi

BASEDIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd)"

# Prepare the license file by curling dashbase.io/license/get
echo "Getting license from dashbase.io and save to dashbase-license.yml locally. Will require your dashbase.io password."
echo "user: $1" > ${BASEDIR}/dashbase-license.yml
echo -n "license: " >> ${BASEDIR}/dashbase-license.yml
if ! command -v curl >/dev/null; then
  echo "`curl` not installed. Please get Dashbase license manually."
  exit 1
else
  KEY="$(curl https://www.dashbase.io/license/get -u $1)"
  echo -n "$KEY" >> ${BASEDIR}/dashbase-license.yml
  echo
  echo "$(cat ${BASEDIR}/dashbase-license.yml)"
  echo
fi

# Get cleaned user id to use as default Kafka topic
export USER_ID=$(cat $BASEDIR/dashbase-license.yml | grep user | sed -e 's/user://' -e 's/ //g' -e 's/[^a-zA-Z0-9\-]/-/g')
if [ -z "$USER_ID" ]; then
  echo "Cannot find User ID from dashbase-license.yml. Please make sure to configure dashbase-license.yml properly."
  exit -1
fi
export KEYSTORE_PATH="${BASEDIR}/keystore"
export CA_KEY_PATH="${BASEDIR}/ca-key.pem"
export CA_CERT_PATH="${BASEDIR}/ca-cert.pem"
export CLIENT_CERT_PATH="${BASEDIR}/client-cert.pem"
export CLIENT_KEY_PATH="${BASEDIR}/client-key.pem"
export KEYSTORE_ENV="${BASEDIR}/env"
export P12KEYSTORE_PATH="${BASEDIR}/keystore.p12"

# Bash generate random 32 character alphanumeric string (upper and lowercase) and
export KEYSTORE_PASSWORD=$(cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

echo "
KAFKA_TOPIC=${USER_ID}
KAFKA_CREATE_TOPICS=${USER_ID}:1:1,quickstart:1:1

KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
KAFKA_SSL_KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD}
KAFKA_SSL_KEY_PASSWORD=${KEYSTORE_PASSWORD}
KAFKA_SSL_TRUSTSTORE_PASSWORD=${KEYSTORE_PASSWORD}
" > ${KEYSTORE_ENV}

echo "Generated keystore password, values saved in '${KEYSTORE_ENV}' and 'docker-compose.yml'"

echo "Deleting previous generated self signed SSL cert"
rm $KEYSTORE_PATH

echo "Get SSL cert and private key"

# Create keystore (self signed certificate)
docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim keytool -genkey -noprompt \
 -alias dashbase \
 -dname "CN=dashbase.io, OU=Engineering, O=Dashbase, L=Santa clara, S=CA, C=US" \
 -keystore ${KEYSTORE_PATH} \
 -storepass ${KEYSTORE_PASSWORD} \
 -keypass ${KEYSTORE_PASSWORD} \
 -keyalg RSA  \
 -validity 3650 \
 -keysize 2048

docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim keytool -importkeystore -srckeystore $KEYSTORE_PATH \
  -destkeystore $P12KEYSTORE_PATH -deststoretype PKCS12 \
  -deststorepass $KEYSTORE_PASSWORD -srcstorepass $KEYSTORE_PASSWORD

# Generate CA cert and key
docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim openssl req -new -x509 -keyout ${CA_KEY_PATH} -out ${CA_CERT_PATH} \
 -days 3650 -config ${BASEDIR}/bin/openssl.conf \
 -passout pass:${KEYSTORE_PASSWORD}

# export cert file from keystore
docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim keytool -keystore ${KEYSTORE_PATH} -alias dashbase -certreq \
 -file tmp-cert-file -storepass ${KEYSTORE_PASSWORD}

# sign the cert with CA key
docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim openssl x509 -req -CA ${CA_CERT_PATH} -CAkey ${CA_KEY_PATH} \
 -in tmp-cert-file -out tmp-cert-signed -days 3650 \
 -CAcreateserial -passin pass:${KEYSTORE_PASSWORD}

# import back unsigned and signed cert
docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim keytool -importcert -keystore ${KEYSTORE_PATH} -alias CARoot \
 -file ${CA_CERT_PATH} -storepass ${KEYSTORE_PASSWORD} -noprompt -trustcacerts
keytool -importcert -keystore ${KEYSTORE_PATH} -alias dashbase \
 -file tmp-cert-signed -storepass ${KEYSTORE_PASSWORD}

# generate key and cert for client (e.g., filebeat)
docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim openssl req -nodes -new -keyout $CLIENT_KEY_PATH -out tmp-client-cert.pem \
 -days 3650 -config ${BASEDIR}/bin/openssl.conf

docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim openssl x509 -req -CA ${CA_CERT_PATH} -CAkey ${CA_KEY_PATH} \
 -in tmp-client-cert.pem -out $CLIENT_CERT_PATH -days 3650 \
 -CAcreateserial -passin pass:${KEYSTORE_PASSWORD}

# remove unnecessary files
rm tmp-* ca-cert.srl

docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim openssl pkcs12 -in $P12KEYSTORE_PATH -nokeys -out $BASEDIR/cert.pem -passin pass:$KEYSTORE_PASSWORD
docker run -v $PWD:${BASEDIR} -w ${BASEDIR} openjdk:8-slim openssl pkcs12 -in $P12KEYSTORE_PATH -nodes -nocerts -out $BASEDIR/key.pem -passin pass:$KEYSTORE_PASSWORD
# Cleanup
rm $P12KEYSTORE_PATH

echo "Completed generating keystore."
echo
echo "The following step only applies to Docker on AWS."

# Prepare AWS credentials for REX-ray
echo "Getting AWS credentials for REX-ray."
if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ -z "$AWS_SECRET_ACCESS_KEY" ]]
then
  echo "No env variables found, checking ~/.aws/credentials file."
  if [[ -e ~/.aws/credentials ]]
  then
    echo "Credentials found. Setting credentials for REX-ray command."
    export AWS_ACCESS_KEY_ID="$(cat ~/.aws/credentials | grep -E 'aws_access_key_id = (.*)' | sed 's/aws_access_key_id = //')"
    export AWS_SECRET_ACCESS_KEY="$(cat ~/.aws/credentials | grep -E 'aws_secret_access_key = (.*)' | sed 's/aws_secret_access_key = //')"
  fi
  if [[ -z "$AWS_ACCESS_KEY_ID" ]] || [[ -z "$AWS_SECRET_ACCESS_KEY" ]]
  then
    echo "No AWS credentials were found. Please manually enter AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY values into $BASEDIR/rexray_cmd."
  fi
fi

echo "docker plugin install --grant-all-permissions rexray/ebs EBS_ACCESSKEY=$AWS_ACCESS_KEY_ID EBS_SECRETKEY=$AWS_SECRET_ACCESS_KEY" > $BASEDIR/rexray_cmd
echo "Prepare script completed."
