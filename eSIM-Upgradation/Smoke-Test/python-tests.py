#!/usr/bin/env python3
"""Exercise a native eSim 2.5 installation on Ubuntu 25.04 without a display."""

import argparse
import importlib
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def check_gui(release):
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PyQt5 import QtCore, QtWidgets

    frontend = release / "src/frontEnd"
    previous_directory = Path.cwd()
    os.chdir(frontend)
    sys.path.insert(0, str(frontend))
    try:
        module = importlib.import_module("Application")
        qt = QtWidgets.QApplication(["eSim-smoke"])
        window = module.Application()
        QtCore.QTimer.singleShot(100, qt.quit)
        status = qt.exec_()
        if status or window.windowTitle() != "eSim-2.5":
            raise RuntimeError(f"eSim main window did not start: {window.windowTitle()}")
        print(f"PASS GUI: {window.windowTitle()} on Qt {QtCore.QT_VERSION_STR}")
        window.hide()
    finally:
        os.chdir(previous_directory)
        sys.path.remove(str(frontend))


def check_kicad(scratch):
    output = scratch / "arduino-uno.net"
    schematic = Path("/usr/share/kicad/template/Arduino_Uno/Arduino_Uno.kicad_sch")
    version = subprocess.check_output(["kicad-cli", "version"], text=True).strip()
    subprocess.run(
        ["kicad-cli", "sch", "export", "netlist", "-o", str(output), str(schematic)],
        check=True,
    )
    if not output.is_file() or "(components" not in output.read_text():
        raise RuntimeError("KiCad produced no component netlist for its Arduino Uno template.")
    print(f"PASS KiCad {version}: exported the packaged Arduino Uno template")


def check_ngspice(scratch):
    circuit = scratch / "divider.cir"
    circuit.write_text(
        "10 V resistor divider\n"
        "V1 in 0 10\nR1 in out 1k\nR2 out 0 1k\n"
        ".control\nop\nprint v(out)\nquit\n.endc\n.end\n"
    )
    result = subprocess.run(
        ["ngspice", "-b", str(circuit)], check=True, text=True, capture_output=True
    )
    output = re.search(r"v\(out\)\s*=\s*([0-9.eE+-]+)", result.stdout)
    if not output or not math.isclose(float(output[1]), 5.0, rel_tol=1e-6):
        raise RuntimeError(f"Expected a 5 V operating point.\n{result.stdout}\n{result.stderr}")
    print(f"PASS ngspice: v(out) = {float(output[1]):.3f} V")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release", type=Path, help="the unpacked eSim 2.5 ZIP")
    release = parser.parse_args().release.resolve()

    print(f"Python {sys.version.split()[0]}")
    check_gui(release)
    with tempfile.TemporaryDirectory() as directory:
        scratch = Path(directory)
        check_kicad(scratch)
        check_ngspice(scratch)


if __name__ == "__main__":
    main()
