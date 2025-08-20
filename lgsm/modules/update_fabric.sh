#!/bin/bash
# LinuxGSM update_mc.sh module
# Fabric version
# Handles updating of Fabric servers.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

fn_update_dl() {
	# Download server jar.
	fn_fetch_file "${remotebuildurl}" "" "" "" "${tmpdir}" "${remotebuildfilename}" "chmodx" "norun" "noforce" "nohash"
	cp -f "${tmpdir}/${remotebuildfilename}" "${serverfiles}/minecraft_server.jar"
	fn_clear_tmp
}

fn_update_localbuild() {
	# Gets local build info.
	fn_print_dots "Checking local build: ${remotelocation}"
	if [ -d "${executabledir}" ]; then
		cd "${executabledir}" || exit
		localbuild=$(unzip -p "minecraft_server.jar" version.json 2>/dev/null | jq -r '.id' || echo "")
	fi
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
	# Resolve mcversion if set to "latest"
	if [ "${mcversion}" == "latest" ]; then
		gamejson=$(curl -s "https://meta.fabricmc.net/v2/versions/game")
		mcversion=$(echo "${gamejson}" | jq -r '[.[] | select(.stable==true)][0].version')
	fi

	# Get latest installer and loader for that mcversion
	apiurl="https://meta.fabricmc.net/v2/versions"
	installerjson=$(curl -s "${apiurl}/installer")
	loaderjson=$(curl -s "${apiurl}/loader/${mcversion}")

	installer_version=$(echo "${installerjson}" | jq -r '.[0].version')
	loader_version=$(echo "${loaderjson}" | jq -r '.[0].version')

	remotebuildversion="${mcversion}-${loader_version}-${installer_version}"
	remotebuildfilename="fabric-server-${remotebuildversion}.jar"
	remotebuildurl="https://meta.fabricmc.net/v2/versions/loader/${mcversion}/${loader_version}/${installer_version}/server/jar"

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
		echo -e "Update available"
		echo -e "* Local build: ${red}${localbuild}${default}"
		echo -e "* Remote build: ${green}${remotebuildversion}${default}"
		fn_script_log_info "Update available"
		fn_script_log_info "Local build: ${localbuild}"
		fn_script_log_info "Remote build: ${remotebuildversion}"

		if [ "${commandname}" == "UPDATE" ]; then
			date +%s > "${lockdir}/last-updated.lock"
			unset updateonstart
			check_status.sh
			if [ "${status}" == "0" ]; then
				fn_update_dl
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
		echo -e "No update available"
		echo -e "* Local build: ${green}${localbuild}${default}"
		echo -e "* Remote build: ${green}${remotebuildversion}${default}"
		fn_script_log_info "No update available"
	fi
}

remotelocation="fabricmc.net"

if [ ! "$(command -v jq 2> /dev/null)" ]; then
	fn_print_fail_nl "jq is not installed"
	fn_script_log_fail "jq is not installed"
	core_exit.sh
fi

if [ "${firstcommandname}" == "INSTALL" ]; then
	fn_update_remotebuild
	fn_update_dl
else
	fn_update_localbuild
	fn_update_remotebuild
	fn_update_compare
fi
