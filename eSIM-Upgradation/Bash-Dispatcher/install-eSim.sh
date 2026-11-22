#!/bin/bash
#=============================================================================
#          FILE: install-eSim.sh
# 
#         USAGE: ./install-eSim.sh --install 
#                            OR
#                ./install-eSim.sh --uninstall
#                
#   DESCRIPTION: Installation script for eSim EDA Suite
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#       AUTHORS: Fahim Khan, Rahul Paknikar, Saurabh Bansode,
#                Sumanto Kar, Partha Singha Roy, Jayanth Tatineni,
#                Anshul Verma, Shiva Krishna Sangati, Harsha Narayana P
#  ORGANIZATION: eSim Team, FOSSEE, IIT Bombay
#       CREATED: Sunday 25 May 2025 17:40
#      REVISION: ---
#=============================================================================

set -e

if [[ $# -ne 1 || ( $1 != --install && $1 != --uninstall ) ]]; then
    printf 'Usage: %s --install | --uninstall\n' "$0" >&2
    exit 1
fi

. /etc/os-release
printf 'Detected OS: %s\n' "${PRETTY_NAME:-unknown}"
if [[ ${ID:-} != ubuntu ]]; then
    printf 'This installer requires Ubuntu.\n' >&2
    exit 1
fi

case "${VERSION_ID:-}" in
    22.04)
        if [[ ${VERSION:-} == "22.04.4 "* ]]; then
            installer=install-eSim-22.04.sh
        else
            installer=install-eSim-23.04.sh
        fi
        ;;
    23.04|24.04|25.04)
        installer=install-eSim-${VERSION_ID}.sh
        ;;
    *)
        printf 'Unsupported Ubuntu version: %s\n' "${VERSION_ID:-unknown}" >&2
        exit 1
        ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$script_dir/install-eSim-scripts/$installer" "$1"
