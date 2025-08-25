#!/bin/bash
# LinuxGSM update_fivem.sh module
# Author: Your Name
# Based on: update_fm.sh by Daniel Gibbs
# Website: https://linuxgsm.com
# Description: Handles updating of FiveM servers.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

# Cfx.re artifacts URL for Linux
artifacts_url="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"

fn_update_dl() {
    fn_print_info "Downloading and installing FiveM build ${remotebuildversion}"
    tmpfile="${tmpdir}/${remotebuildfilename}"
    fn_fetch_file "${remotebuildurl}" "" "" "" "${tmpdir}" "${remotebuildfilename}" "" "norun" "noforce" "nohash"
    tar -xJf "${tmpfile}" -C "${serverfiles}"

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
    fn_print_dots "Checking remote build: ${remotelocation}"

    # Fetch the list of build folders once
    artifact_folders=$(curl -s https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/ \
        | grep -Eo '\./[0-9]+-[a-z0-9]+/' \
        | sed 's|^\./||; s|/$||' \
        | sort -t '-' -k1,1nr)

    if [ "${fmversion}" = "latest" ]; then
        # Pick the first folder as the latest
        remotebuildversion=$(echo "$artifact_folders" | head -n 1)
        buildnumber=$(echo "$remotebuildversion" | cut -d'-' -f1)
    else
        buildnumber="${fmversion}"
        # Find the folder starting with the requested build number
        remotebuildversion=$(echo "$artifact_folders" | grep "^${buildnumber}-" | head -n 1)
    fi

    if [ -z "${remotebuildversion}" ]; then
        fn_print_fail "Could not fetch remote build"
        core_exit.sh
    fi

    remotebuildfilename="fivem_build_${buildnumber}.tar.xz"
    remotebuildurl="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${remotebuildversion}/fx.tar.xz"

    fn_print_ok "Remote build: ${remotebuildfilename}"
}

fn_update_compare() {
    fn_print_dots "Comparing builds"
    if [ "${localbuild}" != "${remotebuildversion}" ] || [ "${forceupdate}" == "1" ]; then
        date '+%s' > "${lockdir:?}/update.lock"
        fn_print_ok_nl "Update available"
        echo -e "* Local build: ${localbuild}"
        echo -e "* Remote build: ${remotebuildversion}"
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
                fn_update_dl
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
        fn_print_ok_nl "No update available"
        echo -e "* Local build: ${localbuild}"
        echo -e "* Remote build: ${remotebuildversion}"
    fi
}

remotelocation="runtime.fivem.net"

if [ ! "$(command -v jq 2>/dev/null)" ]; then
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
