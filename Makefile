# Define scripting
SHELL:=/bin/bash

# General directories definitions
PROJECT_DIR = $(shell readlink -f $(shell pwd)/$(dir $(firstword $(MAKEFILE_LIST))))
BUILD_DIR = $(PROJECT_DIR)/build

# Variables for Installation Directories defaults (following the GNU Makefile conventions)
PROGRAM_NAME = mqtt-play
PREFIX = $(PROJECT_DIR)/_install_dir
EXEC_PREFIX = $(PREFIX)
BINDIR = $(EXEC_PREFIX)/bin
LOCALSTATEDIR = $(PREFIX)/var
RUNSTATEDIR = $(LOCALSTATEDIR)/run
INCLUDEDIR = $(PREFIX)/include
LIBDIR = $(EXEC_PREFIX)/lib
TESTSDIR = $(PROJECT_DIR)/src/tests
DATAROOTDIR = $(PREFIX)/share
HTMLDIR = $(DATAROOTDIR)/$(PROGRAM_NAME)/html

# Non conventional:
# SRCDIRS: A list of SRCDIR's (in the same target we compile sources in 
#          several locations)

# Common compiler options
GCC = gcc
CPP = c++
C_CPP_FLAGS =  -Wall -O3 -fPIC -I$(INCLUDEDIR) -DPROJECT_DIR=\"$(PROJECT_DIR)\" -DPREFIX=\"$(PREFIX)\" -fms-extensions
#C_CPP_FLAGS =  -Wall -O0 -g -fPIC -I$(INCLUDEDIR) -DPROJECT_DIR=\"$(PROJECT_DIR)\" -DPREFIX=\"$(PREFIX)\" -fms-extensions
CFLAGS = $(C_CPP_FLAGS) -std=gnu11
GTEST_CFLAGS = -Wall --coverage -O0 -g -fPIC -I$(INCLUDEDIR) -DPROJECT_DIR=\"$(PROJECT_DIR)\" -DPREFIX=\"$(PREFIX)\"
CPPFLAGS = $(C_CPP_FLAGS) -std=c++11 -std=c++17
GTEST_CPPFLAGS = $(GTEST_CFLAGS) -std=c++11 -std=c++17
LDFLAGS = -L$(LIBDIR)
LDLIBS = -lm -ldl -lpthread -lrt
LIBSHARED_LDFLAGS = $(LDFLAGS) -Bdynamic -shared
LIBSRCDIRS = $(PROJECT_DIR)/src/libs
GTEST_LDLIBS = -lstdc++ -lgtest -lgtest_main -lgmock -lgmock_main -lgcov

.PHONY: all clean .foldertree $(PROGRAM_NAME)

all: mosquitto googletest
	@$(MAKE) $(PROGRAM_NAME)

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf $(PREFIX)
	@$(MAKE) -C "$(PROJECT_DIR)/3rdplibs/mosquitto" clean || exit 1

#Note: Use dot as a "trick" to hide this target from shell when user applies "autocomplete"
.foldertree:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(LIBDIR)
	@mkdir -p $(INCLUDEDIR)
	@mkdir -p $(BINDIR)
	@mkdir -p $(PREFIX)/etc
	@mkdir -p $(PREFIX)/certs
	@mkdir -p $(RUNSTATEDIR)
	@mkdir -p $(PREFIX)/tmp

##############################################################################
# Rule for 'tests' application
##############################################################################

tests: | .foldertree
	sed -e 's~<PREFIX>~${PREFIX}~g' -e 's~<PROJECT_DIR>~${PROJECT_DIR}~g' \
$(PROJECT_DIR)/conf/mc-vod.conf.template > $(PREFIX)/tmp/test_ftp.conf | true
	@$(MAKE) $@-generic-build-install --no-print-directory \
SRCDIRS=$(PROJECT_DIR)/src/tests _BUILD_DIR=$(BUILD_DIR)/$@ \
LDLIBS='$(MCVOD_LDLIBS) $(GTEST_LDLIBS) -lfineftp-serverd -lmcvod' \
TARGETFILE='$(BUILD_DIR)/$@/$@.bin' DESTFILE='$(BINDIR)/$@' || exit 1

##############################################################################
# Rule for 'cJSON' library
##############################################################################

CJSON_SRCDIRS = $(PROJECT_DIR)/3rdplibs/cJSON
.ONESHELL:
cjson: | .foldertree
	@$(eval _BUILD_DIR := $(BUILD_DIR)/$@)
	@mkdir -p "$(_BUILD_DIR)"
	cmake -DENABLE_CJSON_UTILS=On -DENABLE_CJSON_TEST=Off  \
-DBUILD_STATIC_LIBS=OFF -DCMAKE_INSTALL_PREFIX="$(PREFIX)" -B"$(_BUILD_DIR)" \
-S"$(CJSON_SRCDIRS)" || exit 1
	@$(MAKE) -C "$(_BUILD_DIR)" || exit 1
	@$(MAKE) -C "$(_BUILD_DIR)" install || exit 1

##############################################################################
# Rule for 'OpenSSL' library and apps.
##############################################################################

OPENSSL_SRCDIRS = $(PROJECT_DIR)/3rdplibs/openssl
.ONESHELL:
openssl: | .foldertree
	@$(eval _BUILD_DIR := $(BUILD_DIR)/$@)
	@mkdir -p "$(_BUILD_DIR)"
	@if [ ! -f "$(_BUILD_DIR)"/Makefile ] ; then \
		echo "Configuring $@..."; \
		cd "$(_BUILD_DIR)" && "$(OPENSSL_SRCDIRS)"/config --prefix="$(PREFIX)" \
--openssldir="$(PREFIX)" --libdir=lib || exit 1; \
	fi
	@$(MAKE) -C "$(_BUILD_DIR)" -j1 install_sw || exit 1

##############################################################################
# Rule for 'c-ares' library and apps.
##############################################################################

CARES_SRCDIRS = $(PROJECT_DIR)/3rdplibs/c-ares-cares
.ONESHELL:
c-ares-cares: | .foldertree
	@$(eval _BUILD_DIR := $(BUILD_DIR)/$@)
	@mkdir -p "$(_BUILD_DIR)"
	cmake -DBUILD_STATIC_LIBS=OFF -DCMAKE_INSTALL_PREFIX="$(PREFIX)" -B"$(_BUILD_DIR)" \
-S"$(CARES_SRCDIRS)" || exit 1
	@$(MAKE) -C "$(_BUILD_DIR)" || exit 1
	@$(MAKE) -C "$(_BUILD_DIR)" install || exit 1

##############################################################################
# Rule for 'mosquitto' library and apps.
##############################################################################

MOSQUITTO_SRCDIRS = $(PROJECT_DIR)/3rdplibs/mosquitto
.ONESHELL:
mosquitto: c-ares-cares openssl cjson | .foldertree
	@$(eval _BUILD_DIR := $(BUILD_DIR)/$@)
	@mkdir -p "$(_BUILD_DIR)"
	DESTDIR="$(PREFIX)" LDFLAGS="$(LDFLAGS)" CFLAGS="$(CFLAGS)" \
	INCLUDEDIR='-I$(INCLUDEDIR)' $(MAKE) -C "$(MOSQUITTO_SRCDIRS)" \
	WITH_DOCS=no install || exit 1

##############################################################################
# Rule for 'googletest' library
##############################################################################

GTEST_SRCDIRS = $(PROJECT_DIR)/3rdplibs/googletest
.ONESHELL:
googletest: | .foldertree
	@$(eval _BUILD_DIR := $(BUILD_DIR)/$@)
	@mkdir -p "$(_BUILD_DIR)"
	cmake -DBUILD_SHARED_LIBS=ON -B"$(_BUILD_DIR)" -S"$(GTEST_SRCDIRS)" || exit 1
	@$(MAKE) -C "$(_BUILD_DIR)" || exit 1
	@cp -a "$(GTEST_SRCDIRS)"/googletest/include/gtest "$(PREFIX)"/include/
	@cp -a "$(GTEST_SRCDIRS)"/googlemock/include/gmock "$(PREFIX)"/include/
	@cp -a "$(_BUILD_DIR)"/lib/* "$(PREFIX)"/lib/

##############################################################################
# Generic rules to compile and install any library or app. from source
############################################################################## 
# Implementation note: 
# -> ’%’ below is used to write target with wildcards (e.g. ‘%-build’ matches all called targets with this pattern);
# -> ‘$*’ takes exactly the value of the substring matched by ‘%’ in the correspondent target itself. 
# For example, if the main Makefile performs 'make mylibname-build', ’%’ will match 'mylibname' and ‘$*’ will exactly 
# take the value 'mylibname'.

%-generic-build-install: %-generic-build-source-compile
	@echo Installing target "$(TARGETFILE)" to "$(DESTFILE)";
	@if [ ! -z "$(INCLUDEFILES)" ] ; then\
		for file in ${INCLUDEFILES}; do \
			install_path=$$(echo "$${file#*/$*/}");\
			install_dir=$$(dirname "$(INCLUDEDIR)/$*/$$install_path");\
			mkdir -p "$$install_dir";\
			cp -f "$$file" "$(INCLUDEDIR)/$*/$$install_path";\
		done;\
	fi
	cp -f $(TARGETFILE) $(DESTFILE) || exit 1

find_cfiles = $(wildcard $(shell realpath -q --relative-to=$(PROJECT_DIR) $(dir)/*.c))
find_cppfiles = $(wildcard $(shell realpath -q --relative-to=$(PROJECT_DIR) $(dir)/*.cpp))
get_cfiles_objs = $(patsubst %.c,$(_BUILD_DIR)/%.o,$(find_cfiles))
get_cppfiles_objs = $(patsubst %.cpp,$(_BUILD_DIR)/%.oo,$(find_cppfiles))

%-generic-build-source-compile:
	@printf "\nBuilding target '$*' from sources... (make $@)\n"
	@printf "Target file $(TARGETFILE)\n";
	@printf "Source directories: $(SRCDIRS)\n";
	@mkdir -p "$(_BUILD_DIR)"
	$(eval cobjs := $(foreach dir,$(SRCDIRS),$(get_cfiles_objs)))
	$(eval cppobjs := $(foreach dir,$(SRCDIRS),$(get_cppfiles_objs)))
	$(MAKE) $(TARGETFILE) objs+="$(cobjs) $(cppobjs)" --no-print-directory || exit 1;
	@printf "Finished building target '$*'\n" 

$(TARGETFILE): $(objs)
	$(GCC) -o $@ $^ $(LDFLAGS) $(LDLIBS)

.PRECIOUS: $(_BUILD_DIR)%/.
$(_BUILD_DIR)%/.:
	mkdir -p $@

.SECONDEXPANSION:

# Note: The "$(@D)" expands to the directory part of the target path. 
# We escape the $(@D) reference so that we expand it only during the second expansion.
$(_BUILD_DIR)/%.o: $(PROJECT_DIR)/%.c | $$(@D)/.
	$(GCC) -c -o $@ $< $(CFLAGS)

$(_BUILD_DIR)/%.oo: $(PROJECT_DIR)/%.cpp | $$(@D)/.
	$(GCC) -c -o $@ $< $(CPPFLAGS)

