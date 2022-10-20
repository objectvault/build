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

## GITHUB ObjectVault Project BASE URL
GITHUB_OV_URL="https://github.com/objectvault"

## DOCKER Settings

# IMAGES
RABBITMQ="rabbitmq:3.11-management-alpine"
MARIADB="bitnami/mariadb:10.9"

# BUILD Directory
BUILDDIR="${BASEDIR}/builds"

# CONTAINERS Directory for Container Data and Configuration
CONTAINERDIR="${BASEDIR}/containers"

# CONTAINERS Source Directory for Container Configuration
SOURCEDIR="${BASEDIR}/sources"

# NETWORKS
# Backend Network BUS
NET_BACKEND="net-ov-backend"
NETWORKS="net-ov-backend"

## MariaDB Container
# DIR for Dumps
DB_DUMPSDIR="${BASEDIR}/dumps"
# DIR for DB Schema
DB_INITDIR="${BASEDIR}/init/mariadb"

## RabbitMQ Container
# DIR for Dumps
MQ_DUMPSDIR="${BASEDIR}/dumps"
