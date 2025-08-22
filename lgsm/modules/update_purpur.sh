#!/bin/bash
# LinuxGSM update_purpur.sh module
# Author: Adapted from Daniel Gibbs
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Handles updating of Purpur Minecraft servers.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

remotelocation="purpurmc.org"
PURPUR_API_MANIFEST="https://api.purpurmc.org/v2/purpur"

fn_update_dl() {
    # Download Purpur server jar
    fn_print_dots "Downloading Purpur ${remotebuildversion}"
    remotebuildurl="${PURPUR_API_MANIFEST}/${remotebuildversion}/latest/download"
    fn_fetch_file "${remotebuildurl}" "" "" "" "${tmpdir}" "purpur-${remotebuildversion}.jar" "chmodx" "norun" "noforce" "nohash"
    cp -f "${tmpdir}/purpur-${remotebuildversion}.jar" "${serverfiles}/purpur.jar"
	echo "${remotebuildversion}" > "/app/version.txt"
    fn_clear_tmp
}

fn_update_localbuild() {
    # Gets local build info from version.txt
    fn_print_dots "Checking local build: ${remotelocation}"
    
    if [ -f "/app/version.txt" ]; then
        localbuild=$(<"/app/version.txt")
    else
        fn_print_error "Checking local build: ${remotelocation}: missing local build info"
        fn_script_log_error "Missing local build info"
        localbuild="0"
    fi

    if [ -z "${localbuild}" ] || [ "${localbuild}" == "0" ]; then
        fn_print_error "Local build not set"
        fn_script_log_error "Local build not set"
    else
        fn_print_ok "Checking local build: ${remotelocation}"
        fn_script_log_pass "Checking local build"
    fi
}

fn_update_remotebuild() {
    # Fetch Purpur manifest and determine latest or specific version
    manifest=$(curl -s "${PURPUR_API_MANIFEST}")
    if [ "${mcversion}" == "latest" ]; then
        remotebuildversion=$(echo "${manifest}" | jq -r '.metadata.current')
    else
        # Validate requested version exists
        exists=$(echo "${manifest}" | jq -r --arg ver "${mcversion}" '.versions[] | select(.==$ver)')
        if [ -z "${exists}" ]; then
            fn_print_fail "Requested version ${mcversion} does not exist"
            core_exit.sh
        fi
        remotebuildversion="${mcversion}"
    fi

    remotebuildfilename="purpur-${remotebuildversion}.jar"

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
        echo -en "\n"
        echo -e "Update available"
        echo -e "* Local build: ${red}${localbuild}${default}"
        echo -e "* Remote build: ${green}${remotebuildversion}${default}"
        echo -en "\n"
        fn_script_log_info "Update available"
        fn_script_log_info "Local build: ${localbuild}"
        fn_script_log_info "Remote build: ${remotebuildversion}"

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
        echo -en "\n"
        echo -e "No update available"
        echo -e "* Local build: ${green}${localbuild}${default}"
        echo -e "* Remote build: ${green}${remotebuildversion}${default}"
        echo -en "\n"
        fn_script_log_info "No update available"
        fn_script_log_info "Local build: ${localbuild}"
        fn_script_log_info "Remote build: ${remotebuildversion}"
    fi
}

if [ ! "$(command -v java 2> /dev/null)" ]; then
    fn_print_fail_nl "Java is not installed"
    fn_script_log_fail "Java is not installed"
    core_exit.sh
fi

if [ ! "$(command -v jq 2> /dev/null)" ]; then
    fn_print_fail_nl "jq is not installed"
    fn_script_log_fail "jq is not installed"
    core_exit.sh
fi

if [ "${firstcommandname}" == "INSTALL" ]; then
    fn_update_remotebuild
    fn_update_dl
else
    fn_print_dots "Checking for update"
    fn_update_localbuild
    fn_update_remotebuild
    fn_update_compare
fi