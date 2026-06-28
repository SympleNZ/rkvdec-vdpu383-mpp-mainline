# rkvdec-vdpu383-mpp-mainline — vendor MPP decoder on a mainline kernel (RK3576 / VDPU383)

A small, self-contained recipe to build Rockchip's vendor **MPP decoder**
(`rk_vcodec` — `mpp_service` + `mpp_rkvdec2` + the RK3576 warmup) as an
**out-of-tree module on a MAINLINE Linux 7.0 kernel**, driving the **RK3576**
SoC's **VDPU383** video IP.

It exists for one decisive reason. It is the **same-silicon control** that proved
the mainline **V4L2 stateless AV1 and VP9** decode failures on this hardware are
**driver bugs, not silicon** — and it is, as a by-product, a **bit-exact-correct
AV1 / VP9 / H.264 / H.265 decode path on a mainline kernel today**, while the V4L2
drivers are fixed.

> **The result.** On the *same* mainline 7.0 kernel, the *same* device tree, the
> *same* platform (clocks / power / IOMMU) and the *same* board where the mainline
> [V4L2 AV1](https://github.com/SympleNZ/rkvdec-vdpu383-av1) and
> [V4L2 VP9](https://github.com/SympleNZ/rkvdec-vdpu383-vp9) drivers decode
> **wrong**, this OOT build of the vendor MPP driver decodes **bit-exact**:

| Codec | MPP-on-BSP (6.1) | **MPP-on-mainline (7.0, this build)** | independent software |
|---|---|---|---|
| AV1 (39 frames) | `ca5876b5` | **`ca5876b5`** | `ca5876b5` (dav1d) |
| VP9 INTER (60 frames) | `7fb9bc0b` | **`7fb9bc0b`** | `7fb9bc0b` (libvpx) |

Three independent decoders agree bit-exactly. Since the *only* variable between
this build (correct) and the mainline V4L2 drivers (wrong) is the **driver code**
— identical kernel, DT, platform and silicon — the V4L2 AV1/VP9 defects are
software-reachable, not a silicon limitation. This overturned a long-standing
"below-MMIO silicon" conclusion. (The residual in the V4L2 drivers was then
narrowed to *below the V4L2 interface* — see the two sibling repos.)

This is published **downstream-first**: a reproducible proof and a working decode
path, not a maintained product. It is **not** upstream and is not a substitute for
the in-progress mainline V4L2 effort.

---

## What this is (and is not)

- **Is:** a thin **port recipe**. Rockchip's MPP kernel driver is GPL-2.0+ /
  MIT and already public; this repo adds only the glue needed to build and bind it
  on a mainline 7.0 kernel — a forced-include compat shim, a handful of stub
  headers, a Kbuild `Makefile`, a device-tree overlay, a bring-up script, and a
  small, transparent set of mainline-API-drift source patches.
- **Is not:** a fork of MPP, a maintained component, or an upstream submission. It
  takes no feature requests and tracks no other SoC. The vendor source under
  `vendor/` is a **pinned, pristine snapshot**, unmodified on disk; every change
  is applied visibly at build time by `build.sh`.

## Repository layout

```
vendor/                 Pristine Rockchip MPP kernel driver (GPL-2.0+ OR MIT), unmodified:
                        mpp_service.c, mpp_common.c, mpp_iommu.c, mpp_rkvdec2.c,
                        mpp_rkvdec2_link.c, hack/mpp_hack_rk3576.* (the RK3576 warmup),
                        headers, and the BSP soc/rockchip + uapi headers it needs.
compat/                 Our authored mainline-port glue (GPL-2.0):
                        bsp_compat_shim.h  — forced-include; dodges the BSP devfreq
                                             cluster, forces the RK3576 paths, stubs the
                                             BSP-only pmu-idle / QoS / SiP symbols.
                        Makefile           — Kbuild for rk_vcodec.ko.
                        compat_include/    — stub headers (dma-buf-cache.h, rockchip_sip.h).
build.sh                Assemble vendor+compat, apply the mainline-7.0 API-drift patches
                        (shown in full in the script), build rk_vcodec.ko. Run on-target.
rk3576-mpp-rkvdec.dts   Device-tree overlay: re-points the rkvdec node at the MPP driver
                        and adds the mpp-service subtree (so MPP binds, not the V4L2 driver).
gate0_setup.sh          Unbind the mainline V4L2 rkvdec, apply the overlay, insmod (on-target).
```

## How the port works (what mainline needed)

The decode datapath — `mpp_write` register programming, dma-buf → IOVA import,
`RKVDEC_START_EN`, IRQ reap, and the `mpp_service` char-device ABI — is generic
and ports **verbatim**, so unmodified userspace MPP (`mpi_dec_test` /
`librockchip_mpp`) runs against it unchanged. The only work is platform glue:

1. **Compat shim** (`compat/bsp_compat_shim.h`, forced-include): `#undef
   CONFIG_PM_DEVFREQ` so the driver's own `#else` stubs eliminate the BSP devfreq /
   IPA / system-monitor / dmc cluster; force `CONFIG_CPU_RK3576`; define the
   `ROCKCHIP_MPP_*` feature gates so the decoder sub-driver actually binds; and
   provide no-op/equivalent stubs for the BSP-only `rockchip_pmu_idle_request`,
   QoS save/restore, and SiP symbols that have no mainline equivalent.
2. **Stub headers** (`compat/compat_include/`): `dma-buf-cache.h` and
   `rockchip_sip.h`, plus forcing the BSP `soc/rockchip` IOMMU / PM-domain headers
   to their stub branch (mainline has those CONFIGs set, so they would otherwise
   declare BSP-only externs).
3. **Mainline-7.0 API-drift patches** (in `build.sh`, applied to a build copy —
   *pure compile-compat, no decode-behaviour change*): `class_create` 1-arg form,
   `MODULE_IMPORT_NS` string form, `platform_driver::remove` → `void`,
   `fd_file()`, the `iommu_map` `GFP_KERNEL` argument, `MAX_ORDER` → `MAX_PAGE_ORDER`.
4. **Device-tree overlay** (`rk3576-mpp-rkvdec.dts`): the mainline DT binds the
   V4L2 `rkvdec` to the decoder node; the overlay re-compatibles it to
   `rockchip,rkv-decoder-rk3576` and adds the `mpp-service` subtree so the MPP
   driver claims the hardware instead.

Nothing in the decode path is altered — that is the whole point: it is the
**vendor driver's own behaviour**, just compiled and bound on mainline.

## Build & run (on the target)

Requires an RK3576 board on a mainline-based 7.0 kernel (developed on Armbian
`7.0.1-edge-rockchip64`, NanoPi R76S / ArmSoM Sige5) with matching kernel
headers/source at `/lib/modules/$(uname -r)/build`.

```sh
./build.sh            # assemble + patch + build  ->  build/rk_vcodec.ko
sudo ./gate0_setup.sh # unbind V4L2 rkvdec, apply the DT overlay, insmod rk_vcodec
```

Then run unmodified userspace MPP against it (e.g. vendor `mpi_dec_test`, or
`librockchip_mpp` via GStreamer's `mpph264dec`/`mppvp9dec` etc.). A reboot
restores the stock mainline V4L2 driver (the overlay is non-persistent).

## Bisection knob

`build.sh` adds one module parameter, `oot_no_warmup` (default `0` = faithful):
set `1` to skip the RK3576 warmup `hack_run`. It is the entry point for *bisecting*
which vendor-specific behaviour the correct decode depends on — the harness's
original purpose. (Stubbing the BSP-only `pmu_idle` left decode correct, so it is
not the differentiator; see the sibling repos' write-ups.)

## Licence & attribution

- **`vendor/`** is Rockchip's MPP kernel driver, **`SPDX: GPL-2.0+ OR MIT`** (their
  headers preserved), from `rockchip-linux/kernel` — redistributed unmodified under
  those terms. All credit for the decoder itself is Rockchip's.
- **Our glue** (`compat/`, `build.sh`, the overlay, scripts) is **GPL-2.0**,
  consistent with the kernel module it produces. See [LICENSE](LICENSE).

Built on Rockchip's `rockchip-linux/mpp` + BSP kernel driver, and on **Detlev
Casanova / Collabora's** mainline VDPU383 `rkvdec` work and device tree (which this
overlay sits on top of). This repo only proves their hardware/driver can be made to
run correctly on mainline — and measures precisely where the mainline V4L2
re-implementation does not yet match it.

## Related

- [`rkvdec-vdpu383-av1`](https://github.com/SympleNZ/rkvdec-vdpu383-av1) — the mainline V4L2 AV1 driver this harness measures against.
- [`rkvdec-vdpu383-vp9`](https://github.com/SympleNZ/rkvdec-vdpu383-vp9) — the mainline V4L2 VP9 driver (production-ready for KEY / single-ref / low-motion).
- [`rkvdec-vdpu383-h264-hevc`](https://github.com/SympleNZ/rkvdec-vdpu383-h264-hevc) — the mainline HEVC/H.264 read-cache throughput fix (7× / 2.4×) this harness's timing comparison surfaced.

Simon Wright, Symple Solutions, Dunedin NZ.
