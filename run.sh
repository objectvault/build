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

## Helper Function
source ./lib/utility.sh
source ./lib/git.sh
source ./lib/docker.sh

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


## Display Usage
usage() {
  echo "Usage: $0 {container|all} {action} [params...] " >&2
  echo "       $0 help" >&2
  echo "       $0 mode" >&2
  echo >&2
  echo "Containers:"
  echo "  db | mq | api | fe | qp" >&2
  echo >&2
  echo "MODES:" >&2
  echo "  debug   - Local Debugging" >&2
  echo "  single  - NON DEBUG: Single Server Environment" >&2
  echo "  cluster - NON DEBUG: Dual Server Environment" >&2
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$0 all start --- Start All in Default Mode [DEBUG]" >&2
  echo "$0 all help  --- Help for 'all' module" >&2
  echo >&2
  echo "MODE=[debug|single|cluster] $0 all start --- Start All in Specific Mode" >&2
  exit 3
}

# Verify Working mode
case "$MODE" in
  debug|single|cluster)
    mode
    ;;
  *)
    usage
esac

# Module to Execute
MODULE=$1

case "$MODULE" in
  mode)
    ;;
  *)
    # Do we have an embedded command
    RUNNER="${MODULE}_command"

    # Include Module Source
    source ./lib/${MODULE}.sh

    # Check if valid module
    if [[ $(type -t ${RUNNER}) == function ]]; then
      $RUNNER $0 ${@:2}
    else
      usage
    fi
    ;;
esac
