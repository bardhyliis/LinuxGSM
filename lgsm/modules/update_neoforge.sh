#!/bin/bash
# LinuxGSM update_nf.sh module
# Author: Bardhyl + ChatGPT
# Description: Handles updating of NeoForge servers.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

fn_update_dl() {
	fn_fetch_file "${remotebuildurl}" "" "" "" "${tmpdir}" "${remotebuildfilename}" "norun" "force"
	fn_fetch_file "${remotebuildurl}.sha1" "" "" "" "${tmpdir}" "${remotebuildfilename}.sha1" "norun" "force"

	cp -f "${tmpdir}/${remotebuildfilename}" "${serverfiles}/neoforge_installer.jar"

	# Verify sha1 checksum
	expectedhash=$(cat "${tmpdir}/${remotebuildfilename}.sha1" | awk '{print $1}')
	actualhash=$(sha1sum "${tmpdir}/${remotebuildfilename}" | awk '{print $1}')
	if [ "${expectedhash}" != "${actualhash}" ]; then
		fn_print_fail "Hash mismatch for ${remotebuildfilename}"
		fn_script_log_fail "Expected: ${expectedhash}, got: ${actualhash}"
		core_exit.sh
	fi

	# Run installer to extract server to ${serverfiles}
	java -jar "${serverfiles}/neoforge_installer.jar"

	# Dynamically set executable based on installed version
	installed_version=$(ls -1 "${serverfiles}/libraries/net/neoforged/neoforge/" | sort -V | tail -n1)
	executable="${serverfiles}/libraries/net/neoforged/neoforge/${installed_version}/neoforge-${installed_version}-server.jar @${serverfiles}/libraries/net/neoforged/neoforge/${installed_version}/unix_args.txt"

	echo "${installed_version}" > "${serverfiles}/build.txt"

	fn_clear_tmp
}

fn_update_localbuild() {
	fn_print_dots "Checking local build: ${remotelocation}"
	localbuild=$(head -n 1 "${serverfiles}/build.txt" 2> /dev/null)
	if [ -z "${localbuild}" ]; then
		fn_print_error "Checking local build: ${remotelocation}: missing local build info"
		fn_script_log_error "Missing local build info"
		localbuild="0"
	else
		fn_print_ok "Checking local build: ${remotelocation}"
		fn_script_log_pass "Checking local build"
	fi
}

fn_update_remotebuild() {
	apiurl="https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml"

	# Determine version to install
	if [ "${mcversion}" == "latest" ]; then
		# Fetch latest release version
		remotebuildmcversion=$(curl -s "${apiurl}" | xmllint --xpath "string(//metadata/versioning/release)" -)
	else
		# Use the user-specified version
		remotebuildmcversion="${mcversion}"
	fi

	# Set build info
	remotebuildfilename="neoforge-${remotebuildmcversion}-installer.jar"
	remotebuildurl="https://maven.neoforged.net/releases/net/neoforged/neoforge/${remotebuildmcversion}/${remotebuildfilename}"
	remotebuildversion="${remotebuildmcversion}"

	if [ "${firstcommandname}" != "INSTALL" ]; then
		fn_print_dots "Checking remote build: ${remotelocation}"
		if [ -z "${remotebuildversion}" ] || [ "${remotebuildversion}" == "null" ]; then
			fn_print_fail "Checking remote build: ${remotelocation}"
			fn_script_log_fail "Checking remote build"
			core_exit.sh
		else
			fn_print_ok "Checking remote build: ${remotelocation}"
			fn_script_log_pass "Checking remote build"
		fi
	else
		if [ -z "${remotebuildversion}" ] || [ "${remotebuildversion}" == "null" ]; then
			fn_print_failure "Unable to get remote build"
			fn_script_log_fail "Unable to get remote build"
			core_exit.sh
		fi
	fi
}

fn_update_compare() {
	fn_print_dots "Checking for update: ${remotelocation}"
	if [ "${localbuild}" != "${remotebuildversion}" ] || [ "${forceupdate}" == "1" ]; then
		date '+%s' > "${lockdir:?}/update.lock"
		fn_print_ok_nl "Checking for update: ${remotelocation}"
		echo -e "\nUpdate available"
		echo -e "* Local build: ${red}${localbuild}${default}"
		echo -e "* Remote build: ${green}${remotebuildversion}${default}"
		fn_script_log_info "Update available"
		fn_script_log_info "Local build: ${localbuild}"
		fn_script_log_info "Remote build: ${remotebuildversion}"
		fn_script_log_info "${localbuild} > ${remotebuildversion}"

		if [ "${commandname}" == "UPDATE" ]; then
			date +%s > "${lockdir}/last-updated.lock"
			unset updateonstart
			check_status.sh
			if [ "${status}" == "0" ]; then
				fn_update_dl
				if [ "${localbuild}" == "0" ]; then
					exitbypass=1
					command_start.sh
					fn_firstcommand_reset
					exitbypass=1
					fn_sleep_time_5
					command_stop.sh
					fn_firstcommand_reset
				fi
			else
				fn_print_restart_warning
				exitbypass=1
				command_stop.sh
				fn_firstcommand_reset
				exitbypass=1
				fn_update_dl
				exitbypass=1
				command_start.sh
				fn_firstcommand_reset
			fi
			unset exitbypass
			alert="update"
		elif [ "${commandname}" == "CHECK-UPDATE" ]; then
			alert="check-update"
		fi
		alert.sh
	else
		fn_print_ok_nl "Checking for update: ${remotelocation}"
		echo -e "\nNo update available"
		echo -e "* Local build: ${green}${localbuild}${default}"
		echo -e "* Remote build: ${green}${remotebuildversion}${default}"
		fn_script_log_info "No update available"
		fn_script_log_info "Local build: ${localbuild}"
		fn_script_log_info "Remote build: ${remotebuildversion}"
	fi
}

# The location where the builds are checked and downloaded.
remotelocation="maven.neoforged.net"

if [ ! "$(command -v xmllint 2> /dev/null)" ]; then
	fn_print_fail_nl "xmllint is not installed"
	fn_script_log_fail "xmllint is not installed"
	core_exit.sh
fi

if [ "${firstcommandname}" == "INSTALL" ]; then
	fn_update_remotebuild
	fn_update_dl
else
	fn_print_dots "Checking for update"
	fn_script_log_info "Checking for update: ${remotelocation}"
	fn_update_localbuild
	fn_update_remotebuild
	fn_update_compare
fi
