#!/usr/bin/env bash

# Utility Functions
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# Check if a Value Exists in List
in_list() {
  local key=$1  # Value to Search for
  local list=$2 # List of Values

  # Initialize Counter
  local index=0 # Initialize Counter

  # Loop through List
  for k in $list; do
    # Does KEY match?
    if [ "$k" = "$key" ]; then # YES: Return Index
      return $index
    fi

    # Increment Counter
    index=$((index+1))
  done

  # No Match
  return 0
}

in_list_or_default() {
  local default=$3

  # Is Item in List?
  local index=$(in_list $1 $2)
  if [[ $MODEI == 0 ]]; then # NO: Return Default
    echo "${default}"
  fi
  # ELSE: Return Value
  echo $1
}
