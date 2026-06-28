/* SPDX-License-Identifier: (GPL-2.0+ OR MIT) */
/* OOT compat stub. CONFIG_DMABUF_CACHE is unset on mainline, so the cached-attach
 * paths are IS_ENABLED()-dead-stripped and mpp_iommu.c uses the standard dma-buf
 * API. This header only needs to resolve the include and pull in the real API. */
#ifndef __COMPAT_DMA_BUF_CACHE_H
#define __COMPAT_DMA_BUF_CACHE_H
#include <linux/dma-buf.h>
#endif /* __COMPAT_DMA_BUF_CACHE_H */
