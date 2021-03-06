#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2015

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - TLS certificate Common Name - required
# 2 - JKS store password - required
# 3 - JKS key password (should be the same as JKS store password) - required
# 4 - Extra parameters for keytool (ie Subject Alternative Name (SAN)) - optional

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
#"CN=cmhost.sec.cloudera.com,OU=Support,O=Cloudera,L=Denver,ST=Colorado,C=US"
DN="$1"
SP="$2"
#KP="$3"
KP="$SP"
#"SAN=DNS:`hostname`,DNS:my-lb.domain.com"
EXT="$4"
if [ -z "$DN" ]; then
  echo "ERROR: Missing distinguished name."
  exit 1
fi
if [ -z "$SP" ]; then
  echo "ERROR: Missing keystore password."
  exit 2
fi
if [ -z "$KP" ]; then
  echo "ERROR: Missing private key password."
  exit 3
fi
if [ -n "$EXT" ]; then
  EXT="-ext $EXT"
fi

echo "Generating TLS CSR..."
if [ -f /etc/profile.d/jdk.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/java.sh
fi

if [ -d /etc/hortonworks ]; then
  _TYPE=hortonworks
  _DIR=/etc/hortonworks
elif [ -d /opt/cloudera ]; then
  _TYPE=cloudera
  _DIR=/opt/cloudera
else
  echo "ERROR: Cannot determine if this is Cloudera or Hortonworks."
  exit 11
fi

if [ -f "${_DIR}/security/jks/localhost-keystore.jks" ]; then
  echo "ERROR: Keystore already exists.  Exiting..."
  exit 4
fi
# Generate a private RSA key and store it in JKS (localhost-keystore.jks) with the distinguished name "$DN".
keytool -genkeypair -alias localhost -keyalg RSA -sigalg SHA256withRSA \
 -keystore "${_DIR}/security/jks/localhost-keystore.jks" \
 -keysize 2048 -dname "$DN" -storepass "$SP" -keypass "$KP"
chmod 0440 "${_DIR}/security/jks/localhost-keystore.jks"
if [ "$_TYPE" == cloudera ]; then
  chown root:cloudera-scm "${_DIR}/security/jks/localhost-keystore.jks"
else
  chown root:root "${_DIR}/security/jks/localhost-keystore.jks"
fi

if [ -f "${_DIR}/security/x509/localhost.csr" ]; then
  echo "ERROR: CSR already exists.  Exiting..."
  exit 5
fi
# https://www.cloudera.com/documentation/enterprise/5-9-x/topics/cm_sg_create_deploy_certs.html#concept_frd_1px_nw
# X509v3 Extended Key Usage:
#   TLS Web Server Authentication, TLS Web Client Authentication
# Generate a CSR (localhost.csr) from the JKS (localhost-keystore.jks).
# shellcheck disable=SC2086
keytool -certreq -alias localhost \
 -keystore "${_DIR}/security/jks/localhost-keystore.jks" \
 -file "${_DIR}/security/x509/localhost.csr" -storepass "$SP" \
 -keypass "$KP" -ext EKU=serverAuth,clientAuth -ext KU=digitalSignature,keyEncipherment $EXT
chmod 0444 "${_DIR}/security/x509/localhost.csr"

rm -f /tmp/localhost-keystore.p12.$$
# Convert the proprietary JKS (localhost-keystore.jks) to PKCS12 (localhost-keystore.p12) format.
keytool -importkeystore -srckeystore "${_DIR}/security/jks/localhost-keystore.jks" \
 -srcstorepass "$SP" -srckeypass "$KP" -destkeystore /tmp/localhost-keystore.p12.$$ \
 -deststoretype PKCS12 -srcalias localhost -deststorepass "$SP" -destkeypass "$KP"
if [ -f "${_DIR}/security/x509/localhost.e.key" ]; then
  echo "ERROR: Encrypted Key already exists.  Exiting..."
  rm -f /tmp/localhost-keystore.p12.$$
  exit 6
fi
# Extract the PEM encoded private key (localhost.e.key) from the PKCS12 (localhost-keystore.p12) file.
# The private key (localhost.e.key) will still be in encrypted form.
openssl pkcs12 -in /tmp/localhost-keystore.p12.$$ -passin "pass:$KP" -nocerts \
 -out "${_DIR}/security/x509/localhost.e.key" -passout "pass:$KP"
chmod 0400 "${_DIR}/security/x509/localhost.e.key"
rm -f /tmp/localhost-keystore.p12.$$

if [ -f "${_DIR}/security/x509/localhost.key" ]; then
  echo "ERROR: Key already exists.  Exiting..."
  exit 7
fi
# Extract the unencrypted PEM encoded private key (localhost.key) from encrypted private key (localhost.e.key).
openssl rsa -in "${_DIR}/security/x509/localhost.e.key" \
 -passin "pass:$KP" -out "${_DIR}/security/x509/localhost.key"
chmod 0400 "${_DIR}/security/x509/localhost.key"

if [ "$_TYPE" == cloudera ]; then
  if [ -f /etc/cloudera-scm-agent/agentkey.pw ]; then
    echo "ERROR: Agent PW already exists.  Exiting..."
    exit 8
  fi
  install -o root -g root -m 0755 -d /etc/cloudera-scm-agent
  install -o root -g root -m 0600 /dev/null /etc/cloudera-scm-agent/agentkey.pw
  echo "$SP" >/etc/cloudera-scm-agent/agentkey.pw
fi

