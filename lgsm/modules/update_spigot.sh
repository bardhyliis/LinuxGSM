#!/bin/bash
# LinuxGSM update_spigot.sh module
# Author: Adapted from Daniel Gibbs
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Handles updating of Spigot servers using BuildTools.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

remotelocation="spigotmc.org"
BUILDTOOLS_URL="https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
BUILDTOOLS_JAR="${tmpdir}/BuildTools.jar"

fn_update_dl() {
    # Download BuildTools and build spigot
    fn_print_dots "Downloading BuildTools"
    fn_fetch_file "${BUILDTOOLS_URL}" "" "" "" "${tmpdir}" "$(basename "${BUILDTOOLS_JAR}")" "chmodx" "norun" "noforce" "nohash"

    fn_print_dots "Building Spigot: ${remotebuildversion}"
    cd "${tmpdir}" || exit
    java -jar "${BUILDTOOLS_JAR}" --rev "${remotebuildversion}"
    if [ ! -f "spigot-${remotebuildversion}.jar" ]; then
        fn_print_fail "BuildTools failed to generate spigot-${remotebuildversion}.jar"
        core_exit.sh
    fi

    cp -f "spigot-${remotebuildversion}.jar" "${serverfiles}/spigot.jar"
    fn_clear_tmp
}

fn_update_localbuild() {
    # Gets local build info from server jar
    fn_print_dots "Checking local build: ${remotelocation}"
    if [ -f "${serverfiles}/spigot.jar" ]; then
        localbuild=$(java -jar "${serverfiles}/spigot.jar" --version 2>&1 | grep -oP 'This server is running \K.*')
    fi

    if [ -z "${localbuild}" ]; then
        fn_print_error "Checking local build: ${remotelocation}: missing local build info"
        fn_script_log_error "Missing local build info"
        fn_script_log_error "Set localbuild to 0"
        localbuild="0"
    else
        fn_print_ok "Checking local build: ${remotelocation}"
        fn_script_log_pass "Checking local build"
    fi
}

fn_update_remotebuild() {
    # Spigot does not provide a JSON manifest; we rely on specifying version manually
    if [ "${mcversion}" == "latest" ]; then
        remotebuildversion="latest" # Default latest, can be overridden by user
    else
        remotebuildversion="${mcversion}"
    fi
    remotebuildfilename="spigot-${remotebuildversion}.jar"

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

if [ "${firstcommandname}" == "INSTALL" ]; then
    fn_update_remotebuild
    fn_update_dl
else
    fn_print_dots "Checking for update"
    fn_update_localbuild
    fn_update_remotebuild
    fn_update_compare
fi
