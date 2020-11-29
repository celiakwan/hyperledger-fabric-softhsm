#!/bin/bash

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function yaml_ccp {
    local PP=$(one_line_pem $4)
    local CP=$(one_line_pem $5)
    sed -e "s/\${ORG}/$1/" \
        -e "s/\${PORT_P0}/$2/" \
        -e "s/\${PORT_CA}/$3/" \
        -e "s#\${PEM_PEER}#$PP#" \
        -e "s#\${PEM_CA}#$CP#" \
        ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

ORG=1
PORT_P0=7051
PORT_CA=7054
PEM_PEER=organizations/peerOrganizations/org1.example.com/tlsca/tlsca.org1.example.com-cert.pem
PEM_CA=organizations/peerOrganizations/org1.example.com/ca/ca.org1.example.com-cert.pem

echo "$(yaml_ccp $ORG $PORT_P0 $PORT_CA $PEM_PEER $PEM_CA)" > organizations/peerOrganizations/org1.example.com/connection-org1.yaml

ORG=2
PORT_P0=9051
PORT_CA=8054
PEM_PEER=organizations/peerOrganizations/org2.example.com/tlsca/tlsca.org2.example.com-cert.pem
PEM_CA=organizations/peerOrganizations/org2.example.com/ca/ca.org2.example.com-cert.pem

echo "$(yaml_ccp $ORG $PORT_P0 $PORT_CA $PEM_PEER $PEM_CA)" > organizations/peerOrganizations/org2.example.com/connection-org2.yaml
