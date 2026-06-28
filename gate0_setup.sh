#!/usr/bin/env bash
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
#
# Bind the vendor MPP (rk_vcodec) decoder to the RK3576 VDPU383 on a mainline 7.0
# kernel: unbind the V4L2 rkvdec, apply the device-tree overlay, insmod rk_vcodec.
# Run ON the target board, AS ROOT, from the repo root, AFTER ./build.sh:
#
#     sudo ./gate0_setup.sh
#
# State is NON-PERSISTENT (overlay + module vanish on reboot) — re-run after each boot.
# A reboot cleanly restores the stock mainline V4L2 driver.
#
# HARD-WON GOTCHAS (do not regress):
#  - Overlay REMOVAL is broken on this kernel (rmdir of the configfs overlay dir wedges
#    configfs in unkillable D-state). NEVER rmdir the overlay. Apply once; reboot to undo.
#  - Do NOT add a fragment that DISABLES the old video-codec node: destroying it triggers a
#    pm_runtime_drop_link WARN in rk_iommu_release_device that rolls back the apply. Instead
#    UNBIND the V4L2 driver first (below); the old node then sits unbound and frees its MMIO.
#  - Write the dtbo with a SINGLE write() — use `cat`, NOT `dd bs=4096` (dd splits it -> EINVAL).
#  - If the board ever wedges, `reboot -f` may NOT recover (device_shutdown blocks on the wedged
#    state). Use sysrq: `echo 1 > /proc/sys/kernel/sysrq; echo b > /proc/sysrq-trigger`.
#    sysrq-b does NOT sync the fs — run `sync` first or lose the freshly built .ko.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
KO="$HERE/build/rk_vcodec.ko"
DTBO=/tmp/mpp-rkvdec.dtbo

[ -f "$KO" ] || { echo "build/rk_vcodec.ko missing — run ./build.sh first"; exit 1; }

echo "=== compile the device-tree overlay ==="
dtc -@ -I dts -O dtb -o "$DTBO" "$HERE/rk3576-mpp-rkvdec.dts"

echo "=== free the decoder HW from the mainline V4L2 driver (idle unbind) ==="
echo 27b00100.video-codec > /sys/bus/platform/drivers/rkvdec/unbind 2>/dev/null || true

echo "=== apply the overlay ONCE (mpp-service + rkvdec node); cat, never dd; never rmdir after ==="
mkdir -p /sys/kernel/config/device-tree/overlays/mpp
cat "$DTBO" > /sys/kernel/config/device-tree/overlays/mpp/dtbo
sleep 1

echo "=== insmod the OOT MPP module -> mpp_service probes, registers rkvdec2, binds the node ==="
insmod "$KO"
sleep 2

echo "=== GATE 0 ==="
ls -l /dev/mpp_service
echo -n "27b00100.rkvdec -> "; readlink /sys/bus/platform/devices/27b00100.rkvdec/driver 2>/dev/null || echo "(not bound — check dmesg)"
cat /sys/bus/platform/devices/27b00100.rkvdec/power/runtime_status 2>/dev/null || true
echo
echo "MPP is now bound. Run unmodified userspace MPP (mpi_dec_test / librockchip_mpp)."
echo "Reboot to restore the stock mainline V4L2 driver."
