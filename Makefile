.PHONY: all build x11 x11_close run shell nios2_shell quartus_altmalloc quartus compile clean simulation


# set your project name
MAC_ADDRESS := 00:0C:29:XX:XX:XX
LICENSE_FILE := LR-09999_License.dat
PROJECT_NAME := aaa
QSYS_FILE := sys.qsys
SVF_VOLTAGE := 3.3
# in Mhz
SVF_FREQ := 12.0

IMAGE_NAME := quartus
QUARTUS_VER := 21.1.1.850
# QUARTUS_VER := 20.1.0.711
SIMULATION_PATH := simulation/modelsim
OUTPUT_PATH := output_files


CONTAINER_PROJ_PATH := /root/$(PROJECT_NAME)
LOCAL_PATH := $(shell pwd)
LOCAL_SHARED_PATH := $(LOCAL_PATH)/shared
CONTAINER_DISPLAY := docker.for.mac.host.internal:0
CONTAINER_NAME := $(IMAGE_NAME)_run_$(PROJECT_NAME)

# use alternative malloc library
ALTMALLOC := n

IMAGE_TAG := $(IMAGE_NAME):$(QUARTUS_VER)
# IMAGE_TAG := b032baf709c4


ifeq ($(shell uname -m), arm64)
# PLATFORM := arm64
PLATFORM := amd64
ifeq ($(JAVA_SMALLER_HEAP),y)
# to avoid tcl init.tcl error
# TODO: no need?
# -XX:-UseSerialGC -XX:+UseConcMarkSweepGC 
# OPT_ADDITIONAL := --memory 6500M --memory-swap -1 -e _JAVA_OPTIONS="-Xint -XX:-TieredCompilation -XX:-Inline -XX:+CMSIncrementalMode -XX:-UseSerialGC -XX:+UseConcMarkSweepGC -verbose:gc -Xms1500M -Xmx1500M"
OPT_ADDITIONAL := --memory 3500M --memory-swap -1 -e _JAVA_OPTIONS="-Xint -verbose:gc -Xms1500M -Xmx1500M"
else
# -XX:-TieredCompilation -XX:-Inline -XX:-UseSerialGC -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC
# disable JIT to prevent getting stuck the container on ARM Mac
OPT_ADDITIONAL := --memory 3500M --memory-swap -1 -e _JAVA_OPTIONS="-Xint -verbose:gc -Xms3000M -Xmx3000M -XX:MaxMetaspaceSize=2000M"
endif
else
PLATFORM := amd64
endif

ifeq ($(ALTMALLOC),y)
	# ifeq ($(PLATFORM), arm64)
	# CONTAINER_LD_PRELOAD := -e LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4:/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
	# else
	# CONTAINER_LD_PRELOAD := -e LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
	# endif
	CONTAINER_LD_PRELOAD := -e LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
	# CONTAINER_LD_PRELOAD := -e LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
	# no crash for compile 
	# CONTAINER_LD_PRELOAD := -e LD_PRELOAD=/opt/lib/libhoard.so
endif

all:


build:
	docker build --build-arg QUARTUS_VER=$(QUARTUS_VER) -t $(IMAGE_TAG) .
# ifeq ($(shell uname -m), arm64)
# 	docker build -f Dockerfile.arm64 --build-arg QUARTUS_VER=$(QUARTUS_VER) -t $(IMAGE_TAG) .
# else
# 	docker build --build-arg QUARTUS_VER=$(QUARTUS_VER) -t $(IMAGE_TAG) .
# endif

x11: x11_close
	socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"${DISPLAY}\" &
	sleep 2 && open -a xQuartz

x11_close:
	pkill socat || true

# TODO: --privileged

run:
	docker run --name $(CONTAINER_NAME) --rm --privileged -it --platform linux/$(PLATFORM) \
	--mac-address=$(MAC_ADDRESS) \
	-v ~/.Xauthority:/root/.Xauthority \
	-e DISPLAY=$(CONTAINER_DISPLAY) \
	-e LM_LICENSE_FILE=/opt/quartus/$(LICENSE_FILE) \
	-v $(LOCAL_SHARED_PATH)/.config:/root/.config \
	-v $(LOCAL_SHARED_PATH)/.altera.quartus:/root/.altera.quartus \
	-v $(LOCAL_SHARED_PATH)/$(LICENSE_FILE):/opt/quartus/$(LICENSE_FILE) \
	-v $(LOCAL_PATH):$(CONTAINER_PROJ_PATH) \
	-w $(CONTAINER_PROJ_PATH) \
	$(CONTAINER_LD_PRELOAD) $(OPT_ADDITIONAL) \
	$(IMAGE_TAG) $(ARGS)


shell:
	make run ARGS=""

nios2_shell:
	make run ARGS="/opt/quartus/nios2eds/nios2_command_shell.sh"

quartus_altmalloc:
	make quartus ALTMALLOC=y

quartus:
	make run ARGS="/opt/quartus/quartus/bin/quartus --64bit"

compile:
	make run ARGS="/opt/quartus/quartus/bin/quartus_sh --flow compile $(PROJECT_NAME)"

distclean:
	rm -rf db incremental_db sys simulation $(OUTPUT_PATH)

clean:
	make run ARGS="/opt/quartus/quartus/bin/quartus_sh --clean $(PROJECT_NAME)"

qsys_edit:
	make run ARGS="/opt/quartus/quartus/sopc_builder/bin/qsys-edit"

qsys_gen:
	make run ARGS="/opt/quartus/quartus/sopc_builder/bin/qsys-generate $(QSYS_FILE) --synthesis=VHDL"

update_mif:
	make run ARGS="/opt/quartus/quartus/bin/quartus_cdb $(PROJECT_NAME) -c $(PROJECT_NAME) --update_mif"

assemble: update_mif
	make run ARGS="/opt/quartus/quartus/bin/quartus_asm --read_settings_files=on --write_settings_files=off $(PROJECT_NAME) -c $(PROJECT_NAME)"

convert_prog_file: assemble
	make run ARGS="/opt/quartus/quartus/bin/quartus_cpf -c $(PROJECT_NAME).cof"

gen_sim_script:
	make run ARGS="/opt/quartus/quartus/bin/quartus_sh -t /opt/quartus/quartus/common/tcl/internal/nativelink/qnativesim.tcl --rtl_sim $(PROJECT_NAME) $(PROJECT_NAME)"

simulation:
	make run OPT_ADDITIONAL=-w\ $(CONTAINER_PROJ_PATH)/$(SIMULATION_PATH) ARGS="/opt/quartus/questa_fse/bin/vsim"

conv_sof_svf: assemble
	make run ARGS="/opt/quartus/quartus/bin/quartus_cpf -c -g $(SVF_VOLTAGE) -q $(SVF_FREQ)MHz -n p $(OUTPUT_PATH)/$(PROJECT_NAME).sof $(OUTPUT_PATH)/$(PROJECT_NAME).sof.svf"

urjtag_detect:
	echo "cable usbblaster\ndetect" | jtag

urjtag_prog_sram: conv_sof_svf
	cd $(OUTPUT_PATH) && \
	echo "cable usbblaster\ndetect\npart 0\nsvf \"$(PROJECT_NAME).sof.svf\"" | jtag

