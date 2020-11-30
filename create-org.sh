#!/bin/bash

source generate-config.sh
source docker-exec.sh

FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-cli-server
TLS_CERT=/etc/hyperledger/fabric-ca-server/tls-cert.pem
CA_ORG1=ca_org1
CA_ORG2=ca_org2
CA_ORDERER=ca_orderer
PEM_ORG1=7054-ca-org1
PEM_ORG2=8054-ca-org2
PEM_ORDERER=9054-ca-orderer
ORG1_PATH=organizations/peerOrganizations/org1.example.com
ORG2_PATH=organizations/peerOrganizations/org2.example.com
ORDERER_PATH=organizations/ordererOrganizations/example.com

function create_org1() {
  echo "Enrolling org1 CA admin..."
  fabric_ca_client $CA_ORG1 enroll -u https://admin:adminpw@localhost:7054 --caname ca-org1 --tls.certfiles $TLS_CERT
  generate_config_pkcs11 $PEM_ORG1 $PWD/$ORG1_PATH/msp/config.yaml

  echo "Registering org1 peer0..."
  fabric_ca_client $CA_ORG1 register --caname ca-org1 --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles $TLS_CERT
  echo "Registering org1 user..."
  fabric_ca_client $CA_ORG1 register --caname ca-org1 --id.name user1 --id.secret user1pw --id.type client --tls.certfiles $TLS_CERT
  echo "Registering org1 admin..."
  fabric_ca_client $CA_ORG1 register --caname ca-org1 --id.name org1admin --id.secret org1adminpw --id.type admin --tls.certfiles $TLS_CERT

  mkdir -p $ORG1_PATH/peers/peer0.org1.example.com
  echo "Generating org1 peer0 msp..."
  fabric_ca_client $CA_ORG1 enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-org1 -M $FABRIC_CA_CLIENT_HOME/peers/peer0.org1.example.com/msp --csr.hosts peer0.org1.example.com --tls.certfiles $TLS_CERT
  generate_config_sw $PEM_ORG1 $PWD/$ORG1_PATH/peers/peer0.org1.example.com/msp/config.yaml

  echo "Generating org1 peer0 tls certificates..."
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:7054 --caname ca-org1 -M $PWD/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls --enrollment.profile tls --csr.hosts peer0.org1.example.com --csr.hosts localhost --tls.certfiles $PWD/organizations/fabric-ca/org1/tls-cert.pem
  cp $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/tlscacerts/* $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/ca.crt
  cp $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/signcerts/* $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/server.crt
  cp $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/keystore/* $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/server.key

  mkdir -p $PWD/$ORG1_PATH/msp/tlscacerts
  cp $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/tlscacerts/* $PWD/$ORG1_PATH/msp/tlscacerts/ca.crt
  mkdir -p $PWD/$ORG1_PATH/tlsca
  cp $PWD/$ORG1_PATH/peers/peer0.org1.example.com/tls/tlscacerts/* $PWD/$ORG1_PATH/tlsca/tlsca.org1.example.com-cert.pem
  mkdir -p $PWD/$ORG1_PATH/ca
  cp $PWD/$ORG1_PATH/peers/peer0.org1.example.com/msp/cacerts/* $PWD/$ORG1_PATH/ca/ca.org1.example.com-cert.pem

  mkdir -p $ORG1_PATH/users/User1@org1.example.com
  echo "Generating org1 user msp..."
  fabric_ca_client $CA_ORG1 enroll -u https://user1:user1pw@localhost:7054 --caname ca-org1 -M $FABRIC_CA_CLIENT_HOME/users/User1@org1.example.com/msp --tls.certfiles $TLS_CERT
  cp $PWD/$ORG1_PATH/msp/config.yaml $PWD/$ORG1_PATH/users/User1@org1.example.com/msp/config.yaml

  mkdir -p $ORG1_PATH/users/Admin@org1.example.com
  echo "Generating org1 admin msp..."
  fabric_ca_client $CA_ORG1 enroll -u https://org1admin:org1adminpw@localhost:7054 --caname ca-org1 -M $FABRIC_CA_CLIENT_HOME/users/Admin@org1.example.com/msp --tls.certfiles $TLS_CERT
  cp $PWD/$ORG1_PATH/msp/config.yaml $PWD/$ORG1_PATH/users/Admin@org1.example.com/msp/config.yaml
}

function create_org2() {
  echo "Enrolling org2 CA admin..."
  fabric_ca_client $CA_ORG2 enroll -u https://admin:adminpw@localhost:8054 --caname ca-org2 --tls.certfiles $TLS_CERT
  generate_config_pkcs11 $PEM_ORG2 $PWD/$ORG2_PATH/msp/config.yaml

  echo "Registering org2 peer0..."
  fabric_ca_client $CA_ORG2 register --caname ca-org2 --id.name peer0 --id.secret peer0pw --id.type peer --tls.certfiles $TLS_CERT
  echo "Registering org2 user..."
  fabric_ca_client $CA_ORG2 register --caname ca-org2 --id.name user1 --id.secret user1pw --id.type client --tls.certfiles $TLS_CERT
  echo "Registering org2 admin..."
  fabric_ca_client $CA_ORG2 register --caname ca-org2 --id.name org2admin --id.secret org2adminpw --id.type admin --tls.certfiles $TLS_CERT

  mkdir -p $ORG2_PATH/peers/peer0.org2.example.com
  echo "Generating org2 peer0 msp..."
  fabric_ca_client $CA_ORG2 enroll -u https://peer0:peer0pw@localhost:8054 --caname ca-org2 -M $FABRIC_CA_CLIENT_HOME/peers/peer0.org2.example.com/msp --csr.hosts peer0.org2.example.com --tls.certfiles $TLS_CERT
  generate_config_sw $PEM_ORG2 $PWD/$ORG2_PATH/peers/peer0.org2.example.com/msp/config.yaml

  echo "Generating org2 peer0 tls certificates..."
  fabric-ca-client enroll -u https://peer0:peer0pw@localhost:8054 --caname ca-org2 -M $PWD/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls --enrollment.profile tls --csr.hosts peer0.org2.example.com --csr.hosts localhost --tls.certfiles $PWD/organizations/fabric-ca/org2/tls-cert.pem
  cp $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/tlscacerts/* $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/ca.crt
  cp $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/signcerts/* $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/server.crt
  cp $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/keystore/* $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/server.key

  mkdir -p $PWD/$ORG2_PATH/msp/tlscacerts
  cp $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/tlscacerts/* $PWD/$ORG2_PATH/msp/tlscacerts/ca.crt
  mkdir -p $PWD/$ORG2_PATH/tlsca
  cp $PWD/$ORG2_PATH/peers/peer0.org2.example.com/tls/tlscacerts/* $PWD/$ORG2_PATH/tlsca/tlsca.org2.example.com-cert.pem
  mkdir -p $PWD/$ORG2_PATH/ca
  cp $PWD/$ORG2_PATH/peers/peer0.org2.example.com/msp/cacerts/* $PWD/$ORG2_PATH/ca/ca.org2.example.com-cert.pem

  mkdir -p $ORG2_PATH/users/User1@org2.example.com
  echo "Generating org2 user msp..."
  fabric_ca_client $CA_ORG2 enroll -u https://user1:user1pw@localhost:8054 --caname ca-org2 -M $FABRIC_CA_CLIENT_HOME/users/User1@org2.example.com/msp --tls.certfiles $TLS_CERT
  cp $PWD/$ORG2_PATH/msp/config.yaml $PWD/$ORG2_PATH/users/User1@org2.example.com/msp/config.yaml

  mkdir -p $ORG2_PATH/users/Admin@org2.example.com
  echo "Generating org2 admin msp..."
  fabric_ca_client $CA_ORG2 enroll -u https://org2admin:org2adminpw@localhost:8054 --caname ca-org2 -M $FABRIC_CA_CLIENT_HOME/users/Admin@org2.example.com/msp --tls.certfiles $TLS_CERT
  cp $PWD/$ORG2_PATH/msp/config.yaml $PWD/$ORG2_PATH/users/Admin@org2.example.com/msp/config.yaml
}

function create_orderer() {
  echo "Enrolling orderer CA admin..."
  fabric_ca_client $CA_ORDERER enroll -u https://admin:adminpw@localhost:9054 --caname ca-orderer --tls.certfiles $TLS_CERT
  generate_config_pkcs11 $PEM_ORDERER $PWD/$ORDERER_PATH/msp/config.yaml

  echo "Registering orderer..."
  fabric_ca_client $CA_ORDERER register --caname ca-orderer --id.name orderer --id.secret ordererpw --id.type orderer --tls.certfiles $TLS_CERT
  echo "Registering orderer admin..."
  fabric_ca_client $CA_ORDERER register --caname ca-orderer --id.name ordererAdmin --id.secret ordererAdminpw --id.type admin --tls.certfiles $TLS_CERT

  mkdir -p $ORDERER_PATH/orderers/orderer.example.com
  echo "Generating orderer msp..."
  fabric_ca_client $CA_ORDERER enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M $FABRIC_CA_CLIENT_HOME/orderers/orderer.example.com/msp --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles $TLS_CERT
  generate_config_sw $PEM_ORDERER $PWD/$ORDERER_PATH/orderers/orderer.example.com/msp/config.yaml

  echo "Generating orderer tls certificates..."
  fabric-ca-client enroll -u https://orderer:ordererpw@localhost:9054 --caname ca-orderer -M $PWD/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls --enrollment.profile tls --csr.hosts orderer.example.com --csr.hosts localhost --tls.certfiles $PWD/organizations/fabric-ca/ordererOrg/tls-cert.pem
  cp $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/tlscacerts/* $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/ca.crt
  cp $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/signcerts/* $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/server.crt
  cp $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/keystore/* $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/server.key

  mkdir -p $PWD/$ORDERER_PATH/orderers/orderer.example.com/msp/tlscacerts
  cp $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/tlscacerts/* $PWD/$ORDERER_PATH/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
  mkdir -p $PWD/$ORDERER_PATH/msp/tlscacerts
  cp $PWD/$ORDERER_PATH/orderers/orderer.example.com/tls/tlscacerts/* $PWD/$ORDERER_PATH/msp/tlscacerts/tlsca.example.com-cert.pem

  mkdir -p $ORDERER_PATH/users/Admin@example.com
  echo "Generating orderer admin msp..."
  fabric_ca_client $CA_ORDERER enroll -u https://ordererAdmin:ordererAdminpw@localhost:9054 --caname ca-orderer -M $FABRIC_CA_CLIENT_HOME/users/Admin@example.com/msp --tls.certfiles $TLS_CERT
  cp $PWD/$ORDERER_PATH/msp/config.yaml $PWD/$ORDERER_PATH/users/Admin@example.com/msp/config.yaml
}
