/* SPDX-License-Identifier: (GPL-2.0+ OR MIT) */
/* OOT compat stub — see <linux/rockchip/rockchip_sip.h>. Shared include guard. */
#ifndef __COMPAT_ROCKCHIP_SIP_H
#define __COMPAT_ROCKCHIP_SIP_H
#include <linux/types.h>
static inline int sip_smc_vpu_reset(u32 cfg, u32 arg1, u32 arg2) { return 0; }
#endif /* __COMPAT_ROCKCHIP_SIP_H */
