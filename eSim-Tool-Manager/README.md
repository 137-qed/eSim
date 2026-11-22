# eSim Tool Manager

A Python command-line manager for eSim's external tools on Ubuntu. Inspect what is installed, preview what APT would change, install or upgrade a selected tool, and launch eSim with an explicit tool search path.

This prototype uses Ubuntu's signed APT repositories and the Python standard library. The supported host is Ubuntu with Python 3.10 or newer. Package availability and compatibility depend on the Ubuntu and eSim releases in use.

## Get started

Open a terminal in this directory. Run the manager as your regular user. It invokes `sudo` for package changes and index refreshes when needed.

```bash
python3 -m esim_tools --help
python3 -m esim_tools status
python3 -m esim_tools refresh
python3 -m esim_tools plan install ngspice
python3 -m esim_tools install ngspice
python3 -m esim_tools doctor ngspice
```

Use `install` without tool names to select ngspice and KiCad. Add `--yes` to approve a preview in a non-interactive shell. An interactive run prompts before applying changes. APT or `sudo` may still require system authentication or package configuration.

| Tool ID | APT package | Command checked | Role |
| --- | --- | --- | --- |
| `ngspice` | `ngspice` | `ngspice --version` | SPICE simulation |
| `kicad` | `kicad` | `kicad-cli version` | Schematics and PCB design |
| `ghdl` | `ghdl-llvm` | `ghdl --version` | Standalone VHDL simulation |
| `verilator` | `verilator` | `verilator --version` | Standalone Verilog simulation |

The `ghdl` and `verilator` entries manage standalone simulators. A release-specific eSim NGHDL or NgVeri co-simulation setup needs additional integration. Install eSim itself from FOSSEE's distribution. [FOSSEE eSim](https://github.com/FOSSEE/eSim)

## Version and update workflows

```bash
# Query the local package index and the command that eSim would run.
python3 -m esim_tools status ngspice kicad --json

# Select an exact APT package version. This example uses Ubuntu 24.04's ngspice.
python3 -m esim_tools plan install ngspice --version ngspice=42+ds-3build1
python3 -m esim_tools install ngspice --version ngspice=42+ds-3build1 --yes

# Refresh, discover updates, and apply a targeted upgrade.
python3 -m esim_tools refresh
python3 -m esim_tools updates
python3 -m esim_tools plan upgrade ngspice
python3 -m esim_tools upgrade ngspice --yes

# Check the version floor if your eSim workflow requires KiCad 8 or later.
python3 -m esim_tools doctor kicad --minimum kicad=8.0
```

`status` shows the Debian package version, APT candidate, and executable version separately. An exact version must be available from the configured repositories and its dependencies must resolve. Choose a version suitable for your eSim release. The manager uses Ubuntu's package version comparison, respects holds, and refuses downgrades or removals. APT still decides which dependencies are needed. [Ubuntu apt-get manual](https://manpages.ubuntu.com/manpages/noble/man8/apt-get.8.html) · [Ubuntu dpkg-query manual](https://manpages.ubuntu.com/manpages/noble/man1/dpkg-query.1.html)

`updates` and `upgrade` default to the installed catalogue tools. `refresh` explicitly updates indexes before discovery. A repeated install or upgrade with the target version already present produces `No package changes needed.`

## Launch eSim with a tool path

For an existing installation, configure the launcher and any additional executable directory. Replace the example paths with paths on your system.

```bash
python3 -m esim_tools config show
python3 -m esim_tools config set --launcher /usr/bin/esim --bin-dir "$HOME/.local/bin"
python3 -m esim_tools doctor --esim
python3 -m esim_tools run
python3 -m esim_tools logs -n 10
```

The default launcher is `esim` on PATH. The added directories are prepended only in the launched process and in tool probes. A local binary that shadows an Ubuntu binary is shown in the report. Choose `config set --clear-bin-dirs` to restore the inherited PATH. Use `--profile /path/to/config.json` before a command to work with another profile. Pass eSim arguments after `run --`.

The profile is stored in `$XDG_CONFIG_HOME/esim-tool-manager/config.json` or `~/.config/esim-tool-manager/config.json`. The JSON Lines audit log is stored in `$XDG_STATE_HOME/esim-tool-manager/actions.jsonl` or `~/.local/state/esim-tool-manager/actions.jsonl`. The manager leaves shell startup files and the eSim project workspace untouched.

## Test

```bash
# Unit tests. Ubuntu with Python and dpkg is sufficient.
python3 -m unittest discover -s tests -v

# Live install and upgrade. Docker and an amd64 Ubuntu image are required.
bash tests/live-ubuntu.sh
```

The live test mounts this directory read-only and creates a disposable Ubuntu 24.04 container. It exercises a real APT install and upgrade, a read-only KiCad plan, launch arguments and configured PATH using a fixture, and a real ngspice calculation. It downloads Ubuntu packages including GHDL's compiler dependencies. See [design and verification notes](DESIGN.md).

## Troubleshooting

- **No candidate**. Run `refresh` and check your Ubuntu repositories. For tools published in Universe, confirm that component is enabled in the Ubuntu release you use.
- **Unresolved or held dependency**. Read the APT error and inspect `apt-cache policy PACKAGE` or `dpkg --audit`. Some older exact versions require matching versions of companion packages. Choose a compatible set via your Ubuntu repository policy.
- **Executable missing or unexpectedly resolved**. Compare `status` with `config show`. Edit the launch profile or install the selected Ubuntu package. An independently installed Snap or custom tool can launch through a profile, while its version lifecycle remains outside this APT manager.
- **Exit status**. `doctor` returns 1 when it reports a failed check. Usage and manager errors return 2. `run` forwards eSim's exit code.
