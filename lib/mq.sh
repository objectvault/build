#!/usr/bin/env bash

# MQ Container Commands
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# RabbitMQ Properties
MQ_ACTIONS=(start stop log shell init)
RABBITMQCTL=/opt/rabbitmq/sbin/rabbitmqctl

## HELPERS ##
__mq_parameter_file() {
  # PARAM $1 - File Name
  local file=${1:-"export"}
  echo $file
}

## Start a RabbitMQ Server
__mq_start_server() {
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
    local conf="${CONTAINERDIR}/rabbitmq/${container}"
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
    DOCKERCMD="${DOCKERCMD} -v ${container}:/var/lib/rabbitmq"
    DOCKERCMD="${DOCKERCMD} -v ${conf}/conf:/etc/rabbitmq:ro"

    # Options based on Mode
    case "$mode" in
      debug)
        # Expose Port so that we can attach from local system
        DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:4369:4369"
        DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:5671:5671"
        DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:5672:5672"
        DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:15672:15672"
        DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:25672:25672"
        ;;
      *)
        # Expose Port so that we can attach to management from remote system
        DOCKERCMD="${DOCKERCMD} -p 15672:15672"
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

# Initialize RabbitMQ Container
__mq_init_server() {
  # INPUTS
  local image=$1     # Docker Image Name
  local container=$2 # Container Name

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
  local src="${SOURCEDIR}/rabbitmq/${container}"
  local conf="${CONTAINERDIR}/rabbitmq/${container}"
  if [ -d "${conf}" ]; then # YES: Remove it
    rm -rf "${conf}"
  fi

  # Recreate Configuration Directory
  mkdir -p "${conf}"

  # Copy Source Onfirguration to Container
  cp -r "${src}/." "${conf}"

  ## STEP 4 : Initialize Container

  ## Initialize Docker Command
  local DOCKERCMD="docker run --rm --name ${container}"

  # Do we have an Environment File
  local envfile="${src}/.env.init"
  if [ -f "${envfile}" ]; then  # YES: Use it
    # SET Environment File (Used to Initialize Administration User)
    DOCKERCMD="${DOCKERCMD} --env-file ${envfile}"
  fi

  # SET Volumes
  DOCKERCMD="${DOCKERCMD} -v ${container}:/var/lib/rabbitmq"
  DOCKERCMD="${DOCKERCMD} -v ${conf}/conf:/etc/rabbitmq:ro"

  # Add Image Name
  DOCKERCMD="${DOCKERCMD} -d ${image}"

  # Execute the Command
  echo $DOCKERCMD
  $DOCKERCMD

  # Wait for Container to Stabilize and then stop
  sleep 10
  stop_container ${container}
}

# Export RabbitMQ Configuration
__mq_export() {
  # PARAMETERS
  local container=$1 # Container

  # Create DUMP File Name with Full Path
  local timestamp=$(date "+%Y%m%d-%H%M%S")                    # Current Timestamp
  local output=${MQ_DUMPSDIR}/${container}-export-${timestamp}.json   # Output File Name

  ## STEP 1 : Export Configuration to container inernal file
  local DOCKERCMD="docker exec ${container} ${RABBITMQCTL} export_definitions /tmp/export.json"
  echo $DOCKERCMD
  $DOCKERCMD

  ## STEP 2 : Copy EXPORT to File Outside Container
  DOCKERCMD="docker cp ${container}:/tmp/export.json ${output}"
  echo "$DOCKERCMD"
  $DOCKERCMD
}

# Export RabbitMQ Configuration
__mq_import() {
  # PARAMETERS
  local container=$1 # Container
  local file=$2      # Relative EXPORT File Name

  # Full EXPORT File Name
  local input=${MQ_DUMPSDIR}/$file # Input File Name

  ## STEP 1 : Copy File into Container
  local DOCKERCMD="docker cp ${input} ${container}:/tmp/import.json"
  echo $DOCKERCMD
  $DOCKERCMD

  ## STEP 2 : Import Definitions into Server
  DOCKERCMD="docker exec ${container} ${RABBITMQCTL} import_definitions /tmp/import.json"
  echo $DOCKERCMD
  $DOCKERCMD
}

## COMMANDS ##

## Start All RabbitMQ Servers (Depends on Mode)
mq_start() {
    # PARAM $1 - MODE
  local image="${RABBITMQ}"

  # Action Execution State
  echo "Working Mode [$1]"

  # Make Sure Backend Network exists
  network_create ${NET_BACKEND}

  # Options based on Mode
  case "$MODE" in
    debug) # RabbitMQ: Debug Server
      __mq_start_server $image "ov-mq-debug" $1
      ;;
    single) # RabbitMQ: Single Server
      __mq_start_server $image "ov-mq-s1" $1
      ;;
    cluster) # RabbitMQ: Server Cluster
      __mq_start_server $image "ov-mq-c1" $1
      __mq_start_server $image "ov-mq-c2" $1
      ;;
  esac
}

## Stops All RabbitMQ Servers (Depends on MODE)
mq_stop() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$MODE" in
    debug) # RabbitMQ: Debug Server
      stop_container "ov-mq-debug"
      ;;
    single) # RabbitMQ: Single Production Server
      stop_container "ov-mq-s1"
      ;;
    cluster) # RabbitMQ: Cluster (Reverse Start Order)
      stop_container "ov-mq-c2"
      stop_container "ov-mq-c1"
      ;;
  esac
}

## Attach Logger to RabbitMQ Container
mq_log() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$MODE" in
    debug) # RabbitMQ: Debug Server
      logs_container "ov-mq-debug"
      ;;
    single) # RabbitMQ: Single Production Server
      logs_container "ov-mq-s1"
      ;;
    cluster) # RabbitMQ: Cluster
      echo "Can't Log more than one server"
      ;;
  esac
}

## Attach Shell to RabbitMQ Container
mq_shell() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # RabbitMQ: Debug Server
      docker exec -it "ov-mq-debug" /bin/ash
      ;;
    single) # RabbitMQ: Single Production Server
      docker exec -it "ov-mq-s1" /bin/ash
      ;;
    cluster) # RabbitMQ: Cluster
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Initialize RabbitMQ Container
mq_init() {
  # PARAM $1 - MODE
  local image="${RABBITMQ}"

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # RabbitMQ: Debug Server
      __mq_init_server $image "ov-mq-debug"
      ;;
    single) # RabbitMQ: Single Production Server
      __mq_init_server $image "ov-mq-s1"
      ;;
    cluster) # RabbitMQ: Cluster
      __mq_init_server $image "ov-mq-c1"
      __mq_init_server $image "ov-mq-c2"
      ;;
  esac
}

## Export RabbitMQ Container(s) Configuration
mq_export() {
  # PARAM $1 - MODE

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # RabbitMQ: Debug Server
      __mq_export "ov-mq-debug"
      ;;
    single) # RabbitMQ: Single Production Server
      __mq_export "ov-mq-s1"
      ;;
    cluster) # RabbitMQ: Cluster
      __mq_export "ov-mq-c1"
      __mq_export "ov-mq-c2"
      ;;
  esac
}

## Import RabbitMQ Container(s) Configuration
mq_import() {
  # PARAM $1 - MODE
  # PARAM $2 - Export Configuration File

  # Action Execution State
  echo "Working Mode [$1]"

  # Options based on Mode
  case "$1" in
    debug) # RabbitMQ: Debug Server
      __mq_import "ov-mq-debug" "$2"
      ;;
    single) # RabbitMQ: Single Production Server
      __mq_import "ov-mq-s1" "$2"
      ;;
    cluster) # RabbitMQ: Cluster
      echo "Can't Import to more than one server"
      ;;
  esac
}

## Display Message Queue Help
mq_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 mq [start|stop|log|shell]              {debug|single|cluster}" >&2
  echo "       $1 mq [init|export]                       {debug|single|cluster}" >&2
  echo "       $1 mq [import]              [export_file] {debug|single|cluster}" >&2
  echo "       $1 mq [help] " >&2
  echo >&2
  echo "Action:"
  echo "  start   - Start Container" >&2
  echo "  stop    - Stop Container" >&2
  echo "  log     - Display Docker logs for Container" >&2
  echo "  shell   - Interactive shell for Container" >&2
  echo "  init    - Initialize/Reset Container DB" >&2
  echo "  help    - Container usage message" >&2
  echo >&2
  echo "Parameters:"
  echo "  export_file - File generated by \"export\" action"
  echo "                File name only. Path is relative to \"export\" path"
  echo >&2
  echo "Possible MODES:"
  echo "  debug   - Local Debug Model [DEFAULT]"
  echo "  single  - Production: Single Server Mode"
  echo "  cluster - Production: Clustered Server Mode"
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$1 mq start       --- Start Container in [DEBUG] mode" >&2
  echo "$1 mq stop single --- Stop Container in [SINGLE] mode" >&2
  echo "$1 mq export      --- Export server configuration in [DEBUG] mode" >&2
  echo "$1 mq import ov-debug-mq-export-20220929-125223.json --- Import server configuration in [DEBUG] mode" >&2
  exit 3
}

## Execute Container Command
mq_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5 - per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(parameter_mode $3)
      mq_start ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(parameter_mode $3)
      mq_stop ${mode}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      local mode=$(parameter_mode $3)
      mq_log ${mode}
      ;;
    shell)
      # Execute a Shell in a Container
      local mode=$(parameter_mode $3)
      mq_shell ${mode}
      ;;
    init)
      # Initialize Container(s)
      local mode=$(parameter_mode $3)
      mq_init ${mode}
      ;;
    export)
      # Export Server Configuration
      local mode=$(parameter_mode $3)
      mq_export ${mode}
      ;;
    import)
      # Import Server Configuration
      local file=$(__mq_parameter_file $3)
      local mode=$(parameter_mode $4)
      mq_import ${mode} ${file}
      ;;
    *)
      mq_usage "$1"
      ;;
  esac
}
