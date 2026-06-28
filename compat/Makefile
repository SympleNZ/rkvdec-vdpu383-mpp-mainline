# SPDX-License-Identifier: (GPL-2.0+ OR MIT)
# OOT build of the vendor rk_vcodec MPP decoder on mainline 7.0 (bisection harness).
# Build: make -C /lib/modules/$(uname -r)/build M=$(PWD) modules

obj-m += rk_vcodec.o

rk_vcodec-objs := mpp_service.o mpp_common.o mpp_iommu.o \
                  mpp_rkvdec2.o mpp_rkvdec2_link.o \
                  hack/mpp_hack_rk3576.o

ccflags-y += -I$(src) -I$(src)/compat_include
ccflags-y += -include $(src)/bsp_compat_shim.h
ccflags-y += -DMPP_VERSION=\"oot-mainline-port\"
ccflags-y += -DCONFIG_ROCKCHIP_MPP_SERVICE=1 -DCONFIG_ROCKCHIP_MPP_RKVDEC2=1
# tolerate BSP-vs-mainline style warnings for the first pass; tighten later
ccflags-y += -Wno-error
