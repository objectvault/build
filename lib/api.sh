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

# API Server Properties
API_REPO="api-services"
API_IMAGE="ov-api-server"
API_VERSION="v0.0.1"

## HELPERS ##
__api_start_server() {
  # INPUTS
  local image=$1     # Docker Image Name
  local container=$2 # Container Name
  local mode=$3      # Mode

  # Is Container Running?
  status container "$container"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$container'"

    # Custom Configuration File
    local conf="${CONTAINERDIR}/api/server.${mode}.json"

    # Make Sure Backend Network exists
    network_create ${NET_BACKEND}

    ## Initialize Docker Command
    local DOCKERCMD="docker run --rm"
#    DOCKERCMD="docker run"

    # Set Server Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${conf}:/app/server.json:ro"

    # Is Debug DB?
    if [ "$MODE" == "debug" ]; then
      # Expose Port so that we can attach from local system
      DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:3000:3000"
    fi

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} --name ${container}"
    DOCKERCMD="${DOCKERCMD} -d ${image}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container ${NET_BACKEND} "${container}"
  fi
}

## Start Backend API Server
api_start() {
  # PARAM $1 - MODE

  # Docker Image
  local docker_image="local/${API_IMAGE}:${API_VERSION}"

  # Action Execution State
  echo "Working Mode [$1]"

  # Make Sure Backend Network exists
  network_create ${NET_BACKEND}

  # Options based on Mode
  case "$MODE" in
    debug) # RabbitMQ: Debug Server
      __api_start_server $docker_image "ov-api-debug" $1
      ;;
    single) # RabbitMQ: Single Server
      __api_start_server $docker_image "ov-api-s1" $1
      ;;
    cluster) # RabbitMQ: Server Cluster
      __api_start_server $docker_image "ov-api-c1" $1
      __api_start_server $docker_image "ov-api-c2" $1
      ;;
  esac
}

## Stops All API Servers (Depends on MODE)
api_stop() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      stop_container "ov-api-debug"
      ;;
    single) # NOT Debug: Single Shard Server
      stop_container "ov-api-s1"
      ;;
    cluster) # NOT Debug: Dual Shard Server
      stop_container "ov-api-c1" &
      stop_container "ov-api-c2" &
      ;;
  esac
}

## Attach Logger to API Server Container
api_log() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$MODE" in
    debug) # RabbitMQ: Debug Server
      logs_container "ov-api-debug"
      ;;
    single) # RabbitMQ: Single Production Server
      logs_container "ov-api-s1"
      ;;
    cluster) # RabbitMQ: Cluster
      echo "Can't Log more than one server"
      ;;
  esac
}

## Attach Shell to API Server Container
api_shell() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # RabbitMQ: Debug Server
      docker exec -it "ov-api-debug" /bin/ash
      ;;
    single) # RabbitMQ: Single Production Server
      docker exec -it "ov-api-s1" /bin/ash
      ;;
    cluster) # RabbitMQ: Cluster
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Build Docker Image for API Server
api_build() {
  # Docker Image
  local docker_image="local/${API_IMAGE}:${API_VERSION}"

  # Stage Image from GITHUB
  github_clone_release "${API_REPO}" "${API_VERSION}"

  # Build Docker Image
  build_docker_image "${API_REPO}" "${docker_image}"
}

## Display Message Queue Help
api_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 api [start|stop|log|shell|build] {debug|single|cluster}" >&2
  echo "       $1 api [help] " >&2
  echo >&2
  echo "Action:"
  echo "  start   - Start Container" >&2
  echo "  stop    - Stop Container" >&2
  echo "  log     - Display Docker logs for Container" >&2
  echo "  shell   - Interactive shell for Container" >&2
  echo "  build   - Build Container Image" >&2
  echo "  help    - Container usage message" >&2
  echo >&2
  echo "Possible MODES:"
  echo "  debug   - Local Debug Model [DEFAULT]"
  echo "  single  - Production: Single Server Mode"
  echo "  cluster - Production: Clustered Server Mode"
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$1 api start       --- Start Container in [DEBUG] mode" >&2
  echo "$1 api stop single --- Stop Container in  [SINGLE] mode" >&2
  exit 3
}

## Execute Container Command
api_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5 - per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(parameter_mode $3)
      api_start ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(parameter_mode $3)
      api_stop ${mode}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      local mode=$(parameter_mode $3)
      api_log ${mode}
      ;;
    shell)
      # Execute a Shell in a Container
      local mode=$(parameter_mode $3)
      api_shell ${mode}
      ;;
    build)
      # Build Container Image
      local mode=$(parameter_mode $3)
      api_build ${mode}
      ;;
    *)
      api_usage "$1"
      ;;
  esac
}
