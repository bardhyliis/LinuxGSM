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
    tmpfile="${tmpdir}/fivem_build_${remotebuildversion}.tar.xz"
    fn_fetch_file "${remotebuildurl}" "" "" "" "${tmpdir}" "${remotebuildfilename}" "" "norun" "noforce" "nohash"
    tar -xJf "${tmpfile}" -C "${serverfiles}" --strip-components=1
    fn_clear_tmp
}

fn_update_localbuild() {
    fn_print_dots "Checking local build: ${remotelocation}"
    if [ -f "${serverfiles}/version.json" ]; then
        localbuild=$(jq -r '.version' "${serverfiles}/version.json")
    elif [ -f "${serverfiles}/alpine/version.json" ]; then
        localbuild=$(jq -r '.version' "${serverfiles}/alpine/version.json")
    else
        fn_print_warn "Local version.json not found, assuming build 0"
        localbuild="0"
    fi
    fn_print_ok "Local build: ${localbuild}"
}

fn_update_remotebuild() {
    fn_print_dots "Checking remote build: ${remotelocation}"
    remotebuildversion=$(curl -s "${artifacts_url}" | grep -Eo 'href="[0-9]+' | grep -Eo '[0-9]+' | sort -nr | head -n 1)
    remotebuildfilename="fivem_build_${remotebuildversion}.tar.xz"
    remotebuildurl="${artifacts_url}${remotebuildversion}/fx.tar.xz"
    if [ -z "${remotebuildversion}" ]; then
        fn_print_fail "Could not fetch remote build"
        core_exit.sh
    fi
    fn_print_ok "Remote build: ${remotebuildversion}"
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
