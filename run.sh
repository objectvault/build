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

## Display Usage
usage() {
  echo "Usage: $0 {container|all} {action} [params...] " >&2
  echo "       $0 help" >&2
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
  exit 1
}

# Display Default Working Mode
case "$MODE" in
  debug|single|cluster)
    mode "${MODE}"
    ;;
  *)
    usage
esac

# Does Module Exist?
MODULE=$1
if [ -f ./lib/module/${MODULE}.sh ]; then # YES
  # Include Module Source
  source ./lib/module/${MODULE}.sh

  # Does Module Runner Exist?
  RUNNER="${MODULE}_command"
  if [[ $(type -t ${RUNNER}) == function ]]; then # YES
    $RUNNER $0 ${@:2}
  else # NO: Not a Module
    usage
  fi
else # NO: Display Usage
  usage
fi
