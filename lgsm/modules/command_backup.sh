#!/bin/bash
# LinuxGSM command_backup.sh module
# Author: Bardhyl fork
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Creates an rsnapshot backup instead of a compressed archive.

commandname="BACKUP"
commandaction="Backup"
moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
fn_firstcommand_set

# Trap to remove lockfile on quit.
fn_backup_trap() {
    echo -e ""
    fn_print_canceled_eol_nl
    fn_script_log_info "Backup: CANCELED"
    rm -f "${lockdir:?}/backup.lock"
    fn_backup_start_server
    unset exitbypass
    core_exit.sh
}

# Check lockfile
fn_backup_check_lockfile() {
    if [ -f "${lockdir}/backup.lock" ]; then
        local pid
        pid=$(cat "${lockdir}/backup.lock")

        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            # PID exists and process is running
            fn_print_info_nl "Lockfile found: Backup already running (PID $pid)"
            fn_script_log_error "Backup already running: ${lockdir}/backup.lock, PID $pid"
            core_exit.sh
        else
            # Stale lock: process not running
            fn_print_warn_nl "Removing stale lockfile"
            fn_script_log_warn "Removing stale lockfile: ${lockdir}/backup.lock (PID $pid not running)"
            rm -f "${lockdir:?}/backup.lock"
        fi
    fi
}

fn_backup_create_rsnapshot_conf() {
    local rsnapconf="/data/backups/configuration/rsnapshot-${selfname}.conf"

    # If config already exists, skip
    if [ -f "${rsnapconf}" ]; then
        fn_script_log_info "rsnapshot config exists: ${rsnapconf}"
        return
    fi

    fn_print_info "Creating rsnapshot config: ${rsnapconf}"
    fn_script_log_info "Creating rsnapshot config: ${rsnapconf}"

    # Ensure folders exist
    mkdir -p /data/backups/snapshots
    mkdir -p /data/backups/links
    mkdir -p /data/backups/configuration

    # Write rsnapshot config, contains tabs.
    cat > "${rsnapconf}" <<EOF
# Auto-generated rsnapshot config for LinuxGSM server
# Can be updated
config_version	1.2

cmd_rsync	/usr/bin/rsync
cmd_cp	/bin/cp

# Store actual snapshots here
snapshot_root	/data/backups/snapshots

# Retention policy: last 10 daily snapshots
retain	daily	10

rsync_long_args	--relative	--delete	--delete-excluded

lockfile	/data/backups/rsnapshot-${selfname}.pid

# Backup source: everything inside serverfiles
backup	/data/serverfiles/./	./

# Optional exclusions
exclude	*.log
exclude	*.tmp

# Logging
loglevel	3
logfile	/data/backups/rsnapshot-${selfname}.log
EOF

    fn_print_ok "rsnapshot config created"
    fn_script_log_pass "rsnapshot config created: ${rsnapconf}"
}

fn_backup_init() {
    info_distro.sh
    fn_print_dots "Starting rsnapshot backup"
    fn_script_log_info "Starting rsnapshot backup"
}

fn_backup_stop_server() {
        check_status.sh
        # Server is running but will not be stopped.
        if [ "${status}" != "0" ]; then
                fn_print_warn_nl "${selfname} is currently running"
                echo -e "* Although unlikely; creating a backup while ${selfname} is running might corrupt the backup."
                fn_script_log_warn "${selfname} is currently running"
                fn_script_log_warn "Although unlikely; creating a backup while ${selfname} is running might corrupt the backup"
        # Server is running and will be stopped if stoponbackup=on or unset.
        # If server is started
        # elif [ "${status}" != "0" ]; then
        #       fn_print_restart_warning
        #       startserver="1"
        #       exitbypass=1
        #       command_stop.sh
        #       fn_firstcommand_reset
        fi
}

fn_backup_dir() {
    # Create lockfile directory if missing
    if [ ! -d "${lockdir}" ]; then
        mkdir -p "${lockdir}"
    fi
}

fn_backup_create_lockfile() {
    # Create lockfile containing current PID
    echo $$ > "${lockdir:?}/backup.lock"
    fn_script_log_info "Backup lockfile generated: ${lockdir}/backup.lock (PID $$)"

    # Trap to remove lockfile on quit
    trap fn_backup_trap INT
}

fn_update_symbolic_links(){
   # Paths
    SNAPSHOT_DIR="/data/backups/snapshots"
    TIMESTAMP_DIR="/data/backups/timestamps"
    LINK_DIR="/data/backups/links"

    mkdir -p "$TIMESTAMP_DIR" "$LINK_DIR"

    # --- Rotate timestamp files in sync with snapshot rotation ---
    for interval in daily weekly monthly; do
        # Find snapshot files matching the interval
        snaps=($(ls -d "$SNAPSHOT_DIR"/${interval}.[0-9]* 2>/dev/null | sort -r)) # descending
        for snap in "${snaps[@]}"; do
            base=$(basename "$snap")
            num=${base##*.} # extract number, e.g., daily.0 -> 0
            old_ts="$TIMESTAMP_DIR/${interval}.$num.txt"

            if [ "$num" -gt 0 ]; then
                prev_num=$((num - 1))
                prev_ts="$TIMESTAMP_DIR/${interval}.$prev_num.txt"
                if [ -f "$prev_ts" ]; then
                    # move previous timestamp forward
                    mv -f "$prev_ts" "$old_ts"
                else
                    # fallback: create timestamp from snapshot mod time
                    ts=$(stat -c %y "$SNAPSHOT_DIR/${interval}.$prev_num" | cut -d'.' -f1 | tr ' ' '_')
                    echo "$ts" > "$old_ts"
                fi
            fi
        done

        # Create timestamp for the new .0 snapshot
        if [ -d "$SNAPSHOT_DIR/${interval}.0" ]; then
            echo "$(date +"%Y-%m-%d_%H-%M-%S")" > "$TIMESTAMP_DIR/${interval}.0.txt"
        fi
    done

    # --- Rebuild symlinks ---
    rm -f "$LINK_DIR"/*

    for interval in daily weekly monthly; do
        snaps=($(ls -d "$SNAPSHOT_DIR"/${interval}.[0-9]* 2>/dev/null | sort)) # ascending: 0 -> N
        for snap in "${snaps[@]}"; do
            base=$(basename "$snap")
            num=${base##*.}
            ts_file="$TIMESTAMP_DIR/${interval}.$num.txt"

            if [ -f "$ts_file" ]; then
                timestamp=$(cat "$ts_file")
            else
                # fallback: snapshot mod time
                timestamp=$(stat -c %y "$snap" | cut -d'.' -f1 | tr ' ' '_')
            fi

            linkname="${interval}-${timestamp}"
            ln -sfn "$SNAPSHOT_DIR/$base" "$LINK_DIR/$linkname"
        done
    done

    echo "[INFO] rsnapshot links updated successfully."
}

# === MAIN RSNAPSHOT BACKUP ===
fn_backup_rsnapshot() {
    local rsnapconf="/data/backups/configuration/rsnapshot-${selfname}.conf"
    if [ ! -f "${rsnapconf}" ]; then
        fn_print_fail_nl "Missing rsnapshot config: ${rsnapconf}"
        fn_script_log_fail "Missing rsnapshot config: ${rsnapconf}"
        core_exit.sh
    fi

    fn_print_info_nl "Using rsnapshot config: ${rsnapconf}"
    fn_script_log_info "Running: rsnapshot -c ${rsnapconf} daily"

    if rsnapshot -c "${rsnapconf}" daily; then
        fn_print_ok_nl "rsnapshot backup completed"
        fn_script_log_pass "Backup completed using rsnapshot (daily)"

        # update symbolic links
        fn_update_symbolic_links

        alert="backup"
        alert.sh
    else
        fn_print_fail_nl "rsnapshot backup failed"
        fn_script_log_fail "Backup failed using rsnapshot (daily)"
        core_exit.sh
    fi
}

fn_backup_start_server() {
    if [ -n "${startserver}" ]; then
        exitbypass=1
        command_start.sh
        fn_firstcommand_reset
    fi
}

# ==== EXECUTION FLOW ====
fn_print_dots ""
check.sh
core_logs.sh
fn_backup_check_lockfile
fn_backup_create_lockfile
fn_backup_init
fn_backup_stop_server
fn_backup_dir
fn_backup_create_rsnapshot_conf
fn_backup_rsnapshot
fn_backup_start_server

rm -f "${lockdir:?}/backup.lock"
core_exit.sh