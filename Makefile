OMAHA_RO = $(shell find omaha/root_overlay/ -type f)
VERSION ?= microserver
export KDIR ?= omaha/kernel

%.img.bz2: %.img
	bzip2 -kfp $<
	@echo
	touch $@

parallella.img: stage3-armv7a_hardfp-latest.tar.bz2 stage4/boot/parallella.bit.bin stage4/boot/uImage stage4/boot/devicetree.dtb $(STAGE4)
	./.gfwrapper.sh $@ $< stage4 || rm -f $@

omaha.img: stage3-armv7a_hardfp-latest.tar.bz2 omaha.kpart /lib/firmware/mrvl/sd8797_uapsta.bin $(OMAHA_RO)
	./.gfomaha.sh $@ $< omaha/root_overlay || rm -f $@

stage4/boot/parallella.bit.bin: parallella_e16_$(VERSION)_gpiose_7010.bit.bin
	@test -d stage4/boot || mkdir -p stage4/boot
	cp $< $@

stage4/boot/devicetree.dtb: zynq-parallella-$(VERSION).dtb
	@test -d stage4/boot || mkdir -p stage4/boot
	cp $< $@

stage3-armv7a_hardfp-latest.tar.bz2:
	export getpath=$$(wget -q -O- https://distfiles.gentoo.org/releases/arm/autobuilds/latest-stage3-armv7a_hardfp-systemd.txt | awk 'NR==3{print$$1}'); \
	wget -c http://distfiles.gentoo.org/releases/arm/autobuilds/$$getpath; \
	ln -s $$(basename $$getpath) $@

kernel.itb: omaha/kernel.its $(KDIR)/arch/arm/boot/zImage $(wildcard $(KDIR)/arch/arm/boot/dts/*.dtb)
	cp -v $< $(KDIR)/kernel.its
	mkimage -f $(KDIR)/kernel.its $@

omaha.kpart: kernel.itb cmdline
	vbutil_kernel \
		--version 1 \
		--pack $@ \
		--arch arm \
		--keyblock /usr/share/vboot/devkeys/kernel.keyblock \
		--signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk \
		--config cmdline \
		--vmlinuz $< \
		--bootloader cmdline

cmdline:
	tee $@ <<<"console=tty1 verbose root=/dev/sda4 rootwait ro init=/sbin/init"
