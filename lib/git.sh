#!/usr/bin/env bash

# GIT Utility Functions
#
# This file is part of the ObjectVault Project.
# Copyright (C) 2020-2022 Paulo Ferreira <vault at sourcenotes.org>
#
# This work is published under the GNU AGPLv3.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

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
