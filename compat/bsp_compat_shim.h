/* SPDX-License-Identifier: (GPL-2.0+ OR MIT) */
/*
 * bsp_compat_shim.h — forced-include for the OOT MPP-on-mainline build.
 *
 * Purpose: build the vendor rk_vcodec (mpp_service + mpp_rkvdec2 + _link + the
 * rk3576 warmup hack) against mainline 7.0 as a bisection harness. See
 * docs/rk3576/MPP_ON_MAINLINE_PORT_PROGRESS_2026-06-27.md.
 *
 * This file is injected first into every mpp TU via `-include`. It runs AFTER
 * the kernel autoconf, so #undef here overrides the running kernel's config for
 * these TUs only.
 */
#ifndef __BSP_COMPAT_SHIM_H
#define __BSP_COMPAT_SHIM_H

/*
 * Blocker group 4 — dodge the BSP devfreq cluster entirely. With this undef the
 * driver's own `#ifdef CONFIG_PM_DEVFREQ ... #else <stubs>` paths take the stub
 * branch, eliminating every rockchip_init_opp_table / rockchip_system_monitor_* /
 * rockchip_dmcfreq_* reference (BSP-only soc/rockchip symbols absent on mainline).
 * Correctness-neutral: fixed clocks, and clock *rates* are already proven
 * correctness-neutral (LEVER_CAMPAIGN_RESULTS_2026-06-27).
 */
#ifdef CONFIG_PM_DEVFREQ
#undef CONFIG_PM_DEVFREQ
#endif

/* Force the rk3576 code paths (warmup hack, rkvdec2 obj) — mainline has CPU_RK3576 unset. */
#ifndef CONFIG_CPU_RK3576
#define CONFIG_CPU_RK3576 1
#endif

/*
 * We build the .o files directly (bypassing the BSP Kconfig), so the driver's own
 * IS_ENABLED(CONFIG_ROCKCHIP_MPP_*) feature gates are all FALSE by default. In particular
 * mpp_service.c only registers the rkvdec2 sub-driver when HAS_RKVDEC2 ==
 * IS_ENABLED(CONFIG_ROCKCHIP_MPP_RKVDEC2). Define it so the decoder node actually binds.
 */
#ifndef CONFIG_ROCKCHIP_MPP_SERVICE
#define CONFIG_ROCKCHIP_MPP_SERVICE 1
#endif
#ifndef CONFIG_ROCKCHIP_MPP_RKVDEC2
#define CONFIG_ROCKCHIP_MPP_RKVDEC2 1
#endif

/*
 * Blocker group 2 — pmu_idle. Mainline's own soc/rockchip/pm_domains.h shadows our
 * compat copy (LINUXINCLUDE precedes ccflags -I) and does NOT declare this BSP-only
 * symbol. Provide a BUILD stub here so the module links.
 *
 * !! FAITHFULNESS: a no-op == the `rockchip,skip-pmu-idle-request` bisection config.
 * Before the decode-comparison run, replace this with the real handshake ported from
 * BSP drivers/soc/rockchip/pm_domains.c, else a "wrong output" baseline proves nothing.
 */
#include <linux/types.h>
struct device;
static inline int rockchip_pmu_idle_request(struct device *dev, bool idle) { return 0; }

/*
 * rockchip_save_qos / rockchip_restore_qos — BSP-only, declared in the (shadowed)
 * BSP pm_domains.h, absent on mainline. They BRACKET the reset call in the link path
 * (mpp_rkvdec2_link.c rkvdec2_soft_reset). Like pmu_idle, faithfulness-relevant: the
 * real bodies save/restore the device's QoS priority registers across reset. BUILD
 * stubs here; port faithfully (or treat as an explicit bisection lever) before trusting
 * a "wrong output" baseline.
 */
static inline int rockchip_save_qos(struct device *dev) { return 0; }
static inline int rockchip_restore_qos(struct device *dev) { return 0; }

#endif /* __BSP_COMPAT_SHIM_H */
