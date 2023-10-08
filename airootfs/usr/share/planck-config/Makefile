default: compile flash

compile:
	qmk compile -kb planck/ez/glow -km demolinux
	cp ./qmk_firmware/.build/planck_ez_glow_demolinux.bin ./planck_ez_glow.bin
	md5sum ./planck_ez_glow.bin > ./planck_ez_glow.md5

setup:
	qmk setup -H ./qmk_firmware/ zsa/qmk_firmware -b firmware22
	patch -Np1 < ./0001-do-not-turn-on-the-front-leds.patch || :
	ln -sf "$$PWD/src" ./qmk_firmware/keyboards/planck/ez/glow/keymaps/demolinux

flash:
	wally-cli ./planck_ez_glow.bin

.PHONY: default compile setup flash
