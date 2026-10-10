# Corsair Power Mode: Omarchy bar widget

A bar widget for the [Omarchy](https://omarchy.org/) shell, made for the **Corsair AI Workstation 300** (Sixunited AXB35 board, Ryzen AI Max / Strix Halo).

- Shows the EC power mode (Quiet / Balanced / Performance) that the front button sets, plus live APU package power.
- **Left-click** cycles the power mode.
- **Right-click** opens a menu that switches the fans between **Auto** and **Max**.
- The tooltip shows CPU/GPU temperature, GPU clock, fan RPM and the OS power profile.

## Requirements

- The [`ec_su_axb35`](https://github.com/cmetz/ec-su_axb35-linux) kernel driver loaded, so `/sys/class/ec_su_axb35` exists (AUR: `ec-su_axb35-dkms-git`).
- The udev rule in `udev/`, which lets your user write the power mode and fan settings without root.
- `powerprofilesctl` is optional; it only adds the OS power profile to the tooltip.

## Install

```bash
omarchy plugin add https://github.com/iainholder/omarchy-corsair-power --enable

# Helper scripts the widget calls (they must be on PATH)
install -m 755 ~/.config/omarchy/plugins/iain.corsair-power/bin/* ~/.local/bin/

# udev rule for non-root access to the EC
sudo install -m 644 ~/.config/omarchy/plugins/iain.corsair-power/udev/99-ec-su_axb35.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

## Helper scripts

- `corsair-power-status` prints one JSON line with mode, power, temperatures, fan RPM and fan floor.
- `corsair-fans` controls the fans: `auto`, `max`, `toggle`, `status`, or `floor <0-5>` for the in-between levels (not shown in the widget menu).
