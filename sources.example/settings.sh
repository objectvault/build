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

## GITHUB ObjectVault Project BASE URL
GITHUB_OV_URL="https://github.com/objectvault"

## IMAGES
RABBITMQ="rabbitmq:management-alpine"
MARIADB="bitnami/mariadb:latest"

## BUILD Directory
BUILDDIR="${BASEDIR}/builds"

## CONTAINERS Directory for Container Data and Configuration
CONTAINERDIR="${BASEDIR}/containers"

## CONTAINERS Source Directory for Container Configuration
SOURCEDIR="${BASEDIR}/sources"

## NETWORKS
NETWORKS="net-ov-storage"

## DATABASE Related settings
DB_DUMPSDIR="${BASEDIR}/dumps"
DB_SCHEMADIR="${BASEDIR}/init"
