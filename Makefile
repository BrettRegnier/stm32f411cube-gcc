# STM32 Makefile for GNU toolchain and openocd
#
# This Makefile fetches the Cube firmware package from ST's' website.
# This includes: CMSIS, STM32 HAL, BSPs, USB drivers and examples.
#
# Usage:
#	make cube		Download and unzip Cube firmware
#	make program		Flash the board with OpenOCD
#	make openocd		Start OpenOCD
#	make debug		Start GDB and attach to OpenOCD
#	make dirs		Create subdirs like obj, ${DEP_DIR}, ..
#	make template		Prepare a simple example project in this dir
#
# Copyright	2015 Steffen Vogel
# License	http://www.gnu.org/licenses/gpl.txt GNU Public License
# Author	Steffen Vogel <post@steffenvogel.de>
# Link		http://www.steffenvogel.de
#
# edited for the STM32F4-Discovery

# A name common to all output files (elf, map, hex, bin, lst)
TARGET     = ${BUILD_DIR}/${BIN}/program

# Take a look into $(CUBE_DIR)/Drivers/BSP for available BSPs
# name needed in upper case and lower case
BOARD      = STM32F411E-Discovery
BOARD_UC   = STM32F411E-Discovery
BOARD_LC   = stm32f411e_discovery
BSP_BASE   = $(BOARD_LC)

OCDFLAGS   = -f interface/stlink-v2.cfg -f target/stm32f4x.cfg
GDBFLAGS   =

#EXAMPLE   = Templates
EXAMPLE    = Examples/GPIO/GPIO_EXTI

# MCU family and type in various capitalizations o_O
MCU_FAMILY = stm32f4xx
MCU_LC     = stm32f411xe
MCU_MC     = STM32F411xE
MCU_UC     = STM32F411VE

# path of the ld-file inside the example directories
LDFILE     = $(EXAMPLE)/SW4STM32/$(BOARD_UC)/$(MCU_UC)Tx_FLASH.ld
LDFILE_DIR = ${CONFIG_DIR}/$(MCU_LC).ld
#LDFILE     = $(EXAMPLE)/TrueSTUDIO/$(BOARD_UC)/$(MCU_UC)_FLASH.ld

# Your C++ files from the /src directory
SRCS_CC	   =

# Your C files from the /src directory
SRCS_C      = main.c
SRCS_C     += system_$(MCU_FAMILY).c
SRCS_C     += stm32f4xx_it.c

# Basic HAL libraries
SRCS_C     += stm32f4xx_hal_rcc.c stm32f4xx_hal_rcc_ex.c stm32f4xx_hal.c stm32f4xx_hal_cortex.c stm32f4xx_hal_gpio.c stm32f4xx_hal_pwr_ex.c $(BSP_BASE).c

# Directories
OCD_DIR    = /usr/share/openocd/scripts

CUBE_GIT   = STM32CubeF4
CUBE_DIR   = ${CONTRIB_DIR}/cube_f4

BSP_DIR    = $(CUBE_DIR)/Drivers/BSP/$(BOARD_UC)
HAL_DIR    = $(CUBE_DIR)/Drivers/STM32F4xx_HAL_Driver
CMSIS_DIR  = $(CUBE_DIR)/Drivers/CMSIS

DEV_DIR    = $(CMSIS_DIR)/Device/ST/STM32F4xx

STM_GIT_URL= https://github.com/STMicroelectronics/
CUBE_GIT   = STM32CubeF4
CUBE_URL   = ${STM_GIT_URL}/${CUBE_GIT}

# that's it, no need to change anything below this line!

###############################################################################
# Toolchain

PREFIX     = arm-none-eabi
CC         = $(PREFIX)-g++
AR         = $(PREFIX)-ar
OBJCOPY    = $(PREFIX)-objcopy
OBJDUMP    = $(PREFIX)-objdump
SIZE       = $(PREFIX)-size
GDB        = $(PREFIX)-gdb

OCD        = openocd

###############################################################################
# Options

# Defines
DEFS       = -D$(MCU_MC) -DUSE_HAL_DRIVER

# Debug specific definitions for semihosting
DEFS       += -DUSE_DBPRINTF

# Include search paths (-I)
INCS       = -Isrc
INCS      += -Iinc
INCS      += -I$(BSP_DIR)
INCS      += -I$(CMSIS_DIR)/Include
INCS      += -I$(DEV_DIR)/Include
INCS      += -I$(HAL_DIR)/Inc

# Library search paths
LIBS       = -L$(CMSIS_DIR)/Lib

# Compiler flags
CFLAGS     = -Wall -g -std=c++17 -Os
CFLAGS    += -mlittle-endian -mcpu=cortex-m4 -march=armv7e-m -mthumb
CFLAGS    += -mfpu=fpv4-sp-d16 -mfloat-abi=hard
CFLAGS    += -ffunction-sections -fdata-sections
CFLAGS    += $(INCS) $(DEFS)

# Linker flags
LDFLAGS    = -Wl,--gc-sections -Wl,-Map=$(TARGET).map $(LIBS) -Tconfig/$(MCU_LC).ld

# Enable Semihosting
LDFLAGS   += --specs=rdimon.specs -lc -lrdimon

# Source search paths
VPATH      = ./src
VPATH     += $(BSP_DIR)
VPATH     += $(HAL_DIR)/Src
VPATH     += $(DEV_DIR)/Source/

BUILD_DIR  = build
OBJ        = obj
OBJ_DIR    = ${BUILD_DIR}/${OBJ}
DEP        = dep
DEP_DIR    = ${BUILD_DIR}/${DEP}
BIN 	   = bin
BIN_DIR    = ${BUILD_DIR}/${BIN}
CONTRIB	   = contrib
CONTRIB_DIR= ${CONTRIB}
CONFIG_DIR = config

OBJS_C     = $(addprefix ${OBJ_DIR}/,$(SRCS_C:.c=.o))
OBJS_CC    = $(addprefix ${OBJ_DIR}/,$(SRCS_CC:.cc=.o))
OBJS       = ${OBJS_C} ${OBJS_CC}
DEPS_C     = $(addprefix ${BUILD_DIR}/${DEP}/,$(SRCS_C:.c=.d))
DEPS_CC    = $(addprefix ${BUILD_DIR}/${DEP}/,$(SRCS_CC:.cc=.d))
DEPS       = ${DEPS_C} ${DEPS_CC}

# Prettify output
V = 0
ifeq ($V, 0)
	Q = @
	P = > /dev/null
endif

###################################################

.PHONY: all dirs program debug template clean

all: $(TARGET).bin

-include $(DEPS)

dirs: ${DEP_DIR} ${OBJ_DIR} ${BIN_DIR}
${DEP_DIR} ${OBJ_DIR} ${BIN_DIR} ${CONTRIB_DIR} ${CONFIG_DIR} src inc:
	@echo "[MKDIR]   $@"
	$Qmkdir -p $@

${OBJ_DIR}/%.o : %.c | dirs
	@echo "[C]       $(notdir $<)"
	$Q$(CC) $(CFLAGS) -c -o $@ $< -MMD -MF ${DEP_DIR}/$(*F).d

${OBJ_DIR}/%.o : %.cc | dirs
	@echo "[CC]      $(notdir $<)"
	$Q$(CC) $(CFLAGS) -c -o $@ $< -MMD -MF ${DEP_DIR}/$(*F).d

$(TARGET).elf: $(OBJS)
	@echo "[LD]      $(TARGET).elf"
	$Q$(CC) $(CFLAGS) $(LDFLAGS) config/startup_$(MCU_LC).s $^ -o $@
	@echo "[OBJDUMP] $(TARGET).lst"
	$Q$(OBJDUMP) -St $(TARGET).elf >$(TARGET).lst
	@echo "[SIZE]    $(TARGET).elf"
	$(SIZE) $(TARGET).elf

$(TARGET).bin: $(TARGET).elf
	@echo "[OBJCOPY] $(TARGET).bin"
	$Q$(OBJCOPY) -O binary $< $@

openocd:
	$(OCD) $(OCDFLAGS)

program: all
	$(OCD) $(OCDFLAGS) -c "program $(TARGET).elf verify reset"

debug:
	@if ! nc -z localhost 3333; then \
		echo "\n\t[Error] OpenOCD is not running! Start it with: 'make openocd'\n"; exit 1; \
	else \
		$(GDB)  -ex "target extended localhost:3333" \
			-ex "monitor arm semihosting enable" \
			-ex "monitor reset halt" \
			-ex "load" \
			-ex "monitor reset init" \
			$(GDBFLAGS) $(TARGET).elf; \
	fi

cube: ${CONTRIB_DIR}
	if [ -d "./$(CUBE_DIR)" ] ; then \
		cd $(CUBE_DIR) && git pull ; \
	else \
		git clone $(CUBE_URL) ; \
		mv ${CUBE_GIT} ${CUBE_DIR} ; \
	fi

	chmod -R u+w $(CUBE_DIR)

template: cube src inc ${CONFIG_DIR}
	cp -ri $(CUBE_DIR)/Projects/$(BOARD)/$(EXAMPLE)/Src/* src
	cp -ri $(CUBE_DIR)/Projects/$(BOARD)/$(EXAMPLE)/Inc/* inc
	cp -i $(DEV_DIR)/Source/Templates/gcc/startup_$(MCU_LC).s config/
	cp -i $(CUBE_DIR)/Projects/$(BOARD)/$(LDFILE) ${LDFILE_DIR}

clean:
	@echo "[RM]      Cleaning build files..."
	@echo "[RMDIR]   ${BUILD_DIR}" ; rm -fr ${BUILD_DIR}

