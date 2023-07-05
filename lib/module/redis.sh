#!/usr/bin/env bash

# Redis Container Commands
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2023 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# Redis Properties
REDIS="redis/redis-stack"
REDIS_ACTIONS=(start stop log shell init)
REDISCLI="/bin/redis-cli"

## HELPERS ##

## Start a Redis Server
__redis_start_server() {
  # INPUTS
  local image=$1     # Docker Image Name
  local container=$2 # Container Name
  local mode=$3      # Mode

  # Is Container Running?
  status container "$container"
  if [[ $? == 0 ]]; then # NO
    ## Start Server
    echo "Running container '$container'"

    # Configuration Files
    local conf="${CONTAINERDIR}/redis/${container}"
    if [ ! -d "${conf}" ]; then
      echo "Need to initialize '${container}' before 1st run"
      exit 1;
    fi
    local envfile="${conf}/.env"

    # Make Sure the Volume Exists
    volume_create "${container}"

    ## Initialize Docker Command
    local DOCKERCMD="docker run --rm --name ${container}"
#    DOCKERCMD="docker run"

    # Do we have an Environment File
    if [ -f "${envfile}" ]; then  # YES: Use it
      # SET Environment File (Used to Initialize Administration User)
      DOCKERCMD="${DOCKERCMD} --env-file ${envfile}"
    fi

    # SET Volumes
    DOCKERCMD="${DOCKERCMD} -v ${container}:/data"
    #DOCKERCMD="${DOCKERCMD} -v ${conf}/local-redis-stack.conf:/redis-stack.conf"

    # Options based on Mode
    case "$mode" in
      debug)
        # Expose Port so that we can attach from local system
        DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:6379:6379"
        DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:8001:8001"
        ;;
      *)
        # Expose Port so that we can attach to management from remote system
        DOCKERCMD="${DOCKERCMD} -p 6379:6379"
        ;;
    esac

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} -d ${image}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Network
    connect_container ${NET_BACKEND} "${container}"
  fi
}

# Initialize Redis Container
__redis_init_server() {
  # INPUTS
  local image=$1     # Docker Image Name
  local container=$2 # Container Name
  local mode=$3      # Mode

  echo "INITIALIZE Container '$container'"

  ## STEP 1 : Stop Container
  # Is Container Running?
  status container "$container"
  if [[ $? != 0 ]]; then # YES
    echo "Container '$container' is being stopped"
    stop_container "$container"
  fi

  ## STEP 2 : Recreate ANY Existing Volumes
  volume_rm "${container}"
  volume_create "${container}"

  ## STEP 3 : Initialize Configuration

  # Does Configuration Directory Exist
  local src="${SOURCEDIR}/redis/${container}"
  local conf="${CONTAINERDIR}/redis/${container}"
  if [ -d "${conf}" ]; then # YES: Remove it
    rm -rf "${conf}"
  fi

  # Recreate Configuration Directory
  mkdir -p "${conf}"
}

## COMMANDS ##

## Start All Redis Servers (Depends on Mode)
redis_start() {
    # PARAM $1 - MODE
  local image="${REDIS}"

  # Action Execution State
  echo "Working Mode [$1]"

  # Make Sure Backend Network exists
  network_create ${NET_BACKEND}

  # Options based on Mode
  case "$MODE" in
    debug) # Redis: Debug Server
      __redis_start_server $image "ov-redis-debug" $1
      ;;
    single) # Redis: Single Server
      __redis_start_server $image "ov-redis-s1" $1
      ;;
    cluster) # Redis: Server Cluster
      __redis_start_server $image "ov-redis-c1" $1
      __redis_start_server $image "ov-redis-c2" $1
      ;;
  esac
}

## Stops All Redis Servers (Depends on MODE)
redis_stop() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$MODE" in
    debug) # Redis: Debug Server
      stop_container "ov-redis-debug"
      ;;
    single) # Redis: Single Production Server
      stop_container "ov-redis-s1"
      ;;
    cluster) # Redis: Cluster (Reverse Start Order)
      stop_container "ov-redis-c2"
      stop_container "ov-redis-c1"
      ;;
  esac
}

## Attach Logger to Redis Container
redis_log() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$MODE" in
    debug) # Redis: Debug Server
      logs_container "ov-redis-debug"
      ;;
    single) # Redis: Single Production Server
      logs_container "ov-redis-s1"
      ;;
    cluster) # Redis: Cluster
      echo "Can't Log more than one server"
      ;;
  esac
}

## Attach Shell to Redis Container
redis_shell() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Redis: Debug Server
      docker exec -it "ov-redis-debug" /bin/dash
      ;;
    single) # Redis: Single Production Server
      docker exec -it "ov-redis-s1" /bin/dash
      ;;
    cluster) # Redis: Cluster
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Attach to Redis CLI
redis_cli() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Redis: Debug Server
      docker exec -it "ov-redis-debug" "${REDISCLI}"
      ;;
    single) # Redis: Single Production Server
      docker exec -it "ov-redis-s1" "${REDISCLI}"
      ;;
    cluster) # Redis: Cluster
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Initialize Redis Container
redis_init() {
  # PARAM $1 - MODE
  local image="${RABBITMQ}"

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # Redis: Debug Server
      __redis_init_server $image "ov-redis-debug" $1
      ;;
    single) # Redis: Single Production Server
      __redis_init_server $image "ov-redis-s1" $1
      ;;
    cluster) # Redis: Cluster
      __redis_init_server $image "ov-redis-c1" $1
      __redis_init_server $image "ov-redis-c2" $1
      ;;
  esac
}

## Display Message Queue Help
redis_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 redis [start|stop|log|shell]           {debug|single|cluster}" >&2
  echo "       $1 redis [init|cli]                       {debug|single|cluster}" >&2
  echo "       $1 redis [help] " >&2
  echo >&2
  echo "Action:"
  echo "  start   - Start Container" >&2
  echo "  stop    - Stop Container" >&2
  echo "  log     - Display Docker logs for Container" >&2
  echo "  shell   - Interactive shell for Container" >&2
  echo "  init    - Initialize/Reset Container" >&2
  echo "  help    - Container usage message" >&2
  echo >&2
  echo "Possible MODES:"
  echo "  debug   - Local Debug Model [DEFAULT]"
  echo "  single  - Production: Single Server Mode"
  echo "  cluster - Production: Clustered Server Mode"
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$1 redis start       --- Start Container in [DEBUG] mode" >&2
  echo "$1 redis stop single --- Stop Container in [SINGLE] mode" >&2
  exit 3
}

## Execute Container Command
redis_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5 - per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(parameter_mode $3)
      redis_start ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(parameter_mode $3)
      redis_stop ${mode}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      local mode=$(parameter_mode $3)
      redis_log ${mode}
      ;;
    shell)
      # Execute a Shell in a Container
      local mode=$(parameter_mode $3)
      redis_shell ${mode}
      ;;
    cli)
      # Execute a Redis CLI in Container
      local mode=$(parameter_mode $3)
      redis_cli ${mode}
      ;;
    init)
      # Initialize Container(s)
      local mode=$(parameter_mode $3)
      redis_init ${mode}
      ;;
    *)
      redis_usage "$1"
      ;;
  esac
}
