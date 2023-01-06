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

# Frontend Server Properties
QP_REPO="queue-node-processor"
QP_IMAGE="ov-queue-processor"
QP_VERSION="v0.0.4"

## HELPERS ##
# Initialize RabbitMQ Container
__qp_init_server() {
  # INPUTS
  local container=$1 # Container Name

  echo "INITIALIZE Container '$container'"

  ## STEP 1 : Stop Container
  # Is Container Running?
  status container "$container"
  if [[ $? != 0 ]]; then # YES
    echo "Container '$container' is being stopped"
    stop_container "$container"
  fi

  ## STEP 2 : Initialize Configuration
  # Does Source Configuration Directory Exist?
  local src="${SOURCEDIR}/qp/${container}"
  echo $src
  if [ -d "${src}" ]; then # YES
    # Does Work Configuration Directory Exist?
    local conf="${CONTAINERDIR}/qp/${container}"
    if [ -d "${conf}" ]; then # YES: Remove it
      rm -rf "${conf}"
    fi

    # Recreate Configuration Directory
    mkdir -p "${conf}"

    # Copy Source Configuration to Container
    cp -ar "${src}/." "$conf"
  fi
}

## Start a RabbitMQ Server
__qp_start_server() {
  # INPUTS
  local image=$1     # Docker Image Name
  local container=$2 # Container Name
  local mode=$3      # Mode

  # Is Container Running?
  status container "${container}"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '${container}"

    # Container Configuration Directory
    local confdir="${CONTAINERDIR}/qp/${container}"

    # Make Sure Backend Network exists
    network_create ${NET_BACKEND}

    ## Initialize Docker Command
    local DOCKERCMD="docker run --rm --name ${container}"
#    DOCKERCMD="docker run"

    # Set Server Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${confdir}/mixins:/app/mixins:ro"
    DOCKERCMD="${DOCKERCMD} -v ${confdir}/templates:/app/templates:ro"
    DOCKERCMD="${DOCKERCMD} -v ${confdir}/app.config.json:/app/app.config.json:ro"

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} -d ${image}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container ${NET_BACKEND} "${container}"
  fi
}

## Start Queue Processor Container(s)
qp_start() {
  # PARAM $1 - MODE

  # Docker Image
  local docker_image="local/${QP_IMAGE}:${QP_VERSION}"

  # Action Execution State
  echo "Working Mode [$1]"

  # Make Sure Backend Network exists
  network_create ${NET_BACKEND}

  # Options based on Mode
  case "$1" in
    debug) # Debug Server
      __qp_start_server $docker_image "ov-qp-debug" $1
      ;;
    single) # NOT Debug: Single Server
      __qp_start_server $docker_image "ov-qp-s1" $1
      ;;
    cluster) # NOT Debug: Dual Server
      __qp_start_server $docker_image "ov-qp-c1" $1
      __qp_start_server $docker_image "ov-qp-c2" $1
      ;;
  esac
}

## Stops Queue Processor Container(s)
qp_stop() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Debug Server
      stop_container "ov-qp-debug"
      ;;
    single) # NOT Debug: Single Server
      stop_container "ov-qp-s1"
      ;;
    cluster) # NOT Debug: Dual Server
      stop_container "ov-qp-c1" &
      stop_container "ov-qp-c2" &
      ;;
  esac
}

## Attach Logger to Queue Processor Container
qp_log() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$MODE" in
    debug) # Debug Server
      logs_container "ov-qp-debug"
      ;;
    single) # NOT Debug: Single Server
      logs_container "ov-qp-s1"
      ;;
    cluster) # NOT Debug: Dual Server
      echo "Can't Log more than one server"
      ;;
  esac
}

## Attach Shell to Queue Processor Container
qp_shell() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Debug Server
      docker exec -it "ov-qp-debug" /bin/ash
      ;;
    single) # NOT Debug: Single Server
      docker exec -it "ov-qp-s1" /bin/ash
      ;;
    cluster) # NOT Debug: Dual Server
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Initialize Queue Processor Container
qp_init() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Queue Processor: Debug Server
      __qp_init_server "ov-qp-debug"
      ;;
    single) # Queue Processor: Single Production Server
      __qp_init_server "ov-qp-s1"
      ;;
    cluster) # Queue Processor: Cluster
      __qp_init_server "ov-qp-c1"
      __qp_init_server "ov-qp-c2"
      ;;
  esac
}

## Build Docker Image for Server
qp_build() {
  # Docker Image
  local docker_image="local/${QP_IMAGE}:${QP_VERSION}"

  # Stage Image from GITHUB
  github_clone_release "${QP_REPO}" "${QP_VERSION}"

  # Build Docker Image
  build_docker_image "${QP_REPO}" "${docker_image}"
}

## Display Queue Processor Server Help
qp_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 qp [start|stop|log|shell|build] {debug|single|cluster}" >&2
  echo "       $1 qp [build|init]                 {debug|single|cluster}" >&2
  echo "       $1 qp [help] " >&2
  echo >&2
  echo "Action:"
  echo "  start   - Start Container" >&2
  echo "  stop    - Stop Container" >&2
  echo "  log     - Display Docker logs for Container" >&2
  echo "  shell   - Interactive shell for Container" >&2
  echo "  build   - Build Container Image" >&2
  echo "  init    - Initialize/Reset Container Configuration" >&2
  echo "  help    - Container usage message" >&2
  echo >&2
  echo "Possible MODES:"
  echo "  debug   - Local Debug Model [DEFAULT]"
  echo "  single  - Production: Single Server Mode"
  echo "  cluster - Production: Clustered Server Mode"
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$1 qp start       --- Start Container in [DEBUG] mode" >&2
  echo "$1 qp stop single --- Stop Container in  [SINGLE] mode" >&2
  exit 3
}

## Execute Container Command
qp_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5 - per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(parameter_mode $3)
      qp_start ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(parameter_mode $3)
      qp_stop ${mode}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      local mode=$(parameter_mode $3)
      qp_log ${mode}
      ;;
    shell)
      # Execute a Shell in a Container
      local mode=$(parameter_mode $3)
      qp_shell ${mode}
      ;;
    build)
      # Build Container Image
      local mode=$(parameter_mode $3)
      qp_build ${mode}
      ;;
    init)
      # Initialize Container(s)
      local mode=$(parameter_mode $3)
      qp_init ${mode}
      ;;
    *)
      qp_usage "$1"
      ;;
  esac
}

