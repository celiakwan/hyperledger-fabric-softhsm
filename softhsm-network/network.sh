#!/bin/bash

source ./create-org.sh
source ./docker-exec.sh

export PATH=$PWD/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/config

function set_peer_params() {
  for i in ${!ORG_MSP[@]}
  do
    local org=$(($i+1))
    local peer_address=$(eval echo "--peerAddresses \$CORE_PEER_ADDRESS$org")
    local tls_cert=$(eval echo "--tlsRootCertFiles \$PEER0_ORG${org}_CA")
    peer_params="$peer_params $peer_address $tls_cert"
  done
}

function invoke_chaincode() {
  set_peer_params
  fabric_peer ${PEER_ORG[0]} chaincode invoke -o $ORDERER_ADDR --ordererTLSHostnameOverride $ORDERER_ORG --tls --cafile $ORDERER_CA -C $CHANNEL_ID -n $CC_NAME $peer_params -c $1
}

function invoke_chaincode_get_all() {
  fabric_peer ${PEER_ORG[0]} chaincode query -C $CHANNEL_ID -n $CC_NAME -c '{"Args":["getAllRecords"]}'
}

function invoke_chaincode_deliver() {
  read -p "Enter key: " key
  invoke_chaincode '{"function":"deliver","Args":["'$key'"]}'
}

function invoke_chaincode_ship() {
  read -p "Enter key: " key
  invoke_chaincode '{"function":"ship","Args":["'$key'"]}'
}

function invoke_chaincode_order() {
  read -p "Enter origin: " origin
  read -p "Enter destination: " destination

  local id=$(uuidgen)
  local key=ship-$id
  echo "Key: $key"

  invoke_chaincode '{"function":"order","Args":["'$key'","'$id'","'$origin'","'$destination'"]}'
}

function invoke_chaincode_init() {
  invoke_chaincode '{"function":"initLedger","Args":[]}'
}

function deploy_chaincode() {
  export FABRIC_CFG_PATH=$PWD/config/org1-msp

  peer lifecycle chaincode package package/$CC_NAME.tar.gz --path $CHAINCODE_PATH --lang $LANG --label ${CC_NAME}_$CC_VERSION
  
  local package_id=""
  for i in ${!ORG_MSP[@]}
  do
    fabric_peer ${PEER_ORG[$i]} lifecycle chaincode install $PACKAGE_PATH/$CC_NAME.tar.gz

    if [ -z $package_id ]
    then
      package_id=$(echo $(fabric_peer ${PEER_ORG[$i]} lifecycle chaincode queryinstalled) | sed -e "s/.*Package ID: \(.*\), Label.*/\1/")
    fi

    fabric_peer ${PEER_ORG[$i]} lifecycle chaincode approveformyorg -o $ORDERER_ADDR --channelID $CHANNEL_ID --ordererTLSHostnameOverride $ORDERER_ORG --tls --cafile $ORDERER_CA --name $CC_NAME --version $CC_VERSION --package-id $package_id --sequence $CC_SEQUENCE

    # checkcommitreadiness is optional
    sleep 3
    local commit_readiness=$(fabric_peer ${PEER_ORG[$i]} lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_ID --name $CC_NAME --version $CC_VERSION --sequence $CC_SEQUENCE --output json)
    echo "$commit_readiness"
  done

  set_peer_params
  fabric_peer ${PEER_ORG[0]} lifecycle chaincode commit -o $ORDERER_ADDR --channelID $CHANNEL_ID --ordererTLSHostnameOverride $ORDERER_ORG --tls --cafile $ORDERER_CA --name $CC_NAME $peer_params --version $CC_VERSION --sequence $CC_SEQUENCE
  
  # querycommitted is optional
  sleep 3
  for i in ${!ORG_MSP[@]}
  do
    fabric_peer ${PEER_ORG[$i]} lifecycle chaincode querycommitted --channelID $CHANNEL_ID --name $CC_NAME
  done
}

function create_channel() {
  configtxgen -profile $CHANNEL_PROFILE -channelID $CHANNEL_ID -outputCreateChannelTx ./channel-artifacts/$CHANNEL_ID.tx

  for i in ${ORG_MSP[@]}
  do
    configtxgen -profile $CHANNEL_PROFILE -channelID $CHANNEL_ID -outputAnchorPeersUpdate ./channel-artifacts/$i-anchors.tx -asOrg $i
  done

  export FABRIC_CFG_PATH=$PWD/config/org1-msp
  
  sleep 3
  fabric_peer ${PEER_ORG[0]} channel create -o $ORDERER_ADDR -c $CHANNEL_ID --ordererTLSHostnameOverride $ORDERER_ORG -f $CHANNEL_ARTIFACTS_PATH/$CHANNEL_ID.tx --outputBlock $CHANNEL_ARTIFACTS_PATH/$CHANNEL_ID.block --tls --cafile $ORDERER_CA
  
  for i in ${!PEER_ORG[@]}
  do
    sleep 3
    fabric_peer ${PEER_ORG[$i]} channel join -b $CHANNEL_ARTIFACTS_PATH/$CHANNEL_ID.block
    sleep 3
    fabric_peer ${PEER_ORG[$i]} channel update -o $ORDERER_ADDR -c $CHANNEL_ID --ordererTLSHostnameOverride $ORDERER_ORG -f $CHANNEL_ARTIFACTS_PATH/${ORG_MSP[$i]}-anchors.tx --tls --cafile $ORDERER_CA
  done
}

function check_tls_cert() {
  local count=0
  while [ $count -lt 12 ]
  do
    if [ ! -f "$FABRIC_CA_PATH/org1/tls-cert.pem" ] || [ ! -f "$FABRIC_CA_PATH/org2/tls-cert.pem" ] || [ ! -f "$FABRIC_CA_PATH/ordererOrg/tls-cert.pem" ]
    then
      sleep 5
    else
      break
    fi
    ((count++))
  done
}

function clean() {
  echo "Cleaning artifacts..."

  rm -rf system-genesis-block/*.block channel-artifacts/* package/*

  for i in ${!ORG_MSP[@]}
  do
    local org=$(($i+1))
    find $FABRIC_CA_PATH/org$org -mindepth 1 ! -name fabric-ca-server-config.yaml -delete
    find $PEER_ORG_PATH/org$org.example.com -mindepth 1 ! -name fabric-ca-client-config.yaml -delete
  done
  find $FABRIC_CA_PATH/ordererOrg -mindepth 1 ! -name fabric-ca-server-config.yaml -delete
  find $ORDERER_ORG_PATH/example.com -mindepth 1 ! -name fabric-ca-client-config.yaml -delete
}

function network_up() {
  clean

  echo "Generating certificates..."

  docker-compose -f $COMPOSE_FILE_CA up -d

  check_tls_cert
  create_org1
  create_org2
  create_orderer
  ./generate-ccp.sh
  configtxgen -profile OrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block

  docker-compose -f $COMPOSE_FILE_BASE up -d

  create_channel
  
  sleep 2
  docker ps -a
}

function network_down() {
  echo "Stopping network..."

  docker-compose -f $COMPOSE_FILE_BASE -f $COMPOSE_FILE_CA down --volumes --remove-orphans
}

function clean_tokens() {
  echo "Cleaning tokens..."

  rm -f softhsm/tokens/*/*-*-*-*.lock softhsm/tokens/*/*-*-*-*.object
}

ORG_MSP=(
  Org1MSP
  Org2MSP
)
PEER_ORG=(
  peer0.org1.example.com
  peer0.org2.example.com
)
FABRIC_CA_PATH=organizations/fabric-ca
PEER_ORG_PATH=organizations/peerOrganizations
ORDERER_ORG_PATH=organizations/ordererOrganizations
CHANNEL_ARTIFACTS_PATH=/var/hyperledger/channel-artifacts
CHAINCODE_PATH=../chaincode/hyperledger-fabric-shipment
PACKAGE_PATH=/var/hyperledger/package
LANG=java
COMPOSE_FILE_CA=docker/docker-compose-ca.yaml
COMPOSE_FILE_BASE=docker/docker-compose-base.yaml
ORDERER_CA=/var/hyperledger/orderer-ca.pem
ORDERER_ORG=orderer.example.com
ORDERER_ADDR=orderer.example.com:7050
CHANNEL_PROFILE=ChannelOrg1Org2
CHANNEL_ID=channel-org1-org2
CC_NAME=hyperledger-fabric-shipment
CC_VERSION=1.0
CC_SEQUENCE=1
CORE_PEER_ADDRESS1=peer0.org1.example.com:7051
CORE_PEER_ADDRESS2=peer0.org2.example.com:9051
PEER0_ORG1_CA=/etc/hyperledger/fabric/tls/ca.crt
PEER0_ORG2_CA=/etc/hyperledger/fabric/tls-org2/ca.crt

peer_params=""

UP=Up
DEPLOY_CC=Deploy_chaincode
INVOKE_CC_INIT=Invoke_chaincode_initLedger
INVOKE_CC_ORDER=Invoke_chaincode_order
INVOKE_CC_SHIP=Invoke_chaincode_ship
INVOKE_CC_DELIVER=Invoke_chaincode_deliver
INVOKE_CC_GET_ALL=Invoke_chaincode_getAllRecords
DOWN=Down
CLEAN_TOKENS=Clean_tokens
OPTIONS=(
  $UP
  $DEPLOY_CC
  $INVOKE_CC_INIT
  $INVOKE_CC_ORDER
  $INVOKE_CC_SHIP
  $INVOKE_CC_DELIVER
  $INVOKE_CC_GET_ALL
  $DOWN
  $CLEAN_TOKENS
)

echo "Please select:"
select opt in ${OPTIONS[@]}
do 
  case $opt in
    $UP)
      network_up
      break
      ;;
    $DEPLOY_CC)
      deploy_chaincode
      break
      ;;
    $INVOKE_CC_INIT)
      invoke_chaincode_init
      break
      ;;
    $INVOKE_CC_ORDER)
      invoke_chaincode_order
      break
      ;;
    $INVOKE_CC_SHIP)
      invoke_chaincode_ship
      break
      ;;
    $INVOKE_CC_DELIVER)
      invoke_chaincode_deliver
      break
      ;;
    $INVOKE_CC_GET_ALL)
      invoke_chaincode_get_all
      break
      ;;
    $DOWN)
      network_down
      break
      ;;
    $CLEAN_TOKENS)
      clean_tokens
      break
      ;;
  esac
done
