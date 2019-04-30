#!/bin/bash
# Author: William Lam
# Blog: www.virtuallyghetto.com
# Description: Script to import vCenter Server 6.x root certificate to Mac OS X or NIX* system
# Reference: http://www.virtuallyghetto.com/2016/07/automating-the-import-of-vcenter-server-6-x-root-certificate.html

# ensure root user is running the script
if [ "$(id -u)" != "0" ]; then
  echo -e "Please run this script using sudo\n"
  exit 1
fi

# Check for correct number of arguments
if [ ${#} -ne 1 ]; then
  echo -e "Usage: \n\t$0 [VC_HOSTNAME]\n"
  exit 1
fi

NODE_IP=$1

# Automatically determine if OS type is Mac OS X or NIX*
if [ $(uname -s) == "Darwin" ]; then
  OS_TYPE=OSX
fi

# Automatically determine if node is a VC or ESXi endpoint
curl --connect-timeout 10 -k -s "https://${NODE_IP}" | grep 'forAdmins' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    NODE_TYPE=vc
else
    NODE_TYPE=esxi
fi

DOWNLOAD_PATH=/tmp/cert.zip
if [ "${NODE_TYPE}" == "vc" ]; then
    # Install Trusted root CA for vCenter Server for Windows
    echo -e "\nDownloading VC SSL Certificate to ${DOWNLOAD_PATH}"
    curl -k -s "https://${NODE_IP}/certs/download.zip" -o ${DOWNLOAD_PATH}
    unzip ${DOWNLOAD_PATH} -d /tmp > /dev/null 2>&1
    for i in $(ls /tmp/certs/*/*.0);
    do
      SOURCE_CERT=${i%%.*}
      cp "${i}" "/tmp/certs/${SOURCE_CERT##*/}.crt"
      echo "Importing to VC SSL Certificate to Certificate Store"
      if [ "${OS_TYPE}" == "OSX" ]; then
        security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "/tmp/certs/${SOURCE_CERT##*/}.crt"
      else
        cp /tmp/certs/lin/*.0 /usr/local/share/ca-certificates/*.crt
        update-ca-certificates
      fi
    done
elif [ "${NODE_TYPE}" == "esxi" ]; then
  # Install Trusted root CA for ESXi
  echo -n | openssl s_client -showcerts -connect "${NODE_IP}":443 2>/dev/null | openssl x509 > /tmp/certs/esxi_cert.crt
  echo "Importing to VC SSL Certificate to Certificate Store"
  if [ "${OS_TYPE}" == "OSX" ]; then
    security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "/tmp/certs/esxi_cert.crt"
  else
    cp /tmp/esxi_cert.crt /usr/local/share/ca-certificates
    update-ca-certificates
  fi
fi
echo "Cleaning up, delete /tmp/cert.zip"
rm -rf /tmp/cert.zip
echo "Cleaning up, delete /tmp/certs"
rm -rf /tmp/certs
