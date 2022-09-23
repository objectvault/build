#!/usr/bin/env bash

# Backend API Server Container Commands
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

## Build Docker Image for API Server
build_api() {
  REPO="api-services"
  VERSION="v0.0.1"
  IMAGE="ov-api-server"

  # Stage Image from GITHUB
  github_clone_release "${REPO}" "${VERSION}"

  # Build Docker Image
  build_docker_image "${REPO}" "local/${IMAGE}:${VERSION}"
}

## Start Backend API Server
start_api() {
  # PARAM $1 - Container Name
  CONTAINER=$1

  # Docker Image
  IMAGE="ov-api-server"
  VERSION="v0.0.1"
  DOCKER_IMAGE="local/${IMAGE}:${VERSION}"

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/api/server.${MODE}.json"

    # Make Sure Backend Network exists
    network_create ${NET_BACKEND}

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm"
#    DOCKERCMD="docker run"

    # Set Server Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/app/server.json:ro"

    # Is Debug DB?
    if [ "$MODE" == "debug" ]; then
      # Expose Port so that we can attach from local system
      DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:3000:3000"
    fi

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} --name ${CONTAINER}"
    DOCKERCMD="${DOCKERCMD} -d ${DOCKER_IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container ${NET_BACKEND} "${CONTAINER}"
  fi
}
