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

# Database Properties
MYSQL=/opt/bitnami/mariadb/bin/mysql
MYSQLDUMP=/opt/bitnami/mariadb/bin/mysqldump
DB_USER=root
DB_USER_PWD=

# Recognized Actions and Modes
DB_ACTIONS=(start stop log shell dump init restore help)

## HELPERS ##

## Start a Database Server
__db_start_server() {
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
    local conf="${CONTAINERDIR}/mariadb/${container}.conf"
    local envfile="${CONTAINERDIR}/mariadb/.env.${mode}"

    # Create Container Volume
    volume_create "${container}"

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
-- SHOW DATABASES;
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
-- SHOW DATABASES;
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
  echo "$DOCKERCMD > ${output}"
  $DOCKERCMD > ${output}
}

__db_restore_database() {
  # PARAMETERS
  local container=$1 # Container
  local db=$2        # Database to Restore
  local file=$3      # Relative File Name

  # Full DUMP File Name
  local input=${DB_DUMPSDIR}/$file # Input File Name

  ## Initialize Docker Command
  DOCKERCMD="docker exec -i ${container} ${MYSQL} -u ${DB_USER}"

  # Do we have a User Password Set?
  if [ ! -z ${DB_USER_PWD} ]; then # YES: Add User Password
    DOCKERCMD="${DOCKERCMD} --password=\"${DB_USER_PWD}\""
  fi

  # Add Database Name to Dump
  DOCKERCMD="${DOCKERCMD} ${db}"

  # Execute the Command
  echo "cat ${input} | $DOCKERCMD"
  cat ${input} | $DOCKERCMD
}

__db_init_database() {
  # PARAMETERS
  local container=$1 # Container
  local db=$2        # Database to Restore

  # Initial Schema and Startup Data File
  local schema="${DB_INITDIR}/schema.sql"
  local startup="${DB_INITDIR}/startup-data.sql"

  ## Initialize Docker Command
  DOCKERCMD="docker exec -i ${container} ${MYSQL} -u ${DB_USER}"

  # Do we have a User Password Set?
  if [ ! -z ${DB_USER_PWD} ]; then # YES: Add User Password
    DOCKERCMD="${DOCKERCMD} --password=\"${DB_USER_PWD}\""
  fi

  # Add Database Name to Dump
  DOCKERCMD="${DOCKERCMD} ${db}"

  # Execute the Command
  echo "cat ${schema} | $DOCKERCMD"
  cat ${schema} | $DOCKERCMD
  echo "cat ${startup} | $DOCKERCMD"
  cat ${startup} | $DOCKERCMD
}

__db_init_container() {
  # INPUTS
  local mode=$1      # mode
  local container=$2 # Container Name

  local src="${SOURCEDIR}/mariadb"
  local confdir="${CONTAINERDIR}/mariadb"

  # Does Configuration Directory Exist
  if [ ! -d "${confdir}" ]; then # No: Create it
    mkdir -p "${confdir}"
  fi

  # Configuration Files
  local conf="${container}.conf"
  local envfile=".env.${mode}"

  # Configuration file exists?
  if [ -f "${src}/${conf}" ]; then # Yes: Copy it over
    cp -a "${src}/${conf}" "${confdir}/${conf}"
  fi

  # Environment file exists?
  if [ -f "${src}/${envfile}" ]; then # Yes: Copy it over
    cp -a "${src}/${envfile}" "${confdir}/${envfile}"
  fi
}

__db_parameter_db() {
  # PARAM $1 - Database
  local db=${1:-"vault"}
  echo $db
}

__db_parameter_mode_and_db() {
  # PARAM $1 - MODE or Database
  # PARAM $2 - Database

  case "$#" in
    0)
      echo "$(parameter_mode) $(__db_parameter_db)"
    ;;
    1)
      # Is Parameter MODE?
      in_list $1 "${MODES[@]}"
      local index=$?
      if [[ $index == 0 ]]; then # NO: Is Database
        echo "$(parameter_mode) $1"
      else # YES: is Mode
        echo "$1 $(__db_parameter_db)"
      fi
    ;;
    *)
      echo "$(parameter_mode $1) $(__db_parameter_db $2)"
    ;;
  esac
}

__db_parameter_dump() {
  # PARAM $1 - Database
  local dump=${1:-"dump.sql"}
  echo $dump
}

## COMMANDS ##

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
      __db_start_server $image "ov-db-debug" $1
      ;;
    single) # NOT Debug: Single Shard Server
      __db_start_server $image "ov-db-s1" $1
      ;;
    cluster) # NOT Debug: Dual Shard Server
      __db_start_server $image "ov-db-d1"$1
      __db_start_server $image "ov-db-d2" $1
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
      stop_container "ov-db-debug"
      ;;
    single) # NOT Debug: Single Shard Server
      stop_container "ov-db-s1"
      ;;
    cluster) # NOT Debug: Dual Shard Server
      stop_container "ov-db-d1"&
      stop_container "ov-db-d2" &
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
      logs_container "ov-db-debug"
      ;;
    single) # NOT Debug: Single Shard Server
      logs_container "ov-db-s1"
      ;;
    cluster) # NOT Debug: Dual Shard Server
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
      docker exec -it "ov-db-debug" /bin/bash
      ;;
    single) # NOT Debug: Single Shard Server
      docker exec -it "ov-db-s1" /bin/bash
      ;;
    cluster) # NOT Debug: Dual Shard Server
      echo "Can't Attach to more than one server"
      ;;
  esac
}

## Initialize Database
db_init() {
  # PARAM $1 - MODE
  # PARAM $2 - DATABASE

  # Action Execution State
  echo "Working Mode    [$1]"
  echo "Initializing DB [$2]"

  # STEP 1: Make sure Container Stopped
  db_stop "$1"

  # STEP 2: Make sure Container Directory Exists and is Populated
  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      __db_init_container  "$1" "ov-db-debug"
      ;;
    single) # NOT Debug: Single Shard Server
      __db_init_container  "$1" "ov-db-s1"
      ;;
    cluster) # NOT Debug: Dual Shard Server
      # Initialize SHARD 1
      __db_init_container  "$1" "ov-db-d1"
      # Initialize SHARD 2
      __db_init_container  "$1" "ov-db-d2"
      ;;
  esac

  # STEP 3: Restart the DB Server
  db_start "$1"

  # STEP 4: Create and Initialize Database
  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      __db_drop_database    "ov-db-debug" "$2"
      __db_create_database  "ov-db-debug" "$2"
      __db_init_database    "ov-db-debug" "$2"
      ;;
    single) # NOT Debug: Single Shard Server
      __db_drop_database    "ov-db-s1" "$2"
      __db_create_database  "ov-db-s1" "$2"
      __db_init_database    "ov-db-s1" "$2"
      ;;
    cluster) # NOT Debug: Dual Shard Server
      # Initialize SHARD 1
      __db_drop_database    "ov-db-d1" "$2"
      __db_create_database  "ov-db-d1" "$2"
      __db_init_database    "ov-db-d1" "$2"
      # Initialize SHARD 2
      __db_drop_database    "ov-db-d2" "$2"
      __db_create_database  "ov-db-d2" "$2"
      __db_init_database    "ov-db-d2" "$2"
      ;;
  esac
}

## Dump Database
db_export() {
  # PARAM $1 - MODE
  # PARAM $2 - DATABASE

  # Action Execution State
  echo "Working Mode [$1]"
  echo "Dump DB      [$2]"

  # Make sure Database Server Started
  db_start "$1"

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      __db_dump_database "ov-db-debug" "$2"
      ;;
    single) # NOT Debug: Single Shard Server
      __db_dump_database "ov-db-s1" "$2"
      ;;
    cluster) # NOT Debug: Dual Shard Server
      __db_dump_database "ov-db-d1""$2"
      __db_dump_database "ov-db-d2" "$2"
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

  # Make sure Database Server Started
  db_start "$1"

  # Options based on Mode
  case "$1" in
    debug) # Debug DB Server
      __db_drop_database    "ov-db-debug" "$2"
      __db_create_database  "ov-db-debug" "$2"
      __db_restore_database "ov-db-debug" "$2" "$3"
      ;;
    single) # NOT Debug: Single Shard Server
      __db_drop_database    "ov-db-s1" "$2"
      __db_create_database  "ov-db-s1" "$2"
      __db_restore_database "ov-db-s1" "$2" "$3"
      ;;
    cluster) # NOT Debug: Dual Shard Server
      echo "Can't Restore Dump to more than one server"
      ;;
  esac
}

## Display DB Help
db_usage() {
  # PARAM $1 - Main Executable Script
  echo "Usage: $1 db [start|stop|log|shell]             {debug|single|dual}" >&2
  echo "       $1 db [init|export]                      {debug|single|dual} {database}" >&2
  echo "       $1 db [restore]              [dump_file] {debug|single|dual} {database}" >&2
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
  echo "  debug   - Local Debug Model [DEFAULT]"
  echo "  single  - Single shard Mode"
  echo "  cluster - Dual shard Mode"
  echo >&2
  echo "Examples:" >&2
  echo >&2
  echo "$1 db start --- Start Container in [DEBUG] mode" >&2
  echo "$1 db stop single --- Stop Container in [SINGLE] mode" >&2
  echo "$1 db init vault2 --- Initialize database [vault2]" >&2
  echo "$1 db export --- Dump default database [vault]" >&2
  echo "$1 db restore ov-debug-db-vault2-20220924-092700.hex.sql vault3 --- Restore dump to database [vault3]" >&2
  exit 3
}

## Execute Container Command
db_command() {
  # PARAM $1 - Main Executable Script
  # PARAM $2 - Action
  # PARAM $3, $4, $5 - per action parameters

  # Action to Execute
  case "$2" in
    start)
      # Start Container(s)
      local mode=$(parameter_mode $3)
      db_start ${mode}

      ## List Running Containers
      docker container ls
      ;;
    stop)
      # Stop Container(s)
      local mode=$(parameter_mode $3)
      db_stop ${mode}

      ## List Running Containers
      docker container ls
      ;;
    log)
      # Display Container Logs
      local mode=$(parameter_mode $3)
      db_log ${mode}
      ;;
    shell)
      # Execute a Shell in a Container
      local mode=$(parameter_mode $3)
      db_shell ${mode}
      ;;
    init)
      # Initialize Database
      local params=$(__db_parameter_mode_and_db ${@:3})
      db_init ${params}
      ;;
    export)
      # Dump Database
      local params=$(__db_parameter_mode_and_db ${@:3})
      db_export ${params}
      ;;
    restore)
      # Restore Database
      local dump=$(__db_parameter_dump $3)
      local params=$(__db_parameter_mode_and_db ${@:4})
      db_restore ${params} ${dump}
      ;;
    *)
      db_usage "$1"
      ;;
  esac
}
