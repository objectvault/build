#!/usr/bin/env bash

# Frontend Server Container Commands
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

## Build Docker Image for Frontend Web Server
build_fe() {
  REPO="frontend"
  VERSION="v0.0.1"
  IMAGE="ov-fe-server"

  # Stage Image from GITHUB
  github_clone_release "${REPO}" "${VERSION}"

  # Build Docker Image
  build_docker_image "${REPO}" "local/${IMAGE}:${VERSION}"
}

## Start Frontend Web Server
start_fe() {
  # PARAM $1 - Container Name
  CONTAINER=$1

  # Docker Image
  IMAGE="ov-fe-server"
  VERSION="v0.0.1"
  DOCKER_IMAGE="local/${IMAGE}:${VERSION}"

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/fe/config.${MODE}.js"

    # Make Sure required networks exist
    network_create 'net-ov-storage'

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm"
#    DOCKERCMD="docker run"

    # Set Backend Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/usr/share/nginx/html/assets/config.js:ro"

    # Expose Port so that we can attach from local system
    DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:5000:80"

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} --name ${CONTAINER}"
    DOCKERCMD="${DOCKERCMD} -d ${DOCKER_IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container net-ov-storage "${CONTAINER}"
  fi
}
