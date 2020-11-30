# hyperledger-fabric-softhsm
An integration of Hyperledger Fabric and SoftHSM implementing PKCS11 standard for key management. This guide demonstrates how to configure TLS-enabled CA servers, CA clients, peer and ordering nodes, and how to deploy the nodes using Docker Compose. It also covers some potential errors and troubleshooting.

### Version
- [Hyperledger Fabric](https://hyperledger-fabric.readthedocs.io/): 2.x
- Hyperledger Fabric repositories
    - [Hyperledger Fabric CA](https://github.com/hyperledger/fabric-ca): 1.4.9
    - [Hyperledger Fabric](https://github.com/hyperledger/fabric): 2.3.0
    - [Hyperledger Fabric Samples](https://github.com/hyperledger/fabric-samples): 1.4.4
- [Docker Compose](https://docs.docker.com/compose/): 1.27.4
- [SoftHSM](https://www.opendnssec.org/softhsm/): 2.6.1

### Installation
Install Docker.
Download from https://docs.docker.com/get-docker/.

Install SoftHSM.
```
brew install softhsm
```

### SoftHSM
1. The first thing we need is a SoftHSM config file `softhsm2.conf` like this.
    ```
    # SoftHSM v2 configuration file

    directories.tokendir = /Users/celia/path/to/hyperledger-fabric-softhsm/softhsm/tokens
    objectstore.backend = file

    # ERROR, WARNING, INFO, DEBUG
    log.level = ERROR

    # If CKF_REMOVABLE_DEVICE flag should be set
    slots.removable = false

    # Enable and disable PKCS#11 mechanisms using slots.mechanisms.
    slots.mechanisms = ALL

    # If the library should reset the state on fork
    library.reset_on_fork = false
    ```
    
    `directories.tokendir` is the location to store tokens that the nodes will interact with. For demonstration, we set it to `/softhsm/tokens` in the project directory.

    &nbsp;
    Note: The existing `softhsm2.conf` located at `/softhsm` is the config file that will be used by Docker Compose. We should create a new `softhsm2.conf` instead of using it.
    &nbsp;

2. Set the environment variable `SOFTHSM2_CONF`.
    ```
    export SOFTHSM2_CONF=/Users/celia/path/to/softhsm2.conf
    ```

3. Initialize a token. The token lable used in this project is `token-fabric`.
    ```
    softhsm2-util --init-token --slot 0 --label token-fabric
    ```

Useful commands:
- To check the slot list or token info.
    ```
    softhsm2-util --show-slots
    ```

    Note: The initialized tokens will be reassigned to other slots. A new uninitialized token will be added automatically. Therefore you will see one extra slot here.
    &nbsp;

- To delete the token.
    ```
    softhsm2-util --delete-token --token token-fabric
    ```

### Hyperledger Fabric
##### Docker Images
###### Fabric CA
1. Clone the Hyperledger Fabric CA repository.
    ```
    git clone https://github.com/hyperledger/fabric-ca.git
    ```

2. Change current directory to `/fabric-ca`.
    &nbsp;

    Since PKCS11 is not enabled in the prebuilt Hyperledger Fabric Docker images, we need to build our own images that support PKCS11. Before building the images, we may need to modify the `Dockerfile` of Fabric CA.
    ```
    vim images/fabric-ca/Dockerfile
    ```

    Change these lines
    ```
    RUN apk add --no-cache \
	tzdata;
    ```
    to
    ```
    RUN apk add --no-cache \
	tzdata \
	softhsm;
    ```

    Jump down to [Troubleshooting](#troubleshooting) to understand the reason behind.
    &nbsp;

3. Build the Fabric CA image.
    ```
    make docker GO_TAGS=pkcs11
    ```

###### Fabric Peer and Orderer
1. Clone the Hyperledger Fabric repository.
    ```
    git clone https://github.com/hyperledger/fabric.git
    ```

2. Change current directory to `/fabric` and modify the `Dockerfile` of orderer.
    ```
    vim images/orderer/Dockerfile
    ```

    Change this line
    ```
    RUN apk add --no-cache tzdata
    ```
    to
    ```
    RUN apk add --no-cache tzdata softhsm
    ```

3. Modify the `Dockerfile` of peer.
    ```
    vim images/peer/Dockerfile
    ```

    Change this line
    ```
    RUN apk add --no-cache tzdata
    ```
    to
    ```
    RUN apk add --no-cache tzdata softhsm
    ```

4. Build the Fabric images.
    ```
    make docker GO_TAGS=pkcs11
    ```

##### Docker Compose Files
###### Fabric CA
- The Docker Compose file of a peer's CA is like this.
    ```
    ca_org1:
    image: hyperledger/fabric-ca:latest
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-org1
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_PORT=7054
      - FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-cli-server
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm2.conf
    ports:
      - "7054:7054"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ../organizations/fabric-ca/org1:/etc/hyperledger/fabric-ca-server
      - ../organizations/peerOrganizations/org1.example.com:/etc/hyperledger/fabric-ca-cli-server
      - ../softhsm/softhsm2.conf:/etc/hyperledger/fabric/softhsm2.conf
      - ../softhsm/tokens:/etc/hyperledger/fabric/softhsm/tokens
    container_name: ca_org1
    networks:
      - test
    ```

- The Docker Compose file of an orderer's CA is like this.
    ```
    ca_orderer:
    image: hyperledger/fabric-ca:latest
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-orderer
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_PORT=9054
      - FABRIC_CA_CLIENT_HOME=/etc/hyperledger/fabric-ca-cli-server
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm2.conf
    ports:
      - "9054:9054"
    command: sh -c 'fabric-ca-server start -b admin:adminpw -d'
    volumes:
      - ../organizations/fabric-ca/ordererOrg:/etc/hyperledger/fabric-ca-server
      - ../organizations/ordererOrganizations/example.com:/etc/hyperledger/fabric-ca-cli-server
      - ../softhsm/softhsm2.conf:/etc/hyperledger/fabric/softhsm2.conf
      - ../softhsm/tokens:/etc/hyperledger/fabric/softhsm/tokens
    container_name: ca_orderer
    networks:
      - test
    ```

###### Fabric Peer and Orderer
- The Docker Compose file of a peer is like this.
    ```
    peer0.org1.example.com:
    container_name: peer0.org1.example.com
    image: hyperledger/fabric-peer:latest
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_test
      - FABRIC_LOGGING_SPEC=INFO
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      - CORE_PEER_ID=peer0.org1.example.com
      - CORE_PEER_ADDRESS=peer0.org1.example.com:7051
      - CORE_PEER_LISTENADDRESS=0.0.0.0:7051
      - CORE_PEER_CHAINCODEADDRESS=peer0.org1.example.com:7052
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_BOOTSTRAP=peer0.org1.example.com:7051
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer0.org1.example.com:7051
      - CORE_PEER_LOCALMSPID=Org1MSP
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm2.conf
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/admin-msp
    volumes:
        - /var/run/:/host/var/run/
        - ../organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/msp:/etc/hyperledger/fabric/msp
        - ../organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls:/etc/hyperledger/fabric/tls
        - peer0.org1.example.com:/var/hyperledger/production
        - ../softhsm/softhsm2.conf:/etc/hyperledger/fabric/softhsm2.conf
        - ../softhsm/tokens:/etc/hyperledger/fabric/softhsm/tokens
        - ../config/org1-msp/core.yaml:/etc/hyperledger/fabric/core.yaml
        - ../channel-artifacts:/var/hyperledger/channel-artifacts
        - ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem:/var/hyperledger/orderer-ca.pem
        - ../organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp:/etc/hyperledger/fabric/admin-msp
        - ../package:/var/hyperledger/package
        - ../organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt:/etc/hyperledger/fabric/tls-org2/ca.crt
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - 7051:7051
    networks:
      - test
    ```

- The Docker Compose file of an orderer is like this.
    ```
    orderer.example.com:
    container_name: orderer.example.com
    image: hyperledger/fabric-orderer:latest
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=7050
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
      - ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1
      - ORDERER_KAFKA_VERBOSE=true
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
      - SOFTHSM2_CONF=/etc/hyperledger/fabric/softhsm2.conf
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: orderer
    volumes:
        - ../system-genesis-block/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp:/var/hyperledger/orderer/msp
        - ../organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/:/var/hyperledger/orderer/tls
        - orderer.example.com:/var/hyperledger/production/orderer
        - ../softhsm/softhsm2.conf:/etc/hyperledger/fabric/softhsm2.conf
        - ../softhsm/tokens:/etc/hyperledger/fabric/softhsm/tokens
        - ../config/orderer.yaml:/etc/hyperledger/fabric/orderer.yaml
    ports:
      - 7050:7050
    networks:
      - test
    ```

##### Hyperledger Fabric Config Files
###### Fabric CA Server
Replace the `bccsp` section in `fabric-ca-server-config.yaml` with the following for peer and orderer's CAs.
```
bccsp:
    default: PKCS11
    pkcs11:
        library: /usr/lib/softhsm/libsofthsm2.so
        pin: 12345
        label: token-fabric
        hash: SHA2
        security: 256
        immutable: false
```

###### Fabric CA Client
Replace the `bccsp` section in `fabric-ca-client-config.yaml` with the following for peer and orderer's CA clients.
```
bccsp:
    default: PKCS11
    pkcs11:
        library: /usr/lib/softhsm/libsofthsm2.so
        pin: 12345
        label: token-fabric
        hash: SHA2
        security: 256
        immutable: false
```

###### Fabric Peer and Orderer
- `generate-config.sh` will help generate the config files for peers and orderer. The `bccsp` section in the generated config files look like this.
    ```
    BCCSP:
        Default: PKCS11
        PKCS11:
            Library: /usr/lib/softhsm/libsofthsm2.so
            Pin: 12345
            Label: token-fabric
            Hash: SHA2
            Security: 256
            Immutable: false
    ```

    Note: As of now, Hyperledger Fabric does not support HSM integration for TLS. The TLS private keys will still be stored in `keystore`. The `bccsp` section should remain the default `SW` configuration and this will be handled by `generate-config.sh` as well.
    ```
    BCCSP:
        Default: SW
        SW:
            Hash: SHA2
            Security: 256
            FileKeyStore:
                KeyStore: msp/keystore
    ```

- Replace the `bccsp` section in `core.yaml` with the following for each peer.
    ```
    bccsp:
        default: PKCS11
        pkcs11:
            library: /usr/lib/softhsm/libsofthsm2.so
            pin: 12345
            label: token-fabric
            hash: SHA2
            security: 256
            immutable: false
    ```

- Replace the `bccsp` section in `orderer.yaml` with the following for orderer.
    ```
    BCCSP:
        Default: PKCS11
        PKCS11:
            Library: /usr/lib/softhsm/libsofthsm2.so
            Pin: 12345
            Label: token-fabric
            Hash: SHA2
            Security: 256
            Immutable: false
    ```

##### Hyperledger Fabric Binaries
The binaries in `/bin` is retrieved from the Hyperledger Fabric samples repository.
```
git clone https://github.com/hyperledger/fabric-samples.git
```

Note: These binaries are not supported for PKCS11 and are only executed for operations that do not require PKCS11. In order to execute operations that need PKCS11 such as `fabric-ca-client enroll`, we should execute through Docker like `docker exec peer0.org1.example.com fabric-ca-client enroll`.

### Deployment
`network.sh` provides a menu with a list of options to help us deploy the nodes automatically and let us play around with the chaincode.
```
./network.sh
Please select:
1) Up				   6) Invoke_chaincode_deliver
2) Deploy_chaincode		   7) Invoke_chaincode_getAllRecords
3) Invoke_chaincode_initLedger	   8) Down
4) Invoke_chaincode_order	   9) Clean_tokens
5) Invoke_chaincode_ship
```

### Troubleshooting
- `Error: Failed to get BCCSP with opts: Could not find BCCSP, no 'PKCS11' provider`
&nbsp;

    This error means the binaries or Docker images do not support PKCS11. We need to build our own binaries or Docker images with `GO_TAGS=pkcs11`.
&nbsp;

- `Error: Failed to get BCCSP with opts: Could not initialize BCCSP PKCS11: Failed initializing PKCS11 library /etc/hyperledger/fabric/libsofthsm2.so token-fabric: Instantiate failed [/etc/hyperledger/fabric/libsofthsm2.so]`
&nbsp;

    Even the `libsofthsm2.so` has been mounted to Docker containers, it still threw an error saying the `libsofthsm2.so` could not be initialized. Since the Docker images of Hyperledger Fabric 2.x are using Alpine Linux, it could potentially miss some dependencies to run SoftHSM. The workaround is to install SoftHSM on the containers so that all dependencies for SoftHSM can be resolved.