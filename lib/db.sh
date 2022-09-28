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

# Database Properties
MYSQL=/opt/bitnami/mariadb/bin/mysql
MYSQLDUMP=/opt/bitnami/mariadb/bin/mysqldump
DB_USER=root
DB_USER_PWD=

# Recognized Actions and Modes
ACTIONS=( "start" "stop" "log" "shell" "dump" "init" "restore" "help" )
MODES=( "debug" "single" "dual" )

## Start Single Database Server
__db_start_server() {
  local image=$1     # Docker Image Name
  local container=$2 # Container Name
  local mode=$3      # Mode

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

__db_exec_sql() {
  # PARAMETERS
  local container=$1 # Container
  local sql=$2       # SQL Statement(s) to Execute
  local db=$3        # (OPTIONAL) Database

  ## Initialize Docker Command
  DOCKERCMD="docker exec ${container} ${MYSQL} -u ${DB_USER}"

  # Do we have a User PAssword Set?
  if [ ! -z ${DB_USER_PWD} ]; then # YES: Add User Password
    DOCKERCMD="${DOCKERCMD} --password=\"${DB_USER_PWD}\""
  fi

  # Add SQL Command
  DOCKERCMD="${DOCKERCMD} -e"

  # Execute the Command
  echo "${DOCKERCMD} \"${sql}\""

  # Execute Statement Against Database?
  if [ -z ${db} ]; then # NO:
    $DOCKERCMD "${sql}"
  else # YES:
    $DOCKERCMD "${sql} ${db}"
  fi
}

__db_drop_database() {
  # PARAMETERS
  local container=$1 # Container
  local db=$2        # Database to Drop

  # Create SQL Command
  local sql=$(cat <<EOF
DROP DATABASE IF EXISTS ${db};
SHOW DATABASES;
EOF
)

  __db_exec_sql $container "$sql"
}

__db_create_database() {
  # PARAMETERS
  local container=$1  # Container
  local db=$2         # Database to Create

  # Create SQL Command
  local sql=$(cat <<EOF
SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
CREATE DATABASE
  IF NOT EXISTS ${db}
  CHARACTER SET utf8
  COLLATE utf8_general_ci;
SHOW DATABASES;
EOF
)

  __db_exec_sql $container "$sql"
}

__db_dump_database() {
  # PARAMETERS
  local container=$1 # Container
  local db=$2        # Database to Dump

  # Create DUMP File Name with Full Path
  local timestamp=$(date "+%Y%m%d-%H%M%S")                    # Current Timestamp
  local output=${DB_DUMPSDIR}/${container}-${db}-${timestamp}.hex.sql   # Output File Name

  ## Initialize Docker Command
  DOCKERCMD="docker exec ${container} ${MYSQLDUMP} --hex-blob -u ${DB_USER}"

  # Do we have a User Password Set?
  if [ ! -z ${DB_USER_PWD} ]; then # YES: Add User Password
    DOCKERCMD="${DOCKERCMD} --password=\"${DB_USER_PWD}\""
  fi

  # Add Database Name to Dump
  DOCKERCMD="${DOCKERCMD} ${db}"

  # Execute the Command
  echo $DOCKERCMD
  $DOCKERCMD > ${output}
}

__db_restore_database() {
  # PARAMETERS
  local container=$1 # Container
  local db=$2        # Database to Dump
  local file=$3      # Relative File Name

  # Full DUMP File Name
  local input=${DB_DUMPSDIR}/$file # Input File Name

  ## Initialize Docker Command
  DOCKERCMD="docker exec -i ${container} ${MYSQL} -u ${DB_USER}"

  # Do we have a User PAssword Set?
  if [ ! -z ${DB_USER_PWD} ]; then # YES: Add User Password
    DOCKERCMD="${DOCKERCMD} --password=\"${DB_USER_PWD}\""
  fi

  # Add Database Name to Dump
  DOCKERCMD="${DOCKERCMD} ${db}"

  # Execute the Command
  echo "cat ${input} | $DOCKERCMD"
  cat ${input} | $DOCKERCMD
}

__parameter_mode() {
  # PARAM $1 - MODE
  local mode=$(in_list_or_default $1 $MODES "debug")
  echo $mode
}

__parameter_db() {
  # PARAM $1 - Database
  local db=${1:-"vault"}
  echo $db
}

__parameter_dump() {
  # PARAM $1 - Database
  local dump=${1:-"dump.sql"}
  echo $dump
}

## Start All Database Servers (Depends on Mode)
db_start() {
  # PARAM $1 - MODE
  local image="${MARIADB}"

  # Action Execution State
  echo "Working Mode [$1]"
  echo "Containers Directory [${CONTAINERDIR}]"

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

  # Action Execution State
  echo "Working Mode [$1]"

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

  # Action Execution State
  echo "Working Mode [$1]"

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

  # Action Execution State
  echo "Working Mode [$1]"

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
  # PARAM $2 - DATABASE
  echo "TODO: Implement"

  # Action Execution State
  echo "Working Mode    [$1]"
  echo "Initializing DB [$2]"
}

## Dump Database
db_dump() {
  # PARAM $1 - MODE
  # PARAM $2 - DATABASE

  # Action Execution State
  echo "Working Mode [$1]"
  echo "Dump DB      [$2]"

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      __db_dump_database "ov-debug-db" "$2"
      ;;
    single) # NOT Debug: Single Shard Server
      __db_dump_database "ov-s1-db" "$2"
      ;;
    dual) # NOT Debug: Dual Shard Server
      __db_dump_database "ov-d1-db" "$2"
      __db_dump_database "ov-d2-db" "$2"
      ;;
  esac
}

## Dump Database
db_restore() {
  # PARAM $1 - MODE
  # PARAM $2 - DATABASE
  # PARAM $3 - DUMP FILE

  # Action Execution State
  echo "Working Mode  [$1]"
  echo "Restore to DB [$2]"
  echo "Restore Dump  [$3]"

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      __db_drop_database    "ov-debug-db" "$2"
      __db_create_database  "ov-debug-db" "$2"
      __db_restore_database "ov-debug-db" "$2" "$3"
      ;;
    single) # NOT Debug: Single Shard Server
      __db_drop_database    "ov-s1-db" "$2"
      __db_create_database  "ov-s1-db" "$2"
      __db_restore_database "ov-s1-db" "$2" "$3"
      ;;
    dual) # NOT Debug: Dual Shard Server
      echo "Can't Restore Dump to more than one server"
      ;;
  esac
}

## Display DB Gelp
db_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 db [start|stop|log|shell]             {debug|single|dual}" >&2
  echo "       $1 db [init|dump]                        {debug|single|dual} {database}" >&2
  echo "       $1 db [restore]              [dump file] {debug|single|dual} {database}" >&2
  echo "       $1 db [help] " >&2
  echo >&2
  echo "Action:"
  echo "  start   - Start Container" >&2
  echo "  stop    - Stop Container" >&2
  echo "  log     - Display Docker logs for Container" >&2
  echo "  shell   - Interactive shell for Container" >&2
  echo "  init    - Initialize/Reset Container DB" >&2
  echo "  dump    - Dump Container DB" >&2
  echo "  restore - Restore Database Dump" >&2
  echo "  help    - Container usage message" >&2
  echo >&2
  echo "Parameters:"
  echo "  database  - Database to perform action on [DEFAULT: vault]"
  echo "  dump_file - File generated by \"dump\" action"
  echo "              File name only. Path is relative to \"dump\" path"
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
  echo "$1 mq init vault2 --- Initialize database [vault2]" >&2
  echo "$1 mq dump --- Dump default database [vault]" >&2
  echo "$1 mq restore ov-debug-db-vault2-20220924-092700.hex.sql vault3 --- Restore dump to database [vault3]" >&2
  exit 3
}

## Execute Container Command
db_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5- per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(__parameter_mode $3)
      db_start ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(__parameter_mode $3)
      db_stop ${mode}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      local mode=$(__parameter_mode $3)
      db_log ${mode}
      ;;
    shell)
      # Execute a Shell in a Container
      local mode=$(__parameter_mode $3)
      db_shell ${mode}
      ;;
    init)
      # Initialize Database
      local mode=$(__parameter_mode $3)
      local db=$(__parameter_db $4)
      db_init ${mode} ${db}
      ;;
    dump)
      # Dump Database
      local mode=$(__parameter_mode $3)
      local db=$(__parameter_db $4)
      db_dump ${mode} ${db}
      ;;
    restore)
      # Restore Database
      local dump=$(__parameter_dump $3)
      local mode=$(__parameter_mode $4)
      local db=$(__parameter_db $5)
      db_restore ${mode} ${db} ${dump}
      ;;
    *)
      db_usage "$1"
      ;;
  esac
}
