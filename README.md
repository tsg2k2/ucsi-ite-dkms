# ucsi-ite-dkms

A DKMS package for **`ucsi_ite`**, the UCSI I2C transport driver for the **ITE885x** USB-C/PD controllers (`ITE8853`, `ITE8800`–`ITE8805`) found on recent ASUS desktop boards.

Without this driver the controller has no Linux driver, and `/sys/class/typec/` stays empty. With it you get `typec` ports, partner and cable identity, the PD source capabilities under `/sys/class/usb_power_delivery/`, and Thunderbolt/USB4 alt-mode hookup.

Power delivery works either way, because the controller negotiates in its own firmware. The driver only makes that state visible to Linux.

## Upstream status

The driver is from Edward Blair's series *"Add ITE885x UCSI I2C transport driver"* (v3, 2026-08-29, linux-acpi / linux-usb). As of v7.3-rc4 it is **not merged**. The original patches are in [`upstream/`](upstream/), and `src/ucsi_ite.c` is byte-identical to patch 2/2.

Once a kernel you run ships `ucsi_ite` in-tree, **uninstall this package**. DKMS installs into `updates/`, which takes priority over the in-tree module.

### Patch 1/2 is not included

Patch 1/2 changes `drivers/acpi/scan.c` so that the `MSFT8000` resource-hub proxy stops claiming the ITE controller's I2C address. That is a core kernel change, so DKMS can't ship it. You only need it if binding fails with `-EBUSY`. Check whether the ITE device got an I2C client:

```sh
ls /sys/bus/i2c/devices/ | grep ITE    # e.g. i2c-ITE8853:00  -> patch 1 not needed
```

On boards where the ITE and `MSFT8000` nodes have distinct I2C addresses in the DSDT, it registers fine without the patch.

## Supported kernels

The driver includes the UCSI core's *private* header `drivers/usb/typec/ucsi/ucsi.h`. Its struct layouts, `struct ucsi_operations` in particular, change between kernel series, so building against the wrong copy produces a module that loads and then misbehaves. For that reason the package ships an exact copy for each series:

| Series | Header source | Tested |
|---|---|---|
| 7.2 | `v7.2.6` (identical to `v7.2`) | ASUS ProArt X870E-Creator WIFI, `ITE8853`, 7.2.6 |
| 7.3 | `v7.3-rc4` | build only; re-check against 7.3 final |

The build refuses a kernel if:

- no `src/headers/<major>.<minor>/ucsi.h` exists for it, or
- the kernel does not export `ucsi_write_message_out_command`. This catches distro kernels with partial UCSI backports. For example, Ubuntu's 7.0 kernel exports `ucsi_suspend` but has the older `ucsi_operations`, so it matches no upstream header.

`dkms.conf` also sets `BUILD_EXCLUSIVE_KERNEL`, so DKMS skips unsupported kernels instead of failing on them.

**Adding a series:** copy `drivers/usb/typec/ucsi/ucsi.h` from that exact kernel tag into `src/headers/<series>/`, then extend `BUILD_EXCLUSIVE_KERNEL` in `src/dkms.conf`.

## Install

Requires `dkms` and the headers for your kernel.

```sh
./install.sh      # copies src/ to /usr/src/ucsi-ite-<ver>, dkms install, modprobe
./uninstall.sh    # removes all versions
```

On a Secure Boot system, DKMS signs the module with its MOK key (`/var/lib/shim-signed/mok/`), and that key must be enrolled.

To build by hand without DKMS: `make -C src` (use `KVER=` to target another installed kernel).

## Expected log noise

```
ucsi_ite i2c-ITE8853:00: UCSI_GET_PDOS failed (-95)
```

The ITE firmware reports UCSI 1.0, which has no `GET_PDOS`. This message is harmless. You may also see a single `-70` (`ECOMM`) variant of the same line on reload, while the controller finishes its reset.

## License

GPL-2.0-only, same as the kernel sources it is taken from. See [`LICENSE`](LICENSE).
