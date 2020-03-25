# ====================================================================
# Copyright oVirt Authors
# SPDX-License-Identifier: Apache-2.0
# ====================================================================

#
# CUSTOMIZATION-BEGIN
#
BUILD_DEV=0

PACKAGE_NAME=ovirt-engine-extension-logger-log4j
PACKAGE_VERSION=master
PACKAGE_DISPLAY_NAME=$(PACKAGE_NAME)-$(PACKAGE_VERSION)
ENGINE_NAME=ovirt-engine
PREFIX=/usr/local
LOCALSTATE_DIR=$(PREFIX)/var
BIN_DIR=$(PREFIX)/bin
SYSCONF_DIR=$(PREFIX)/etc
DATAROOT_DIR=$(PREFIX)/share
MAN_DIR=$(DATAROOT_DIR)/man
DOC_DIR=$(DATAROOT_DIR)/doc
DATA_DIR=$(DATAROOT_DIR)/$(PACKAGE_NAME)
JAVA_DIR=$(DATAROOT_DIR)/java
BUILD_FILE=tmp.built
#
# CUSTOMIZATION-END
#

# Don't use any of the bultin rules, in particular don't use the rule
# for .sh files, as that means that we can't generate .sh files from
# templates:
.SUFFIXES:
.SUFFIXES: .in

# Rule to generate files from templates:
.in:
	GENERATED_FILE_LIST=$$(echo "$(GENERATED)" | sed -e "s/ /\\\n/g"); \
	sed \
	-e "s|@MODULEPATH@|$(DATA_DIR)/modules|g" \
	-e "s|@PACKAGE_NAME@|$(PACKAGE_NAME)|g" \
	-e "s|@PACKAGE_VERSION@|$(PACKAGE_VERSION)|g" \
	-e "s|@PACKAGE_DISPLAY_NAME@|$(PACKAGE_DISPLAY_NAME)|g" \
	$< > $@

# List of files that will be generated from templates:
# Once add new template file, if required chmod, add it in generated-files target.
GENERATED = \
	packaging/etc/ovirt-engine/engine.conf.d/50-ovirt-engine-extension-logger-log4j.conf \
	src/main/resources/org/ovirt/engine/extension/logger/log4j/config.properties \
	$(NULL)


build: \
	$(BUILD_FILE) \
	$(NULL)

# support force run of maven
maven:
	mvn -Pdevenv install
	touch "$(BUILD_FILE)"

$(BUILD_FILE):
	$(MAKE) maven

clean:
	# Clean maven generated stuff:
	mvn clean
	rm -rf $(BUILD_FILE) tmp.dev.flist
	# Clean files generated from templates:
	rm -rf $$(echo $(GENERATED))


install: \
	install-layout \
	$(NULL)


# copy SOURCEDIR to TARGETDIR
# exclude EXCLUDEGEN a list of files to exclude with .in
# exclude EXCLUDE a list of files.
copy-recursive:
	( cd "$(SOURCEDIR)" && find . -type d -printf '%P\n' ) | while read d; do \
		install -d -m 755 "$(TARGETDIR)/$${d}"; \
	done
	( \
		cd "$(SOURCEDIR)" && find . -type f -printf '%P\n' | \
		while read f; do \
			exclude=false; \
			for x in $(EXCLUDE_GEN); do \
				if [ "$(SOURCEDIR)/$${f}" = "$${x}.in" ]; then \
					exclude=true; \
					break; \
				fi; \
			done; \
			for x in $(EXCLUDE); do \
				if [ "$(SOURCEDIR)/$${f}" = "$${x}" ]; then \
					exclude=true; \
					break; \
				fi; \
			done; \
			$${exclude} || echo "$${f}"; \
		done \
	) | while read f; do \
		src="$(SOURCEDIR)/$${f}"; \
		dst="$(TARGETDIR)/$${f}"; \
		[ -x "$${src}" ] && MASK=0755 || MASK=0644; \
		[ -n "$(DEV_FLIST)" ] && echo "$${dst}" | sed 's#^$(PREFIX)/##' >> "$(DEV_FLIST)"; \
		install -T -m "$${MASK}" "$${src}" "$${dst}"; \
	done

generate-files: \
		$(GENERATED) \
		$(NULL)


install-packaging-files:
	$(MAKE) copy-recursive SOURCEDIR=packaging/etc TARGETDIR="$(DESTDIR)$(SYSCONF_DIR)" EXCLUDE_GEN="$(GENERATED)"
	for d in examples modules; do \
		$(MAKE) copy-recursive SOURCEDIR="packaging/$${d}" TARGETDIR="$(DESTDIR)$(DATA_DIR)/$${d}" EXCLUDE_GEN="$(GENERATED)"; \
	done
	install -d -m 755 "$(DESTDIR)$(DOC_DIR)"
	install -d -m 755 "$(DESTDIR)$(DOC_DIR)/$(PACKAGE_NAME)"
	install -m 644 README "$(DESTDIR)$(DOC_DIR)/$(PACKAGE_NAME)/README"

install-layout: \
		install-packaging-files \
		$(NULL)
	ln -sf "$(JAVA_DIR)/$(PACKAGE_NAME)/$(PACKAGE_NAME).jar" "$(DESTDIR)$(DATA_DIR)/modules/org/ovirt/engine/extension/logger/log4j/main/$(PACKAGE_NAME).jar"
	ln -sf "$(JAVA_DIR)/log4j.jar" "$(DESTDIR)$(DATA_DIR)/modules/org/ovirt/engine/extension/logger/log4j/main/log4j.jar"


install-artifacts: \
		build \
		$(NULL)
	install -d -m 755 "$(DESTDIR)$(JAVA_DIR)"
	install -d -m 755 "$(DESTDIR)$(JAVA_DIR)/$(PACKAGE_NAME)"
	install -m 644 "target/$(PACKAGE_NAME).jar" "$(DESTDIR)$(JAVA_DIR)/$(PACKAGE_NAME)/$(PACKAGE_NAME).jar"

install-dev:	\
		generate-files \
		install-layout \
		install-artifacts \
		$(NULL)
	# remove dbscripts to avoid dups
	rm -fr "$(DESTDIR)$(DATA_DIR)/dbscripts"
	if [ -f "$(DESTDIR)$(PREFIX)/dev.$(PACKAGE_NAME).flist" ]; then \
		cat "$(DESTDIR)$(PREFIX)/dev.$(PACKAGE_NAME).flist" | while read f; do \
			rm -f "$(DESTDIR)$(PREFIX)/$${f}"; \
		done; \
		rm -f "$(DESTDIR)$(PREFIX)/dev.$(PACKAGE_NAME).flist"; \
	fi
	rm -f tmp.dev.flist
	$(MAKE) \
		install \
		DEV_FLIST=tmp.dev.flist \
		$(NULL)
	cp tmp.dev.flist "$(DESTDIR)$(PREFIX)/dev.$(PACKAGE_NAME).flist"


