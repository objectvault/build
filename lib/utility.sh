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
  ## Example usage
  # inlist "key" "${ARRAY[@]}"
  # inlist "debug" "$MODES[@]"
  ## RETURNS
  # 0  - No match
  # >0 - Index of Match (Not Zero Based)

  local key=$1      # Value to Search for
  local list=${@:2} # List of Values

  #echo "PARAM 1 [$1]"
  #echo "PARAM 2 [${list[@]}]"

  # Initialize Counter
  local index=0 # Initialize Counter

  # Loop through List
  for k in ${list[@]}; do
    # Does KEY match?
    if [ "$k" = "$key" ]; then # YES: Return Index
      return $((index+1))
    fi

    # Increment Counter
    index=$((index+1))
  done

  # No Match
  return 0
}

in_list_or_default() {
  ## Example usage
  # in_list_or_default "key" "${ARRAY[@]}" "default"
  # in_list_or_default $3 "${MODES[@]}" "debug"
  ## RETURNS
  # default - No match in List
  # match   - Matched Value in List

  ## Function Arguments
  local args=("$@")
  local largs=${#args[@]}

  # Params to pass o in_list call
  local params=(${args[@]:0:(($largs - 1))})
  # Default Valut
  local default=${args[*]: -1}

  # Is Item in List?
  in_list "${params[@]}"
  local index=$?
  if [[ $index == 0 ]]; then # NO: Return Default
    echo "${default}"
  else # YES: Return Value
    echo ${params[@]:$index:1}
  fi
}
