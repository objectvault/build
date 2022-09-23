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

## Initialize RabbitMQ Container
build_rabbitmq() {
  IMAGE=$1     # Docker Image Name
  CONTAINER=$2 # Container Name

  echo "BUILD Container '$CONTAINER'"

  ## STEP 1 : Stop Container
  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? != 0 ]]; then # YES
    echo "Container '$CONTAINER' is being stopped"
    stop_container "$CONTAINER"
  fi

  ## STEP 2 : Remove ANY Existing Volumes
  volume_rm "${CONTAINER}"

  ## STEP 3 : Initialize Configuration

  # Does Configuration Directory Exist
  SRC="${SOURCEDIR}/rabbitmq/${CONTAINER}"
  CONF="${CONTAINERDIR}/rabbitmq/${CONTAINER}"
  if [ -d "${CONF}" ]; then # YES: Remove it
    rm -rf "${CONF}"
  fi

  # Recreate Configuration Directory
  mkdir -p "${CONF}"

  # Copy Source Onfirguration to Container
  cp -r "${SRC}/." "$CONF"

  ## STEP 4 : Initialize Container

  ## Initialize Docker Command
  DOCKERCMD="docker run --rm --name ${CONTAINER}"

  # SET Environment File (Used to Initialize Administration User)
  DOCKERCMD="${DOCKERCMD} --env-file ${SRC}/.env"

  # SET Volumes
  DOCKERCMD="${DOCKERCMD} -v ${CONTAINER}:/var/lib/rabbitmq"
  DOCKERCMD="${DOCKERCMD} -v ${CONF}/conf:/etc/rabbitmq:ro"

  # Add Image Name
  DOCKERCMD="${DOCKERCMD} -d ${IMAGE}"

  # Execute the Command
  echo $DOCKERCMD
  $DOCKERCMD

  # Wait for Container to Stabilize and the stop
  sleep 10
  stop_container ${CONTAINER}
}

## Start Single RabbitMQ Server
start_rabbitmq() {
  IMAGE=$1     # Docker Image Name
  CONTAINER=$2 # Container Name

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Server
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/rabbitmq/${CONTAINER}"
    if [ ! -d "${CONF}" ]; then
      echo "Need to build '${CONTAINER}' before 1st run"
      exit 1;
    fi
    ENVFILE="${CONF}/.env"

    # Make Sure the Volume Exists
    volume_create "${CONTAINER}"

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm --name ${CONTAINER}"
#    DOCKERCMD="docker run"

    # Do we have an Environment File
    if [ -f "${ENVFILE}" ]; then  # YES: Use it
      # SET Environment File (Used to Initialize Administration User)
      DOCKERCMD="${DOCKERCMD} --env-file ${ENVFILE}"
    fi

    # SET Volumes
    DOCKERCMD="${DOCKERCMD} -v ${CONTAINER}:/var/lib/rabbitmq"
    DOCKERCMD="${DOCKERCMD} -v ${CONF}/conf:/etc/rabbitmq:ro"

    # Options based on Mode
    case "$MODE" in
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
    DOCKERCMD="${DOCKERCMD} -d ${IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Network
    connect_container net-ov-storage "${CONTAINER}"
  fi
}

## Initialize RabbitMQ

## Initialize RabbitMQ Container
build_mq() {
  IMAGE="${RABBITMQ}"

  # Options based on Mode
  case "$MODE" in
    debug) # Debug DB Server
      build_rabbitmq $IMAGE "ov-debug-mq"
      ;;
    single) # NOT Debug: Single Shard Server
      build_rabbitmq $IMAGE "ov-s1-mq"
      ;;
    dual) # NOT Debug: Dual Shard Server
      build_rabbitmq $IMAGE "ov-d1-mq"
      build_rabbitmq $IMAGE "ov-d2-mq"
      ;;
  esac
}

## Start All RabbitMQ Servers (Depends on Mode)
start_mq() {
  IMAGE="${RABBITMQ}"

  # Make Sure net-ov-storage network exists
  network_create 'net-ov-storage'

  # Options based on Mode
  case "$MODE" in
    debug) # Debug DB Server
      start_rabbitmq $IMAGE "ov-debug-mq"
      ;;
    single) # NOT Debug: Single Shard Server
      start_rabbitmq $IMAGE "ov-s1-mq"
      ;;
    dual) # NOT Debug: Dual Shard Server
      start_rabbitmq $IMAGE "ov-d1-mq"
      start_rabbitmq $IMAGE "ov-d2-mq"
      ;;
  esac
}

## Stops All RabbitMQ Servers (Depends on MODE)
stop_mq() {
  # Options based on Mode
  case "$MODE" in
    debug) # Debug DB Server
      stop_container "ov-debug-mq"
      ;;
    single) # NOT Debug: Single Shard Server
      stop_container "ov-s1-mq"
      ;;
    dual) # NOT Debug: Dual Shard Server
      stop_container "ov-d1-mq" &
      stop_container "ov-d2-mq" &
      ;;
  esac
}

## Attach Logger to RabbitMQ Container
logs_rabbitmq() {
  # Options based on Mode
  case "$MODE" in
    debug) # Debug DB Server
      logs_container "ov-debug-mq"
      ;;
    single) # NOT Debug: Single Shard Server
      logs_container "ov-s1-mq"
      ;;
    dual) # NOT Debug: Dual Shard Server
      echo "Can't Log more than one server"
      ;;
  esac
}
