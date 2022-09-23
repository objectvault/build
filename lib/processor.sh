#!/usr/bin/env bash

# Node Queue Processor Container Commands
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

## Build Docker Image for Queue Email Sender (Node Version)
build_processor_node() {
  REPO="queue-node-processor"
  VERSION="v0.0.2"
  IMAGE="ov-queue-processor"

  # Stage Image from GITHUB
  github_clone_release "${REPO}" "${VERSION}"

  # Build Docker Image
  build_docker_image "${REPO}" "local/${IMAGE}:${VERSION}"

  # Does Configuration Directory Exist?
  SRC="${SOURCEDIR}/${IMAGE}"
  if [ -d "${SRC}" ]; then # YES

    # Does Configuration Work Directory Exist?
    CONF="${CONTAINERDIR}/${IMAGE}"
    if [ -d "${CONF}" ]; then # YES: Remove it
      rm -rf "${CONF}"
    fi

    # Recreate Configuration Directory
    mkdir -p "${CONF}"

    # Copy Source Onfirguration to Container
    cp -r "${SRC}/." "$CONF"
  fi
}

start_processor_node() {
  # PARAM $1 - Container Name
  CONTAINER=$1

  # Docker Image
  IMAGE="ov-queue-processor"
  VERSION="v0.0.2"
  DOCKER_IMAGE="local/${IMAGE}:${VERSION}"

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/${IMAGE}/app.config.${MODE}.json"
    MIXINS="${CONTAINERDIR}/${IMAGE}/mixins.${MODE}"
    TEMPLATES="${CONTAINERDIR}/${IMAGE}/templates.${MODE}"

    # Make Sure required networks exist
    network_create 'net-ov-storage'

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm --name ${CONTAINER}"
#    DOCKERCMD="docker run"

    # Set Server Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${MIXINS}:/app/mixins:ro"
    DOCKERCMD="${DOCKERCMD} -v ${TEMPLATES}:/app/templates:ro"
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/app/app.config.json:ro"

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} -d ${DOCKER_IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container net-ov-storage "${CONTAINER}"
  fi
}
