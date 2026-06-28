/* SPDX-License-Identifier: (GPL-2.0+ OR MIT) */
/* OOT compat stub. Shared guard with <soc/rockchip/rockchip_sip.h> so whichever
 * is included first wins and the second is a no-op (avoids redefinition).
 *
 * CONFIG_ROCKCHIP_SIP is unset on mainline, so sip_smc_vpu_reset() is only ever
 * reached inside dead `if (IS_REACHABLE(CONFIG_ROCKCHIP_SIP))` branches — the
 * live path falls through to rkvdec2_reset() (register reset incl.
 * rkvdec_vdpu383_reset, the rk3576 path we want). The declaration only needs to
 * exist so those dead branches compile. */
#ifndef __COMPAT_ROCKCHIP_SIP_H
#define __COMPAT_ROCKCHIP_SIP_H
#include <linux/types.h>
static inline int sip_smc_vpu_reset(u32 cfg, u32 arg1, u32 arg2) { return 0; }
#endif /* __COMPAT_ROCKCHIP_SIP_H */
