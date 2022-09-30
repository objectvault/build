#!/usr/bin/env bash

# ObjectVault Runner
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

## WORKING MODE [DEFAULT: debug]
MODES=(debug single cluster)
MODE=${MODE:-"debug"}

## User Configurable RUN Settings
source ./settings.sh
source ./lib/git.sh
source ./lib/docker.sh

## CONTAINER: Node Queue Processor ##
source ./lib/processor.sh

## CONTAINER: BACK-END API Server ##
source ./lib/api.sh

## CONTAINER: FRONT-END Servers ##
source ./lib/fe.sh

## Start All Application Containers (Depends on MODE)
start_all() {
  ## START All Servers ##
  echo "STAGE-2: Starting Servers"

  # Re-create Networks
  networks_create

  ## Start Data Servers ##
  db_start "${MODE}" &
  start_mq &

  # Delay 10 Seconds to Allow for Server Initialization
  sleep 10

  # Start Queue Processors
  start_processor_node ov-mq-processor &

  ## Start Backend Servers ##
  start_api ov-api-server &

  # Delay 10 Seconds to Allow for Server Initialization
  sleep 5

  ## Start Frontend Server
  start_fe ov-fe-server
}

## Stop All Application Containers (Depends on MODE)
stop_all() {
  ## STOP All Servers ##
  echo "Stopping Running Servers"

  # Stop Front-End Server
  stop_container ov-fe-server &

  # Stop Back-End Server
  stop_container ov-api-server &

  # Wait for FrontEnd and API Server
  sleep 10

  stop_container ov-mq-processor &

  # Wait for Queue Processors
  sleep 10

  # Stop RabbitMQ Servers
  stop_mq &

  # Stop Data-Servers
  db_stop "${MODE}" &

  # Delay 10 Seconds to Allow for Complete Stop
  sleep 15

  # Remove Existing Networks
  networks_rm
}

build_all() {
  ## START All Servers ##
  echo "Building All Images"

  # Build API Server Docker Images
  build_api

  # Build Frontned Server Docker Images
  build_fe

  # Build RaabitMQ Mail Processor
  build_processor_node
}

## SHELL COMMAND: Start - On or More Application Containers
build() {
  ## Start
  echo "Building '$1'"

  case "$1" in
    all)
      build_all
      ;;
    api)
      build_api
      ;;
    fe)
      build_fe
      ;;
    mq)
      build_mq
      ;;
    processor)
      build_processor_node
      ;;
    *)
      usage
      ;;
  esac
}

## SHELL COMMAND: Start - On or More Application Containers
start() {
  ## Start
  echo "Starting '$1'"

  case "$1" in
    all)
      start_all
      ;;
    api)
      start_api ov-api-server
      ;;
    db)
      db_start "${MODE}"
      ;;
    fe)
      start_fe ov-fe-server
      ;;
    processor)
      start_processor_node ov-mq-processor
      ;;
    mq)
      start_mq
      ;;
    *)
      usage
      ;;
  esac
}

## SHELL COMMAND: Stop - On or More Application Containers
stop() {
  ## Stop
  echo "Stopping '$1'"

  case "$1" in
    all)
      stop_all
      ;;
    api)
      stop_container ov-api-server
      ;;
    db)
      db_stop "${MODE}"
      ;;
    fe)
      stop_container ov-fe-server
      ;;
    processor)
      stop_container ov-mq-processor
      ;;
    mq)
      stop_mq
      ;;
    *)
      usage
      ;;
  esac
}

## SHELL COMMAND: Log - Attach to Container Logger
log() {
  case "$1" in
    api)
      logs_container ov-api-server
      ;;
    db)
      db_log "${MODE}"
      ;;
    fe)
      logs_container ov-fe-server
      ;;
    processor)
      logs_container ov-mq-processor
      ;;
    mq)
      logs_rabbitmq
      ;;
    *)
      usage
      ;;
  esac
}

## SHELL COMMAND: Shell - Attach to Container shell
shell() {
    ## Shell
  echo "Console for '$1'"

  case "$1" in
    api)
      docker exec -it ov-api-server /bin/ash
      ;;
    fe)
      docker exec -it ov-fe-server /bin/ash
      ;;
    processor)
      docker exec -it ov-mq-processor /bin/ash
      ;;
    *)
      usage
      ;;
  esac
}

## SHELL COMMAND: Mode - Working Current Mode
mode() {
  case "$MODE" in
    debug)
      echo "Environment - Debug"
      ;;
    single)
      echo "Environment - Single Shard DB"
      ;;
    dual)
      echo "Environment - Dual Shard DB"
      ;;
    *)
      usage
      ;;
  esac
}


## Dsiplay Usage
usage() {
  echo "Usage: $0 {start|stop}  [all|{container}] DEFAULT: all" >&2
  echo "       $0 build         [all|api|fe|processor] DEFAULT: all" >&2
  echo "       $0 log           {container}" >&2
  echo "       $0 shell         {container}" >&2
  echo "       $0 networks      rm|create" >&2
  echo "       $0 mode" >&2
  echo >&2
  echo "Containers:"
  echo "  db | mq | api | fe | processor" >&2
  echo >&2
  echo "MODES:" >&2
  echo "  debug  - Local Debugging" >&2
  echo "  single - Single Shard Environment" >&2
  echo "  dual   - Dual Shard Environment" >&2
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$0 start all --- Start All in Default Mode [DEBUG]" >&2
  echo >&2
  echo "MODE=[debug|single|dual] $0 start all --- Start All in Specific Mode" >&2
  exit 3
}

# Verify Working mode
case "$MODE" in
  debug|single|dual)
    mode
    ;;
  *)
    usage
esac

# Action to Execute
ACTION=$1

case "$ACTION" in
  networks)
    if [[ $# < 2 ]]; then
      usage
    fi

    if [ "$2" == "create" ]; then
      networks_create
    elif [ "$2" == "rm" ]; then
      networks_rm
    else
      usage
    fi

    ## List Active Networks
    docker network ls
    ;;
  log)
    if [[ $# < 2 ]]; then
      usage
    fi

    log "$2"
    ;;
  build)
    # Container : DEFAULT [all]
    CONTAINER=${2:-"all"}

    # Stop Container(s)
    build "$CONTAINER"

    ## List Docker Images
    docker image ls
    ;;
  start)
    echo "Containers Directory [${CONTAINERDIR}]"

    # Container : DEFAULT [all]
    CONTAINER=${2:-"all"}

    # Start Container(s)
    start "${CONTAINER}"

    ## List Running Containers
    docker container ls
    ;;
  stop)
    # Container : DEFAULT [all]
    CONTAINER=${2:-"all"}

    # Stop Container(s)
    stop "$CONTAINER"

    ## List Running Containers
    docker container ls
    ;;
  shell) # Execute a Shell in a Container
    shell "${2}"
    ;;
  mode)
    ;;
  *)
    # Do we have an embedded command
    COMMAND="${ACTION}_command"

    ## Include Command Source
    source ./lib/${ACTION}.sh

    echo $COMMAND
    if [[ $(type -t ${COMMAND}) == function ]]; then
      $COMMAND $0 ${@:2}
    else
      usage
    fi
    ;;
esac
