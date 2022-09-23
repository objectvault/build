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

## Start Single Database Server
start_db_server() {
  IMAGE=$1     # Docker Image Name
  CONTAINER=$2 # Container Name

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start an Instance of MariaDB
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/mariadb/${CONTAINER}.conf"
    ENVFILE="${CONTAINERDIR}/mariadb/.env.${MODE}"

    # Create Container Volume
    volume_create "${CONTAINER}"

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm --name ${CONTAINER}"
#    DOCKERCMD="docker run"

    ## Attach Volumes
    DOCKERCMD="${DOCKERCMD} -v ${CONTAINER}:/bitnami/mariadb"
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/opt/bitnami/mariadb/conf/my_custom.cnf:ro"

    # Expose Port so that we can attach from local system (Allows Access to DB)
    DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:3306:3306"

    # Do we have an Environment File
    if [ -f "${ENVFILE}" ]; then  # YES: Use it
      DOCKERCMD="${DOCKERCMD} --env-file ${ENVFILE}"
    fi

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} -d ${IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Network
    connect_container net-ov-storage "${CONTAINER}"
  fi
}

## Start All Database Servers (Depends on Mode)
start_db() {
  IMAGE="${MARIADB}"

  # Make Sure net-ov-storage network exists
  network_create 'net-ov-storage'

  # Options based on Mode
  case "$MODE" in
    debug) # Debug DB Server
      start_db_server $IMAGE "ov-debug-db"
      ;;
    single) # NOT Debug: Single Shard Server
      start_db_server $IMAGE "ov-s1-db"
      ;;
    dual) # NOT Debug: Dual Shard Server
      start_db_server $IMAGE "ov-d1-db"
      start_db_server $IMAGE "ov-d2-db"
      ;;
  esac
}

## Stops All Database Servers (Depends on MODE)
stop_db() {
  # Options based on Mode
  case "$MODE" in
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
logs_db() {
  # Options based on Mode
  case "$MODE" in
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
