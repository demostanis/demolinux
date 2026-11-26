default: compile flash

compile:
	qmk compile -kb planck/ez/glow -km demolinux
	cp ./qmk_firmware/.build/planck_ez_glow_demolinux.bin ./planck_ez_glow.bin
	md5sum ./planck_ez_glow.bin > ./planck_ez_glow.md5

setup:
	qmk setup -H ./qmk_firmware/ zsa/qmk_firmware -b firmware22
	@set -e; for p in 0001-do-not-turn-on-the-front-leds.patch 0002-support-python-3.14.patch; do \
		if ! patch --dry-run -Rfp1 < "$$p" >/dev/null; then patch -Nfp1 < "$$p"; fi; \
	done
	ln -sfnT "$$PWD/src" ./qmk_firmware/keyboards/planck/ez/glow/keymaps/demolinux

flash:
	wally-cli ./planck_ez_glow.bin

.PHONY: default compile setup flash
