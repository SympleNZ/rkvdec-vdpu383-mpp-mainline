#!/usr/bin/env bash
# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
#
# Build the vendor Rockchip rk_vcodec (MPP) decoder as an out-of-tree module on a
# MAINLINE Linux 7.0 kernel for the RK3576 (VDPU383) — the "MPP-on-mainline" harness.
#
# Run this ON the target board (mainline kernel, with matching kernel headers/source
# at /lib/modules/$(uname -r)/build), from the repository root:
#
#     ./build.sh
#
# It assembles a build/ directory from:
#   vendor/   — pristine Rockchip MPP kernel driver (GPL-2.0+ OR MIT), unmodified
#   compat/   — our authored mainline-port glue (compat shim, stub headers, Makefile)
# then applies a small, transparent set of mainline-7.0 API-drift patches (pure
# compile-compat — NO change to decode behaviour) and builds. Output: build/rk_vcodec.ko
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BUILD="$HERE/build"
KDIR="${KDIR:-/lib/modules/$(uname -r)/build}"

echo "=== assemble (vendor + compat) ==="
rm -rf "$BUILD"; mkdir -p "$BUILD/hack" "$BUILD/compat_include"
cp "$HERE"/vendor/*.c "$HERE"/vendor/*.h "$BUILD/"
cp "$HERE"/vendor/hack/* "$BUILD/hack/"
cp -r "$HERE"/vendor/compat_include/* "$BUILD/compat_include/"   # Rockchip BSP soc/rockchip + uapi headers
cp "$HERE"/compat/bsp_compat_shim.h "$HERE"/compat/Makefile "$BUILD/"
cp -r "$HERE"/compat/compat_include/* "$BUILD/compat_include/"   # our linux/ stubs + soc/rockchip/rockchip_sip.h

echo "=== force the two shadowed-but-config-on BSP headers to their stub branch ==="
sed -i 's/#if IS_REACHABLE(CONFIG_ROCKCHIP_IOMMU)/#if 0 \/* OOT: force stub *\//' "$BUILD/compat_include/soc/rockchip/rockchip_iommu.h"
sed -i 's/#if IS_REACHABLE(CONFIG_ROCKCHIP_PM_DOMAINS)/#if 0 \/* OOT: force stub *\//' "$BUILD/compat_include/soc/rockchip/pm_domains.h"

echo "=== mainline-7.0 API-drift patches (compile-compat only; no decode-behaviour change) ==="
python3 - "$BUILD" <<'PY'
import sys, pathlib
oot = pathlib.Path(sys.argv[1])
def patch(rel, subs):
    p = oot/rel; s = p.read_text(encoding='utf-8', errors='surrogateescape')
    for old,new in subs:
        assert old in s, f"NOT FOUND in {rel}: {old[:60]!r}"
        s = s.replace(old,new,1)
    p.write_text(s, encoding='utf-8', errors='surrogateescape'); print("patched", rel)
patch("mpp_service.c", [
  ("class_create(THIS_MODULE, MPP_CLASS_NAME)", "class_create(MPP_CLASS_NAME)/*mainline:1-arg*/"),
  ("MODULE_IMPORT_NS(DMA_BUF);", 'MODULE_IMPORT_NS("DMA_BUF");/*mainline:string*/'),
  ("static int mpp_service_remove(struct platform_device *pdev)",
   "static void mpp_service_remove(struct platform_device *pdev)/*mainline:void*/"),
  ("\treturn 0;\n}\n\nstatic const struct of_device_id mpp_dt_ids[]",
   "\treturn;\n}\n\nstatic const struct of_device_id mpp_dt_ids[]"),
])
patch("mpp_common.c", [(a, a.replace("f.file","fd_file(f)")) for a in
  ("!f.file", "session = f.file->private_data;", "if (f.file->private_data == session)")])
patch("mpp_rkvdec2.c", [
  ("static int rkvdec2_remove(struct platform_device *pdev)",
   "static void rkvdec2_remove(struct platform_device *pdev)/*mainline:void*/"),
  ("\treturn 0;\n}\n\nstatic void rkvdec2_shutdown(struct platform_device *pdev)",
   "\treturn;\n}\n\nstatic void rkvdec2_shutdown(struct platform_device *pdev)"),
  ("sram_size, IOMMU_READ | IOMMU_WRITE);", "sram_size, IOMMU_READ | IOMMU_WRITE, GFP_KERNEL);"),
  ("page_size, IOMMU_READ | IOMMU_WRITE);", "page_size, IOMMU_READ | IOMMU_WRITE, GFP_KERNEL);"),
  ("min(get_order(page_size), MAX_ORDER)", "min(get_order(page_size), MAX_PAGE_ORDER)"),
  # bisection knob (default off = faithful): skip the rk3576 warmup hack_run
  ("static int rkvdec2_rk3576_init(struct mpp_dev *mpp)",
   "static bool oot_no_warmup;\nmodule_param(oot_no_warmup, bool, 0644);\n"
   "MODULE_PARM_DESC(oot_no_warmup, \"OOT: skip rk3576 warmup hack_run (bisection)\");\n\n"
   "static int rkvdec2_rk3576_init(struct mpp_dev *mpp)"),
])
_p = oot/"mpp_rkvdec2.c"; _s = _p.read_text(encoding='utf-8',errors='surrogateescape')
_s = _s.replace("if (dec->fix && mpp->hw_ops->hack_run)",
                "if (dec->fix && mpp->hw_ops->hack_run && !oot_no_warmup)")
_p.write_text(_s, encoding='utf-8', errors='surrogateescape'); print("gated hack_run sites")
PY

echo "=== build (KBUILD_MODPOST_WARN=1: mainline Module.symvers is empty; exports resolve at insmod) ==="
make -C "$KDIR" M="$BUILD" KBUILD_MODPOST_WARN=1 modules
ls -l "$BUILD/rk_vcodec.ko"
echo
echo "OK: build/rk_vcodec.ko"
echo "Next: ./gate0_setup.sh  (blacklist the V4L2 rkvdec, apply the DT overlay, insmod rk_vcodec)"
