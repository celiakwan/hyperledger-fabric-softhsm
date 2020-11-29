#!/bin/bash

node_ous=""
PKCS11_CONFIG="
BCCSP:
    Default: PKCS11
    PKCS11:
        Library: /usr/lib/softhsm/libsofthsm2.so
        Pin: 12345
        Label: token-fabric
        Hash: SHA2
        Security: 256
        Immutable: false
"
SW_CONFIG="
BCCSP:
    Default: SW
    SW:
        Hash: SHA2
        Security: 256
        FileKeyStore:
            KeyStore: msp/keystore
"

function set_node_ous() {
    node_ous="
NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/localhost-$1.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/localhost-$1.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/localhost-$1.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/localhost-$1.pem
        OrganizationalUnitIdentifier: orderer
"
}

function generate_config_pkcs11() {
    set_node_ous $1
    echo "$node_ous$PKCS11_CONFIG" > $2
}

function generate_config_sw() {
    set_node_ous $1
    echo "$node_ous$SW_CONFIG" > $2
}
