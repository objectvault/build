#!/bin/bash

## Execution SYSTEM
source /etc/os-release

# Are we running the composer on a QNAP system?
SYSTEM="linux"
if [ $ID == "qts" ]; then # YES
  SYSTEM="qnap"
  echo "CURRENT SYSTEM - QNAP"
else
  echo "CURRENT SYSTEM - LINUX"
fi

## Base Script Directory
export BASEDIR="$( cd "$( dirname "$0" )" >/dev/null 2>&1 && pwd )"

## WORKING MODE [DEFAULT: debug]
MODE=${MODE:-"debug"}

## IMAGES
MARIADB="bitnami/mariadb:latest" 
APISERVER="local/ov-api-server"
FESERVER="local/ov-fe-server"

## NETWORKS
NETWORKS="net-ov-storage"

## VOLUMES Directory

# IMPORTANT - QNAP Firmware Updates will clear any paths outside /shares
# this means that, any VOLUMES that are not created using docker volume create
# will disappear a long with any data store in them (therefore any server that 
# requires a permanent store for it's state, i.e. database,needs to have a volume)

# Volumes whose state is not managed by the server
VOLUMESDIR="${BASEDIR}/volumes"

## CONF Directory
CONFDIR="${BASEDIR}/conf"

## DOCKER CONTAINER Environment Properties
MARIADB_ROOT_PASSWORD='rvKTk6xH8bDapzp6G5F9'

## Status Check 
status() {
  # PARAM $1 - type of object volume | container | network
  # PARAM $2 - name of object
  # RETURNS
  # 0 - Object Does not Exist
  # 1 - Object Exists

  # Does Docker Object Exist?
  local s="$(docker $1 ls -f name=$2 -q 2> /dev/null)"
  if [ "$s" == "" ]; then # NO
    return 0
  fi 
  # ELSE: YES
  return 1
}

## Remove Docker Network
network_rm() {
  # PARAM $1 - Network Name
  NETWORK=$1
  
  # Does Network Exists?
  status network "${NETWORK}"
  if [[ $? == 1 ]]; then # YES
    # Remove Existing Networks
    echo "Removing Network '$NETWORK'"
    docker network rm "${NETWORK}"
  fi 
}

## Remove ALL Docker Networks for Application
networks_rm() {
  for network in $(echo $NETWORKS | tr "," " "); do \
    network_rm "${network}"
  done
}

## Create Docker Network
network_create() {
  # PARAM $1 - Network Name
  NETWORK=$1
  
  # Does Network Exists?
  status network "${NETWORK}"
  if [[ $? == 0 ]]; then # NO
    # Set Network Options
    case "${NETWORK}" in
      net-ov-storage) # Internal Only Networks
        ARGS="--internal ${NETWORK}"
      ;;
      *)
        ARGS="${NETWORK}"
      ;;
    esac
    
    # Create
    echo "Creating Network '$NETWORK'"
    docker network create ${ARGS}
  fi
}

## Remove ALL Docker Networks for Application
networks_create() {
  for network in $(echo $NETWORKS | tr "," " "); do \
    network_create "${network}"
  done
}

## Attach Docker Container to Network
connect_container() {
  # PARAM $1 - Network Name
  # PARAM $2 - Container Name
  # PARAM $3 - DNS Alias for Container
  NETWORK=$1
  CONTAINER=$2
  ALIAS=$3

  # is ALIAS Set?
  if [ "${ALIAS}" == "" ]; then # NO: User Container Name as Alias
    ALIAS="${CONTAINER}"
  fi 

  # Attach Container to Network
  docker network connect --alias "${ALIAS}" "${NETWORK}" "${CONTAINER}"
  echo "Connecting [${CONTAINER}] to Network [${NETWORK}] as [${ALIAS}]"
}

## Create Docker Volume
create_volume() {
  # PARAM $1 - Volume Name

  # Does Volume Exists?
  status volume "$1"
  if [[ $? == 0 ]]; then # NO
    echo "Creating Volume '$1'"
    docker volume create $1
  else 
    echo "WARN: Volume '$1' Already Exists"
  fi
}

## See Container Logs
logs_container() {
  # PARAM $1 - Container Name

  ## NOTE: Don't Test for Container Running in the case we wan't to see problems 
  ## with stopped containers
  echo "Logging container '$1'"
  docker logs -f "$1"
}

## Stop Container
stop_container() {
  # PARAM $1 - Container Name

  # Is Container Running?
  status container "$1"
  if [[ $? == 1 ]]; then # YES
    echo "Stopping container '$1'"
    docker stop "$1"
  else # NO
    echo "Container '$1' NOT Running"
  fi 
}

## CONTAINERS: DB ##

## Start Single Database Server
start_db_server() {
  # PARAM $1 - Docker Image Name
  # PARAM $2 - Container Name
  IMAGE=$1
  CONTAINER=$2

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO  
    ## Start an Instance of MariaDB
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONFDIR}/mariadb/${CONTAINER}.conf"

    # Create Container Volume
    create_volume "${CONTAINER}"

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm --name ${CONTAINER}"
#    DOCKERCMD="docker run"

    ## Attach Volumes
    DOCKERCMD="${DOCKERCMD} -v ${CONTAINER}:/bitnami/mariadb"
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/opt/bitnami/mariadb/conf/my_custom.cnf:ro"

    # Expose Port so that we can attach from local system (Allows Access to DB)
    DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:3306:3306"

    # Is Debug? 
    if [ "${MODE}" == "debug" ]; then  # YES: Image OPTIONS
      DOCKERCMD="${DOCKERCMD} -e ALLOW_EMPTY_PASSWORD=yes"
    else # NO: Image OPTIONS
      DOCKERCMD="${DOCKERCMD} -e MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}"
    fi

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} --name ${CONTAINER}"
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

## CONTAINERS: BACK-END Servers ##

## Start Backend API Server
start_api() {
  # Get Parameters
  IMAGE="${APISERVER}"
  CONTAINER=$1

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONFDIR}/api/server.${MODE}.json"

    # Make Sure required networks exist
    network_create 'net-ov-storage'

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm"
#    DOCKERCMD="docker run"

    # Set Server Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/app/server.json:ro"

    # Is Debug DB? 
    if [ "$MODE" == "debug" ]; then  
      # Expose Port so that we can attach from local system
      DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:3000:3000"
    fi

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} --name ${CONTAINER}"
    DOCKERCMD="${DOCKERCMD} -d ${IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container net-ov-storage "${CONTAINER}"
  fi 
}

## CONTAINERS: FRONT-END Servers ##

## Start Frontend Web Server
start_fe() {
  # Get Parameters
  IMAGE="${FESERVER}"
  CONTAINER=$1

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm"
#    DOCKERCMD="docker run"

    # Expose Port so that we can attach from local system
    DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:5000:80"

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} --name ${CONTAINER}"
    DOCKERCMD="${DOCKERCMD} -d ${IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD
  fi 
}

## Start All Application Containers (Depends on MODE)
start_all() {
  ## START All Servers ##
  echo "STAGE-2: Starting Servers"

  # Re-create Networks
  networks_create

  ## Start Data Servers ##
  start_db &

  # Delay 10 Seconds to Allow for Server Initialization
  sleep 10

  ## Start Backend Servers ##
  start_api  ov-api-server &

  # Delay 10 Seconds to Allow for Server Initialization
  sleep 5

  ## Start Frontend Server
  start_fe  ov-fe-server
}

## Stop All Application Containers (Depends on MODE)
stop_all() {
  ## STOP All Servers ##
  echo "Stopping Running Servers"

  # Stop Front-End Server
  stop_container ov-fe-server

  # Stop Back-End Server
  stop_container ov-api-server
  
  # Stop Data-Servers
  stop_db 

  # Delay 10 Seconds to Allow for Complete Stop
  sleep 15

  # Remove Existing Networks
  networks_rm
}

## SHELL COMMAND: Start - On or More Application Containers
start() {
  ## Start
  echo "Starting '$1'"

  case "$1" in
    all)
      start_all
      ;;
    db)
      start_db 
      ;;
    api)
      start_api ov-api-server
      ;;
    fe)
      start_fe ov-fe-server
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
    db)
      stop_db
      ;;
    api)
      stop_container ov-api-server
      ;;
    fe)
      stop_container ov-fe-server
      ;;
    *)
      usage
      ;;
  esac
}

## SHELL COMMAND: Log - Attach to Container Logger
log() {
  case "$1" in
    db)
      logs_db
      ;;
    api)
      logs_container ov-api-server
      ;;
    fe)
      logs_container ov-fe-server
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
    db)
      logs_db
      ;;
    api)
      docker exec -it ov-api-server /bin/ash
      ;;
    fe)
      docker exec -it ov-fe-server /bin/ash
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
  echo "Usage: run {start|stop}  [all|{container}] DEFAULT: all" >&2
  echo "       run log           {container}" >&2
  echo "       run shell         {container}" >&2
  echo "       run networks      rm|create" >&2
  echo "       mode" >&2
  echo >&2
  echo "Containers:"
  echo "  db | api | fe" >&2
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
  start)
    echo "Volumes Directory       [${VOLUMESDIR}]"
    echo "Configuration Directory [${CONFDIR}]"

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
    usage
    ;;
esac
