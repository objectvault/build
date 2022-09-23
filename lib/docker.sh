#!/usr/bin/env bash

# Docker Utility Functions
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

build_docker_image() {
  # PARAM $1 - Local Image Source Path
  # PARAM $2 - Docker Image Tag

  # PATH for Image SRC
  IMAGEPATH="${BUILDDIR}/$1"

  # Build Docker Image
  docker build --tag "$2" "${IMAGEPATH}/."
}

## Status Check
status() {
  # PARAM $1 - type of object volume | container | network
  # PARAM $2 - name of object
  # RETURNS
  # 0 - Object Does not Exist
  # 1 - Object Exists

  # Does Docker Object Exist?
  local s="$(docker $1 ls -f name=$2 -q 2> /dev/null)"
  if [ "$s" == "" ]; then # NO
    return 0
  fi
  # ELSE: YES
  return 1
}

## Remove Docker Network
network_rm() {
  # PARAM $1 - Network Name
  NETWORK=$1

  # Does Network Exists?
  status network "${NETWORK}"
  if [[ $? == 1 ]]; then # YES
    # Remove Existing Networks
    echo "Removing Network '$NETWORK'"
    docker network rm "${NETWORK}"
  fi
}

## Remove ALL Docker Networks for Application
networks_rm() {
  for network in $(echo $NETWORKS | tr "," " "); do \
    network_rm "${network}"
  done
}

## Create Docker Network
network_create() {
  # PARAM $1 - Network Name
  NETWORK=$1

  # Does Network Exists?
  status network "${NETWORK}"
  if [[ $? == 0 ]]; then # NO

    if [ "${NETWORK}" -eq ${NET_BACKEND} ]; then
      # Internal Only Networks
      ARGS="--internal ${NETWORK}"
    else # Normal Network
      ARGS="${NETWORK}"
    fi

    # Create
    echo "Creating Network '$NETWORK'"
    docker network create ${ARGS}
  fi
}

## Remove ALL Docker Networks for Application
networks_create() {
  for network in $(echo $NETWORKS | tr "," " "); do \
    network_create "${network}"
  done
}

## Attach Docker Container to Network
connect_container() {
  # PARAM $1 - Network Name
  # PARAM $2 - Container Name
  # PARAM $3 - DNS Alias for Container
  NETWORK=$1
  CONTAINER=$2
  ALIAS=$3

  # is ALIAS Set?
  if [ "${ALIAS}" == "" ]; then # NO: User Container Name as Alias
    ALIAS="${CONTAINER}"
  fi

  # Attach Container to Network
  docker network connect --alias "${ALIAS}" "${NETWORK}" "${CONTAINER}"
  echo "Connecting [${CONTAINER}] to Network [${NETWORK}] as [${ALIAS}]"
}

## Create Docker Volume
volume_create() {
  # PARAM $1 - Volume Name

  # Does Volume Exists?
  status volume "$1"
  if [[ $? == 0 ]]; then # NO
    echo "Creating Volume '$1'"
    docker volume create $1
  else
    echo "WARN: Volume '$1' Already Exists"
  fi
}

## Delete Docker Volume
volume_rm() {
  # PARAM $1 - Volume Name

  # Does Volume Exists?
  status volume "$1"
  if [[ $? != 0 ]]; then # YES
    echo "Removing Volume '$1'"
    docker volume rm $1
  else
    echo "INFO: Volume '$1' Does not exist"
  fi
}

## See Container Logs
logs_container() {
  # PARAM $1 - Container Name

  ## NOTE: Don't Test for Container Running in the case we wan't to see problems
  ## with stopped containers
  echo "Logging container '$1'"
  docker logs -f "$1"
}

## Stop Container
stop_container() {
  # PARAM $1 - Container Name

  # Is Container Running?
  status container "$1"
  if [[ $? == 1 ]]; then # YES
    echo "Stopping container '$1'"
    docker stop "$1"
  else # NO
    echo "Container '$1' NOT Running"
  fi
}
