#!/usr/bin/env bash

# DB Container Commands
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

## Imnport Utility Functions
source ./lib/utility.sh

# Recognized Actions and Modes
ACTIONS=( "start" "stop" "log" "shell" "init" "dump" "help" )
MODES=( "debug" "single" "dual" )

## Start Single Database Server
__db_start_server() {
  local image=$1     # Docker Image Name
  local container=$2 # Container Name
  local mode=$3 # Mode

  # Is Container Running?
  status container "$container"
  if [[ $? == 0 ]]; then # NO
    ## Start an Instance of MariaDB
    echo "Running container '$container'"

    # Custom Configuration File
    local conf="${CONTAINERDIR}/mariadb/${container}.conf"
    local envfile="${CONTAINERDIR}/mariadb/.env.${mode}"

    # Create Container Volume
    volume_create "${CONTAINER}"

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm --name ${container}"
#    DOCKERCMD="docker run"

    ## Attach Volumes
    DOCKERCMD="${DOCKERCMD} -v ${container}:/bitnami/mariadb"
    DOCKERCMD="${DOCKERCMD} -v ${conf}:/opt/bitnami/mariadb/conf/my_custom.cnf:ro"

    # Expose Port so that we can attach from local system (Allows Access to DB)
    DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:3306:3306"

    # Do we have an Environment File
    if [ -f "${envfile}" ]; then  # YES: Use it
      DOCKERCMD="${DOCKERCMD} --env-file ${envfile}"
    fi

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} -d ${image}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Network
    connect_container ${NET_BACKEND} "${container}"
  fi
}

## Start All Database Servers (Depends on Mode)
db_start() {
  # PARAM $1 - MODE
  local image="${MARIADB}"

  # Make Sure Backend Network exists
  network_create ${NET_BACKEND}

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      __db_start_server $image "ov-debug-db" $1
      ;;
    single) # NOT Debug: Single Shard Server
      __db_start_server $image "ov-s1-db" $1
      ;;
    dual) # NOT Debug: Dual Shard Server
      __db_start_server $image "ov-d1-db" $1
      __db_start_server $image "ov-d2-db" $1
      ;;
  esac
}

## Stops All Database Servers (Depends on MODE)
db_stop() {
  # PARAM $1 - MODE

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      stop_container "ov-debug-db"
      ;;
    single) # NOT Debug: Single Shard Server
      stop_container "ov-s1-db"
      ;;
    dual) # NOT Debug: Dual Shard Server
      stop_container "ov-d1-db" &
      stop_container "ov-d2-db" &
      ;;
  esac
}

## Attach Logger to DB Container
db_log() {
  # PARAM $1 - MODE

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      logs_container "ov-debug-db"
      ;;
    single) # NOT Debug: Single Shard Server
      logs_container "ov-s1-db"
      ;;
    dual) # NOT Debug: Dual Shard Server
      echo "Can't Log more than one server"
      ;;
  esac
}

## Attach Shell to DB Container
db_shell() {
  # PARAM $1 - MODE

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      docker exec -it "ov-debug-db" /bin/bash
      ;;
    single) # NOT Debug: Single Shard Server
      docker exec -it "ov-s1-db" /bin/bash
      ;;
    dual) # NOT Debug: Dual Shard Server
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Initialize Database
db_init() {
  # PARAM $1 - MODE
  echo "TODO: Implement"
}

## Dump Database
db_dump() {
  # PARAM $1 - MODE
  echo "TODO: Implement"
}

## Display DB Gelp
db_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 mq [start|stop|log|shell|init|dump] {debug|single|dual} " >&2
  echo "       $1 mq [help] " >&2
  echo >&2
  echo "Action:"
  echo "  start - Start Container" >&2
  echo "  stop  - Stop Container" >&2
  echo "  log   - Display Docker logs for Container" >&2
  echo "  shell - Interactive shell for Container" >&2
  echo "  init  - Initialize/Reset Container DB" >&2
  echo "  dump  - Dump Container DB" >&2
  echo "  help  - Container usage message" >&2
  echo >&2
  echo "Possible MODES:"
  echo "  debug  - Local Debug Model [DEFAULT]"
  echo "  single - Single shard Mode"
  echo "  dual   - Dual shard Mode"
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$1 mq start --- Start Container in [DEBUG] mode" >&2
  echo "$1 mq stop single --- Stop Container in [SINGLE] mode" >&2
  exit 3
}

## Execute Container Command
mq_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3 - (Optional) Mode

  # Action to Execute
  ACTION=$2

  # WORKING MODE [DEFAULT: debug]
  MODE=$(in_list_or_default $MODE $MODES "debug")
  echo "Working Mode [${MODE}]"

  case "$ACTION" in
    start)
      echo "Containers Directory [${CONTAINERDIR}]"

      # Start Container(s)
      db_start ${MODE}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      db_stop ${MODE}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      db_log ${MODE}
      ;;
    shell)
      # Execute a Shell in a Container
      db_shell ${MODE}
      ;;
    init)
      # Initialize Database
      db_init ${MODE}
      ;;
    dump)
      # Dump Database
      db_dump ${MODE}
      ;;
    *)
      db_usage "$1"
      ;;
  esac
}
