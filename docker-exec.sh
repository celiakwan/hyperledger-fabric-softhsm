#!/bin/bash

function fabric_ca_client() {
  docker exec $1 fabric-ca-client ${@:2}
}

function fabric_peer() {
  docker exec $1 peer ${@:2}
}