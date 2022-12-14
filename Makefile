# OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
# Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
# SPDX-License-Identifier: GPL-3.0-only

# Prerequisites:
# To build, you will need 64tass and GNU Make.
# If you wish to build an image with CBM BASIC, you will need a ROM image.
# You may also want either wget or curl (for fetching ROMs).

64TASS	?= 64tass

# Default target.
# Load at $c000, includes a simple shell.
always: bin/C256jr.bin

# OpenKERNAL bundled with CBM BASIC V2 (you supply the ROM).
# Load at $a000, boots to BASIC.
cbmjr:	cbm/C256jr.bin

clean:
	rm -f bin/*.bin cbm/*.bin
	
deepclean: clean
	find . -name "*~" -exec rm {} \;
	find . -name "*#" -exec rm {} \;


COPT = -I . -C -Wall -Werror -Wno-shadow -x --verbose-list

####### Kernal ###########################################

CORE	= \
	core/kernel.asm \
	core/iec.asm \
	core/io.asm \
	core/dev.asm \
	core/dev_screen.asm \
	core/dev_keyboard.asm \
	core/rtc.asm \
	core/sys.asm \
	core/keyboard.asm \
	core/video.asm \
	core/device.asm \
	core/token.asm \
	core/keyboard.asm \
	core/vectors.asm \
	core/cli.asm \
	core/cli_list.asm \
	core/cli_load.asm \

####### C256jr ##################################################

C256JR	= \
	platform/jr/jr.asm \
	platform/jr/iec.asm \
	platform/jr/irq.asm \
	platform/jr/ps2.asm \
	platform/jr/console.asm \
	platform/jr/c64kbd.asm \
	platform/jr/FPGA/TinyVicky_Def.asm \
	platform/jr/FPGA/interrupt_def.asm \
	hardware/hardware.asm \
	hardware/i8042.asm \
	hardware/ps2.asm \
	hardware/ps2_kbd2.asm \
	hardware/keys.asm \

# Make a KERNAL for the C256jr.  The .bin should be loaded at $c000.

bin/C256jr.bin: Makefile $(CORE) $(C256JR)
	@echo Building the kernel
	64tass $(COPT) $(filter %.asm, $^) -b -L $(basename $@).lst -o $@
	@echo


# Build an uploadable CBM BASIC .bin file for use on the C256 Foenix Jr.
# The .bin will contain OpenKERNAL and a user-provided CBM BASIC ROM.
# The .bin should be loaded at $a000.
# Note: roms/cbm_patched.bin is used to import the floating point fix.
# See https://www.c64-wiki.com/wiki/Multiply_bug

cbm/C256jr.bin: util/bundle_cbm_jr.asm bin/C256jr.bin roms/cbm_patched.bin
	@echo Bundling the kernel with CBM BASIC V2.
	64tass  -b $< -I . \
		-D kernel=\"$(filter bin/%.bin, $^)\" \
		-D basic=\"$(filter roms/%.bin, $^)\" \
		-o $@
	@echo
	@echo $@ built.


####### Rules for fetching a CBM BASIC ROM ####################################

WGET		?= wget
CURL		?= curl 
CBM_BASIC	= 64c.251913-01.bin
CBM_ARCHIVE 	= http://www.zimmers.net/anonftp/pub/cbm/firmware/computers/c64

roms/%.bin:
	@echo
	@echo You must supply your own CBM ROMs.
	@echo Typing \"make curl-cbm\" or \"make wget-cbm\"
	@echo will fetch the default CBM BASIC ROM from 
	@echo $(CMB_ARCHIVE)
	@false
	
wget-cbm: 
	$(WGET) $(CBM_ARCHIVE)/$(CBM_BASIC) -O roms/$(CBM_BASIC)

curl-cbm:
	$(CURL) -L $(CBM_ARCHIVE)/$(CBM_BASIC) >roms/$(CBM_BASIC)

# Patch CBM BASIC V2 to fix the floating-point multiply bug:
# https://www.c64-wiki.com/wiki/Multiply_bug
roms/cbm_patched.bin: util/patch_cbm.asm roms/$(CBM_BASIC)
	@echo Patching CBM BASIC V2 to fix the multiply bug.
	64tass -b $< -I . -D basic=\"$(filter roms/%.bin, $^)\" -o $@
	@echo
