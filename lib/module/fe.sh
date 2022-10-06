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

# Frontend Server Properties
FE_REPO="frontend"
FE_IMAGE="ov-fe-server"
FE_VERSION="v0.0.1"

## HELPERS ##
__fe_start_server() {
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
    local conf="${CONTAINERDIR}/fe/config.${mode}.js"

    # Make Sure Backend Network exists
    network_create ${NET_BACKEND}

    ## Initialize Docker Command
    local DOCKERCMD="docker run --rm"
#    DOCKERCMD="docker run"

    # Set Backend Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${conf}:/usr/share/nginx/html/assets/config.js:ro"

    # Expose Port so that we can attach from local system
    DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:5000:80"

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

## Start Frontend Server
fe_start() {
  # PARAM $1 - MODE

  # Docker Image
  local docker_image="local/${FE_IMAGE}:${FE_VERSION}"

  # Action Execution State
  echo "Working Mode [$1]"

  # Make Sure Backend Network exists
  network_create ${NET_BACKEND}

  # Options based on Mode
  case "$1" in
    debug) # Debug Server
      __fe_start_server $docker_image "ov-fe-debug" $1
      ;;
    single) # NOT Debug: Single Server
      __fe_start_server $docker_image "ov-fe-s1" $1
      ;;
    cluster) # NOT Debug: Dual Server
      __fe_start_server $docker_image "ov-fe-c1" $1
      __fe_start_server $docker_image "ov-fe-c2" $1
      ;;
  esac
}

## Stops All Frontend Servers (Depends on MODE)
fe_stop() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Debug Server
      stop_container "ov-fe-debug"
      ;;
    single) # NOT Debug: Single Server
      stop_container "ov-fe-s1"
      ;;
    cluster) # NOT Debug: Dual Server
      stop_container "ov-fe-c1" &
      stop_container "ov-fe-c2" &
      ;;
  esac
}

## Attach Logger to Frontend Server Container
fe_log() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$MODE" in
    debug) # Debug Server
      logs_container "ov-fe-debug"
      ;;
    single) # NOT Debug: Single Server
      logs_container "ov-fe-s1"
      ;;
    cluster) # NOT Debug: Dual Server
      echo "Can't Log more than one server"
      ;;
  esac
}

## Attach Shell to Frontend Server Container
fe_shell() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Debug Server
      docker exec -it "ov-fe-debug" /bin/ash
      ;;
    single) # NOT Debug: Single Server
      docker exec -it "ov-fe-s1" /bin/ash
      ;;
    cluster) # NOT Debug: Dual Server
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Build Docker Image for Server
fe_build() {
  # Docker Image
  local docker_image="local/${FE_IMAGE}:${FE_VERSION}"

  # Stage Image from GITHUB
  github_clone_release "${FE_REPO}" "${FE_VERSION}"

  # Build Docker Image
  build_docker_image "${FE_REPO}" "${docker_image}"
}

## Display Frontend Server Help
fe_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 fe [start|stop|log|shell|build] {debug|single|cluster}" >&2
  echo "       $1 fe [help] " >&2
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
  echo "$1 fe start       --- Start Container in [DEBUG] mode" >&2
  echo "$1 fe stop single --- Stop Container in  [SINGLE] mode" >&2
  exit 3
}

## Execute Container Command
fe_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5 - per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(parameter_mode $3)
      fe_start ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(parameter_mode $3)
      fe_stop ${mode}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      local mode=$(parameter_mode $3)
      fe_log ${mode}
      ;;
    shell)
      # Execute a Shell in a Container
      local mode=$(parameter_mode $3)
      fe_shell ${mode}
      ;;
    build)
      # Build Container Image
      local mode=$(parameter_mode $3)
      fe_build ${mode}
      ;;
    *)
      fe_usage "$1"
      ;;
  esac
}
