#!/bin/bash

## User Configurable RUN Settings
source ./settings.sh

## Get URL for ObjectVault Repository for Specific Release
github_clone_release() {
  # PARAM $1 - Repository
  # PARAM $2 - Github Release Tag
  # RETURNS:
  # 0 - On Cloned
  # 1 - Failed
  local url="${GITHUB_OV_URL}/$1.git"
  local output="${BUILDDIR}/$1"

  # Does Build Directory Exist?
  if [ ! -d "${BUILDDIR}" ]; then # NO: Create it
    mkdir "${BUILDDIR}"
  fi

  # Does Repositry Directory Exist?
  if [ -d "${output}" ]; then # YES: Remove it
    rm -rf "${output}"
  fi

  # Clone a Release or Latest?
  if [[ $# == 1 ]]; then # CLONE: Latest
    git clone -q --depth 1 ${url} ${output}
  else # CLONE: Release
    git clone -q --depth 1 --branch $2 ${url} ${output}
  fi

  # Cloned Repository?
  if [[ $? == 0 ]]; then # YES: Remove .git
    rm -rf ${output}/.git
    return 0
  fi
  # ELSE: Failed to Clone Repository/Release
  return 1
}

build_docker_image() {
  # PARAM $1 - Local Image Source Path
  # PARAM $2 - Docker Image Tag

  # PATH for Image SRC
  IMAGEPATH="${BUILDDIR}/$1"

  # Build Docker Image
  docker build --tag "$2" "${IMAGEPATH}/."
}

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
volume_create() {
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

## Delete Docker Volume
volume_rm() {
  # PARAM $1 - Volume Name

  # Does Volume Exists?
  status volume "$1"
  if [[ $? != 0 ]]; then # YES
    echo "Removing Volume '$1'"
    docker volume rm $1
  else
    echo "INFO: Volume '$1' Does not exist"
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

## CONTAINER: RabbitMQ ##

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

    # Make Sure the Volume Exists
    volume_create "${CONTAINER}"

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm --name ${CONTAINER}"
#    DOCKERCMD="docker run"

    # SET Environment File (Used to Initialize Administration User)
    DOCKERCMD="${DOCKERCMD} --env-file ${CONF}/.env"

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

## CONTAINER: MariaDB Server ##

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

## CONTAINER: BACK-END API Server ##

## Build Docker Image for API Server
build_api() {
  REPO="api-services"
  VERSION="v0.0.1"
  IMAGE="ov-api-server"

  # Stage Image from GITHUB
  github_clone_release "${REPO}" "${VERSION}"

  # Build Docker Image
  build_docker_image "${REPO}" "local/${IMAGE}:${VERSION}"
}

## Start Backend API Server
start_api() {
  # PARAM $1 - Container Name
  CONTAINER=$1

  # Docker Image
  IMAGE="ov-api-server"
  VERSION="v0.0.1"
  DOCKER_IMAGE="local/${IMAGE}:${VERSION}"

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/api/server.${MODE}.json"

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
    DOCKERCMD="${DOCKERCMD} -d ${DOCKER_IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container net-ov-storage "${CONTAINER}"
  fi
}

## CONTAINER: Node Queue Processor ##

## Build Docker Image for Queue Email Sender (Node Version)
build_processor_node() {
  REPO="queue-node-processor"
  VERSION="v0.0.2"
  IMAGE="ov-queue-processor"

  # Stage Image from GITHUB
  github_clone_release "${REPO}" "${VERSION}"

  # Build Docker Image
  build_docker_image "${REPO}" "local/${IMAGE}:${VERSION}"

  # Does Configuration Directory Exist?
  SRC="${SOURCEDIR}/${IMAGE}"
  if [ -d "${SRC}" ]; then # YES

    # Does Configuration Work Directory Exist?
    CONF="${CONTAINERDIR}/${IMAGE}"
    if [ -d "${CONF}" ]; then # YES: Remove it
      rm -rf "${CONF}"
    fi

    # Recreate Configuration Directory
    mkdir -p "${CONF}"

    # Copy Source Onfirguration to Container
    cp -r "${SRC}/." "$CONF"
  fi
}

start_processor_node() {
  # PARAM $1 - Container Name
  CONTAINER=$1

  # Docker Image
  IMAGE="ov-queue-processor"
  VERSION="v0.0.2"
  DOCKER_IMAGE="local/${IMAGE}:${VERSION}"

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/${IMAGE}/app.config.${MODE}.json"
    MIXINS="${CONTAINERDIR}/${IMAGE}/mixins.${MODE}"
    TEMPLATES="${CONTAINERDIR}/${IMAGE}/templates.${MODE}"

    # Make Sure required networks exist
    network_create 'net-ov-storage'

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm --name ${CONTAINER}"
#    DOCKERCMD="docker run"

    # Set Server Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${MIXINS}:/app/mixins:ro"
    DOCKERCMD="${DOCKERCMD} -v ${TEMPLATES}:/app/templates:ro"
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/app/app.config.json:ro"

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} -d ${DOCKER_IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container net-ov-storage "${CONTAINER}"
  fi
}

## CONTAINER: FRONT-END Servers ##

## Build Docker Image for Frontend Web Server
build_fe() {
  REPO="frontend"
  VERSION="v0.0.1"
  IMAGE="ov-fe-server"

  # Stage Image from GITHUB
  github_clone_release "${REPO}" "${VERSION}"

  # Build Docker Image
  build_docker_image "${REPO}" "local/${IMAGE}:${VERSION}"
}

## Start Frontend Web Server
start_fe() {
  # PARAM $1 - Container Name
  CONTAINER=$1

  # Docker Image
  IMAGE="ov-fe-server"
  VERSION="v0.0.1"
  DOCKER_IMAGE="local/${IMAGE}:${VERSION}"

  # Is Container Running?
  status container "$CONTAINER"
  if [[ $? == 0 ]]; then # NO
    ## Start Mongo
    echo "Running container '$CONTAINER'"

    # Custom Configuration File
    CONF="${CONTAINERDIR}/fe/config.${MODE}.js"

    # Make Sure required networks exist
    network_create 'net-ov-storage'

    ## Initialize Docker Command
    DOCKERCMD="docker run --rm"
#    DOCKERCMD="docker run"

    # Set Backend Configuration File
    DOCKERCMD="${DOCKERCMD} -v ${CONF}:/usr/share/nginx/html/assets/config.js:ro"

    # Expose Port so that we can attach from local system
    DOCKERCMD="${DOCKERCMD} -p 127.0.0.1:5000:80"

    # Add Image Name
    DOCKERCMD="${DOCKERCMD} --name ${CONTAINER}"
    DOCKERCMD="${DOCKERCMD} -d ${DOCKER_IMAGE}"

    # Execute the Command
    echo $DOCKERCMD
    $DOCKERCMD

    # Attach to Storage Backplane Network
    connect_container net-ov-storage "${CONTAINER}"
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
  stop_db  &

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
      start_db
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
      stop_db
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
      logs_db
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
    usage
    ;;
esac
