# Installing eSim 2.5 on Ubuntu 25.04

**FOSSEE eSim Winter Internship 2026 · Screening Task 4 · 21 November 2026**

The published eSim 2.5 installer stopped before dependency installation on Ubuntu 25.04. The patch repairs the installer entry point and installs the GUI and analog tools. Validation used a clean Ubuntu 25.04 amd64 Docker environment. The eSim main window opened, KiCad exported a native-format schematic, and ngspice measured 5.000 V in a 10 V resistor divider. The bundled NGHDL installer and legacy RC schematic export still need work.

## Environment and baseline

- **Release** — FOSSEE Linux ZIP named `eSim-2.5.zip`. Its SHA-256 matched FOSSEE's published value, `b9860ae26f026930bae589520761f4a57b85d593a2e2cd1ac83d5e5db2f281ed`.
- **Installer source** — FOSSEE's `installers` branch at `a77d6b904c7bab275d819cf4d8cbb594802fe16d`. The branch supplied the scripts. The official ZIP supplied the application, examples, and libraries.
- **Test system** — Canonical's Ubuntu 25.04 (Plucky Puffin) amd64 container image, digest `sha256:27771fb7b40a58237c98e8d3e6b9ecdd9289cec69a857fccfb85ff36294dac20`. The host was Ubuntu 24.04.5 LTS. The test used a regular account inside the container and ran the GUI through Qt's offscreen platform.
- **Archive check** — Canonical ended support for 25.04 on 15 January 2026. In this test, the image's default Ubuntu APT sources updated successfully. A separate probe against `old-releases.ubuntu.com` returned HTTP 404 for the Plucky suites. The installer leaves APT source configuration to the system administrator. [Canonical end-of-life notice](https://lists.ubuntu.com/archives/ubuntu-announce/2026-January/000320.html)

## Reproduced issues and fixes

| Issue | Evidence on Plucky | Result |
| --- | --- | --- |
| Published ZIP rejects Ubuntu 25.04 | `bash install-eSim.sh --install` printed `Unsupported Ubuntu version: 25.04 ()` and exited 1. The ZIP's dispatcher ended at 24.04. | **Fixed.** The patched entry point reads `VERSION_ID` from `/etc/os-release` and selects the 25.04 script. |
| The branch's dispatcher cannot parse | `bash -n Ubuntu/install-eSim.sh` exited 2 at line 70, near an unexpected `}`. A dispatcher conditional was followed by part of an older installer body. | **Fixed.** The entry point calls the version-specific installer and passes through its exit status. |
| The old HDL parser package fails to build | `python -m pip install --no-build-isolation --no-deps hdlparse==1.0.4` failed under Python 3.13.3 and setuptools 75.8.0 with `use_2to3 is invalid`. The original script redundantly requests HDLParse after installing from GitHub. | **Fixed.** A single commit-pinned GitHub archive builds HDLParse 1.0.7. The installer checks the parser, PyQt5, Matplotlib's Qt backend, psutil, and Watchdog before installing launchers. |
| An existing KiCad 8 installation stops the legacy installer early | When run with KiCad 8.0.8 installed, the original `installKicad` function printed `KiCad 8.0 is already installed.` and exited the entire shell with status 0. A statement after the function never ran. | **Fixed.** A second patched install completed through the Python checks and launchers. The existing KiCad symbol table stayed byte-for-byte identical. |
| Bundled NGHDL rejects Ubuntu 25.04 | The `nghdl.zip` dispatcher printed `Unsupported Ubuntu version: 25.04 ()` and exited 1. Its 24.04 worker tries to compile GHDL 4.1.0 against the system LLVM. Plucky offers `ghdl-llvm` 5.0.1 and both LLVM 19 and 20. | **Open.** The patch installs Ubuntu's ngspice for analog use and reports NGHDL as separate setup. A mixed-signal test is needed before recommending a GHDL/LLVM combination. |
| KiCad 8 fails to export a bundled legacy schematic | `kicad-cli sch export netlist` returned 3 and printed `Failed to load schematic file` for `Examples/RC/RC.sch`, an EESchema version 2 file. Exporting KiCad's packaged Arduino Uno `.kicad_sch` succeeded. | **Open.** The two tests distinguish a working KiCad CLI from compatibility with this bundled legacy project. |
| The eSim welcome panel has a missing local document | The GUI emitted `QTextBrowser: No document for file://…/src/browser/library/browser/welcome.html` while the main window opened. | **Open.** The warning is in the released application's welcome page path. |

Two controls helped rule out misleading causes. APT successfully simulated the legacy `kicad=8.0.8+dfsg-1` pin using Ubuntu's stock archive. The KiCad 8 PPA returned HTTP 200 for its Plucky Release file, so the patch uses Ubuntu packages to reduce the number of repositories involved. The exact original HDLParse GitHub URL also returned HTTP 200 after redirecting to `main`. The reproduced Python failure came from the PyPI 1.0.4 source package.

## Implementation

- **Bash dispatcher** validates the argument, reads the Ubuntu release, and uses `exec` to call the matching installer. It keeps the 22.04, 23.04, and 24.04 routes.
- **Plucky Bash installer** installs Ubuntu's KiCad, ngspice, and Python packages. It creates a Python 3.13 virtual environment with `--system-site-packages` so the application can see Ubuntu's PyQt5 and scientific libraries. It installs only the commit-pinned parser with pip.
- **Python symbol registration** derives the KiCad configuration directory from the installed `kicad-cli` version. It merges the eSim entries into the existing table or the packaged template, preserves existing entries and models, and writes the new table atomically. The installer keeps an existing SKY130 directory.
- **Python smoke test** creates the real eSim main window in an offscreen Qt event loop, exports a KiCad 8 netlist, and checks ngspice against a known circuit. It uses the installed versions rather than mocking dependencies.

The `--install` result covers the main GUI and analog tools. NGHDL co-simulation, Makerchip, and SandPiper need separate setup. Headless tests cover window startup and independent analog tooling. Interactive editing, mixed-signal simulation, and SKY130 model simulation remain outside the verified results. The Plucky `--uninstall` route removes this patch's launchers. APT dependencies, project files, and symbol data remain available for separate review.

## Reproduce the test

Run in a disposable Ubuntu 25.04 amd64 VM or container. Obtain the official ZIP and verify its SHA-256. On the target Ubuntu system, unpack the ZIP as the desktop user who will run eSim. Set `checkout` to the path to the patched eSim Git checkout.

```bash
unzip eSim-2.5.zip
cd eSim-2.5
bash install-eSim.sh --install
# Baseline exits 1 on Ubuntu 25.04.

bash -n "$checkout/Ubuntu/install-eSim.sh"
bash -n "$checkout/Ubuntu/install-eSim-scripts/install-eSim-25.04.sh"
bash "$checkout/Ubuntu/install-eSim.sh" --install

QT_QPA_PLATFORM=offscreen "$HOME/.esim/env/bin/python" \
  "$checkout/Ubuntu/tests/smoke-esim-25.04.py" "$PWD"
```

For the Docker test, the container used the pinned Ubuntu image above and the official ZIP and checkout were made available inside it. Bootstrap packages were `sudo`, `unzip`, `xz-utils`, and `lsb-release`. A container-local test account ran the installer. Rerun the patched command with KiCad already present to check that the full installer still runs and the existing symbol table is unchanged.

## Verification results

```text
Python 3.13.3
PASS GUI: eSim-2.5 on Qt 5.15.15
PASS KiCad 8.0.8: exported the packaged Arduino Uno template
PASS ngspice: v(out) = 5.000 V
PASS launcher, desktop entry, SKY130 model, and 14 eSim symbol registrations
PASS reinstallation continued through dependency checks and preserved the KiCad symbol table
```

The installed `/usr/bin/esim` launcher separately started the application and remained in the event loop until the five-second test timeout. APT installed `kicad` 8.0.8+dfsg-1, `ngspice` 44.2+ds-1, `python3-pyqt5` 5.15.11+dfsg-2, and `python3-matplotlib` 3.8.3-7build1. The installed SKY130 model file was present.

## Git review and references

Review the changed files with `git show --stat HEAD` and the patch with `git show HEAD`. The screening brief names the `installers` branch as the submission target. Its Spoken Tutorial on Git resource covers the checkout, review, and commit workflow.

- [FOSSEE eSim downloads and release checksum](https://esim.fossee.in/downloads)
- [FOSSEE eSim 2.5 release](https://github.com/FOSSEE/eSim/releases/tag/v2.5)
- [Baseline installer branch revision](https://github.com/FOSSEE/eSim/tree/a77d6b904c7bab275d819cf4d8cbb594802fe16d/Ubuntu)
- [HDLParse PyPI source release](https://pypi.org/project/hdlparse/1.0.4/)
- [Pinned HDLParse source](https://github.com/hdl/pyHDLParser/tree/e1153ace8ca1e25f9fb53350c41058ef8eb8dacf)
- [Spoken Tutorial on Git, IIT Bombay](https://spoken-tutorial.org/tutorial-search/?search_foss=Git&search_language=English)
