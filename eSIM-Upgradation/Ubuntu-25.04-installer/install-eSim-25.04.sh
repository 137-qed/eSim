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
#                Sumanto Kar, Partha Singha Roy, Harsha Narayana P, 
#                Jayanth Tatineni, Anshul Verma
#  ORGANIZATION: eSim Team, FOSSEE, IIT Bombay
#       CREATED: Wednesday 15 July 2015 15:26
#      REVISION: Sunday 25 May 2025 17:40
#=============================================================================

set -euo pipefail

config_dir="$HOME/.esim"
symbol_dir=/usr/share/kicad/symbols
pdk_dir=/usr/share/local/sky130_fd_pr
release_dir=$PWD
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
hdlparse_url=https://codeload.github.com/hdl/pyHDLParser/tar.gz/e1153ace8ca1e25f9fb53350c41058ef8eb8dacf

register_kicad_symbols() {
    local kicad_version config_home
    kicad_version=$(kicad-cli version)
    if [[ ! $kicad_version =~ ^([0-9]+\.[0-9]+) ]]; then
        printf 'Could not determine the KiCad configuration version: %s\n' "$kicad_version" >&2
        return 1
    fi
    config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
    /usr/bin/python3 "$script_dir/register-plucky-symbols.py" \
        "$config_home/kicad/${BASH_REMATCH[1]}/sym-lib-table" \
        /usr/share/kicad/template/sym-lib-table "$symbol_dir" "$1"
}

install_esim() {
    if (( EUID == 0 )); then
        printf 'Run as the desktop user. APT will request sudo as needed.\n' >&2
        return 1
    fi
    if [[ ! -f "$release_dir/VERSION" || $(<"$release_dir/VERSION") != 2.5 ||
          ! -f "$release_dir/src/frontEnd/Application.py" ||
          ! -f "$release_dir/library/kicadLibrary.tar.xz" ||
          ! -f "$release_dir/library/sky130_fd_pr.tar.xz" ]]; then
        printf 'Run from the extracted FOSSEE eSim 2.5 ZIP directory.\n' >&2
        return 1
    fi

    # Plucky ships KiCad 8 and Qt bindings for its system Python.
    sudo apt-get -o APT::Update::Error-Mode=any update
    sudo apt-get install -y --no-install-recommends \
        ca-certificates kicad kicad-footprints kicad-symbols kicad-templates \
        ngspice python3-venv python3-setuptools python3-wheel python3-pyqt5 \
        python3-matplotlib python3-psutil python3-watchdog xterm xz-utils

    mkdir -p -- "$config_dir"
    /usr/bin/python3 -m venv --system-site-packages "$config_dir/env"
    "$config_dir/env/bin/python" -m pip install --no-build-isolation --no-deps "$hdlparse_url"
    "$config_dir/env/bin/python" -c 'from PyQt5 import QtCore, QtWidgets; from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg; import hdlparse.verilog_parser, psutil, watchdog; print("eSim Python dependencies import successfully")'

    install_dir=$(mktemp -d)
    trap 'rm -rf -- "$install_dir"' EXIT
    tar -xJf "$release_dir/library/kicadLibrary.tar.xz" -C "$install_dir"
    libraries=("$install_dir/kicadLibrary/eSim-symbols/"eSim_*.kicad_sym)
    for library in "${libraries[@]}"; do
        name=${library##*/}
        # Keep user-edited eSim libraries and leave KiCad's stock libraries alone.
        if [[ ! -e "$symbol_dir/$name" ]]; then
            sudo install -o "$(id -u)" -g "$(id -g)" -m 0644 -- "$library" "$symbol_dir/$name"
        fi
    done
    register_kicad_symbols "$install_dir/kicadLibrary/eSim-symbols"

    if [[ ! -e "$pdk_dir" ]]; then
        tar -xJf "$release_dir/library/sky130_fd_pr.tar.xz" -C "$install_dir"
        sudo install -d /usr/share/local
        sudo mv -- "$install_dir/sky130_fd_pr" "$pdk_dir"
    fi

    cat > "$config_dir/config.ini" <<EOF
[eSim]
eSim_HOME = $release_dir
LICENSE = %(eSim_HOME)s/LICENSE
KicadLib = %(eSim_HOME)s/library/kicadLibrary.tar.xz
IMAGES = %(eSim_HOME)s/images
VERSION = %(eSim_HOME)s/VERSION
MODELICA_MAP_JSON = %(eSim_HOME)s/library/ngspicetoModelica/Mapping.json
EOF

    install -m 0644 -- "$release_dir/images/logo.png" "$config_dir/logo.png"
    {
        printf '#!/usr/bin/env bash\n# FOSSEE eSim 2.5 Plucky launcher\n'
        printf 'set -e\ncd -- %q\n' "$release_dir/src/frontEnd"
        printf 'export PATH=%q:"$PATH"\n' "$config_dir/env/bin"
        printf 'exec %q Application.py "$@"\n' "$config_dir/env/bin/python"
    } > "$install_dir/esim"
    cat > "$install_dir/esim.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=eSim
Exec=esim
Icon=$config_dir/logo.png
Terminal=false
Categories=Development;Electronics;
EOF
    sudo install -m 0755 -- "$install_dir/esim" /usr/bin/esim
    sudo install -m 0644 -- "$install_dir/esim.desktop" /usr/share/applications/esim.desktop

    printf 'eSim 2.5 GUI and analog tools installed. Launch with esim.\n'
    printf 'NGHDL mixed-signal simulation and Makerchip/SandPiper require separate setup.\n'
}

case "${1:-}" in
    --install)
        install_esim
        ;;
    --uninstall)
        # Remove the launchers installed here. The application tree, user
        # settings, and system dependencies can also be used independently.
        if [[ -f /usr/bin/esim ]] && grep -Fxq '# FOSSEE eSim 2.5 Plucky launcher' /usr/bin/esim; then
            sudo rm -f -- /usr/bin/esim /usr/share/applications/esim.desktop
            printf 'Removed the eSim launchers. Project and dependency files are available for review.\n'
        fi
        ;;
    *)
        printf 'Usage: %s --install | --uninstall\n' "$0" >&2
        exit 1
        ;;
esac
