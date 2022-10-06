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

## CONTAINER: MariaDB Server ##
source ./lib/db.sh

## CONTAINER: RabbitMQ ##
source ./lib/mq.sh

## CONTAINER: Node Queue Processor ##
source ./lib/qp.sh

## CONTAINER: BACK-END API Server ##
source ./lib/api.sh

## CONTAINER: FRONT-END Servers ##
source ./lib/fe.sh

## Start All Application Containers (Depends on MODE)
all_start() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - MODE

  ## START All Servers ##
  echo "START: Starting Servers"

  #1 Start Database and Queue Servers ##
  db_command $1 start $2 &
  mq_command $1 start $2 &

  # Delay 10 Seconds to Allow for Server Initialization
  sleep 10

  # Start Queue Processors
  qp_command $1 start $2

  # Delay 5 Seconds to Allow for Server Initialization
  sleep 5

  ## Start Backend Servers ##
  api_command $1 start $2

  # Delay 5 Seconds to Allow for Server Initialization
  sleep 5

  ## Start Frontend Server
  fe_command $1 start $2
}

## Stop All Application Containers (Depends on MODE)
all_stop() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - MODE

  ## STOP All Servers ##
  echo "Stopping Running Servers"

  # Stop Front-End Server
  fe_command $1 stop $2 &

  # Stop Back-End Server
  api_command $1 stop $2 &

  # Wait for FrontEnd and API Server
  sleep 10

  qp_command $1 stop $2

  # Wait for Queue Processors
  sleep 5

  # Stop RabbitMQ Server(s)
  mq_command $1 stop $2 &

  # Stop Database Server(s)
  db_command $1 stop $2 &

  # Delay 10 Seconds to Allow for Complete Stop
  sleep 15

  # Remove Existing Networks
  networks_rm
}

## Display ALL Help
all_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 all [start|stop|build|init|export] {debug|single|cluster}" >&2
  echo "       $1 all [help] " >&2
  echo >&2
  echo "Action:"
  echo "  start   - Start all Containers" >&2
  echo "  stop    - Stop all Running Containers" >&2
  echo "  build   - Build all Container Images" >&2
  echo "  init    - Initialize/Reset Containers" >&2
  echo "  export  - Export Configuration/Data for all Containers" >&2
  echo "  help    - Container usage message" >&2
  echo >&2
  echo "Possible MODES:"
  echo "  debug   - Local Debug Model [DEFAULT]"
  echo "  single  - Production: Single Server Mode"
  echo "  cluster - Production: Clustered Server Mode"
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$1 all start       --- Start all Containers in [DEBUG] mode" >&2
  echo "$1 all stop single --- Stop all Containers in [SINGLE] mode" >&2
  echo "$1 all export      --- Export all Configuration/Data in [DEBUG] mode" >&2
  exit 3
}

## Execute ALL Command
all_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5 - per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(parameter_mode $3)
      all_start $1 ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(parameter_mode $3)
      all_stop $1 ${mode}

      ## List Running Containers
      docker container ls
      ;;
    build)
      # Display Container Logs
      local mode=$(parameter_mode $3)
      all_log $1 ${mode}
      ;;
    init)
      # Execute a Shell in a Container
      local mode=$(parameter_mode $3)
      all_init $1 ${mode}
      ;;
    export)
      # Export Server Configuration
      local mode=$(parameter_mode $3)
      all_export $1 ${mode}
      ;;
    *)
      all_usage "$1"
      ;;
  esac
}
