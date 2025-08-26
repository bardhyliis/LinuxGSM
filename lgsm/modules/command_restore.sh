#!/bin/bash
# LinuxGSM command_restore.sh module
# Author: Bardhyl fork
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Restores a server backup using rsnapshot snapshots and links.

commandname="RESTORE"
commandaction="Restore"
moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
fn_firstcommand_set

# Trap to catch Ctrl+C
fn_restore_trap() {
    fn_print_fail_nl "Restore canceled"
    fn_script_log_warn "Restore canceled by user"
    core_exit.sh
}
trap fn_restore_trap INT

# Paths
backup_root="/data/backups/snapshots"
links_dir="/data/backups/links"
restore_target="/data/serverfiles"

# --- Function: Check server status and stop if running ---
fn_restore_check_server() {
    check_status.sh
    if [ "${status}" != "0" ]; then
        fn_print_warn_nl "${selfname} is running. Stop the server before restoring."
        fn_script_log_warn "Restore blocked: server running"
        core_exit.sh
    fi
}

# --- Function: Validate backup exists ---
fn_restore_validate_backup() {
    local restore_point="$1"

    if [ -z "${restore_point}" ]; then
        fn_print_fail_nl "No backup specified. Use a symlink name or snapshot folder."
        fn_script_log_fail "No restore point specified"
        core_exit.sh
    fi

    # Check if it’s a symlink
    if [ -L "${links_dir}/${restore_point}" ]; then
        latest_snapshot=$(readlink -f "${links_dir}/${restore_point}")
    elif [ -d "${backup_root}/${restore_point}" ]; then
        latest_snapshot="${backup_root}/${restore_point}"
    else
        fn_print_fail_nl "Backup not found: ${restore_point}"
        fn_script_log_fail "Backup not found: ${restore_point}"
        core_exit.sh
    fi

    if [ ! -d "${latest_snapshot}" ]; then
        fn_print_fail_nl "Snapshot folder missing: ${latest_snapshot}"
        fn_script_log_fail "Snapshot folder missing: ${latest_snapshot}"
        core_exit.sh
    fi

    fn_script_log_info "Restoring from snapshot: ${latest_snapshot}"
}

# --- Function: Restore snapshot ---
fn_restore_execute() {
    fn_print_info "Restoring backup: ${latest_snapshot} -> ${restore_target}"
    fn_script_log_info "Starting restore: ${latest_snapshot} -> ${restore_target}"

    rsync -a --delete "${latest_snapshot}/" "${restore_target}/"
    exitcode=$?

    if [ "${exitcode}" -ne 0 ]; then
        fn_print_fail_nl "Restore failed"
        fn_script_log_fail "Restore failed from ${latest_snapshot}"
        core_exit.sh
    else
        fn_print_ok "Restore completed successfully"
        fn_script_log_pass "Restore completed from ${latest_snapshot}"
    fi
}

# --- MAIN ---
if [ $# -lt 1 ]; then
    fn_print_fail_nl "Usage: $0 <backup_symlink_or_snapshot>"
    fn_script_log_fail "No restore point specified"
    core_exit.sh
fi

while true; do
    echo -n "Enter restore point name (or type 'exit' to cancel): "
    read restore_point

    # Trim whitespace
    restore_point=$(echo "$restore_point" | xargs)

    # Check if user wants to exit
    if [[ "$restore_point" == "exit" ]]; then
        fn_print_info "Restore canceled."
        core_exit.sh
    fi

    # Check if input is empty
    if [[ -z "$restore_point" ]]; then
        echo ""   # add newline before warning
        fn_print_warn "No input provided. Please type a restore point or 'exit'."
        echo ""   # extra newline for spacing
        continue
    fi

    # Input is valid, break loop
    break
done

fn_restore_check_server
fn_restore_validate_backup "${restore_point}"
fn_restore_execute

core_exit.sh