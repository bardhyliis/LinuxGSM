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

    # Write rsnapshot config
    cat > "${rsnapconf}" <<EOF
# Auto-generated rsnapshot config for LinuxGSM server
# Can be updated
config_version  1.2

cmd_rsync       /usr/bin/rsync
cmd_cp  /bin/cp

# Store actual snapshots here
snapshot_root   /data/backups/snapshots

# Retention policy: last 10 daily snapshots
retain  daily   10

rsync_long_args --relative --delete --delete-excluded

lockfile        /data/backups/rsnapshot-${selfname}.pid

# Backup source: everything inside serverfiles
backup  /data/serverfiles/./    ./

# Optional exclusions
exclude *.log
exclude *.tmp

# Logging
loglevel        3
logfile /data/backups/rsnapshot-${selfname}.log
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
	# 	fn_print_restart_warning
	# 	startserver="1"
	# 	exitbypass=1
	# 	command_stop.sh
	# 	fn_firstcommand_reset
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

# === MAIN RSNAPSHOT BACKUP ===
fn_backup_rsnapshot() {
    local rsnapconf="/data/backups/configuration/rsnapshot-${selfname}.conf"
    if [ ! -f "${rsnapconf}" ]; then
        fn_print_fail_nl "Missing rsnapshot config: ${rsnapconf}"
        fn_script_log_fail "Missing rsnapshot config: ${rsnapconf}"
        core_exit.sh
    fi

    fn_print_info "Using rsnapshot config: ${rsnapconf}"
    fn_script_log_info "Running: rsnapshot -c ${rsnapconf} daily"

    if rsnapshot -c "${rsnapconf}" daily; then
        fn_print_ok "rsnapshot backup completed"
        fn_script_log_pass "Backup completed using rsnapshot (daily)"

        # --- Create/update date symlinks in /data/backups/links ---
        # Why we create symlinks:
        # 1. Each snapshot folder created by rsnapshot is named daily.0, daily.1, etc.
        #    These names rotate with each backup, so daily.0 always points to the newest snapshot.
        # 2. To keep a permanent reference to the snapshot taken at a specific date/time,
        #    we create a symlink named with the folder's creation UTC timestamp (YYYYMMDDTHHMMSSZ)
        #    that points to the actual snapshot folder.
        # 3. This way, even after rotation, each timestamped symlink points to the correct snapshot folder.

        local links_dir="/data/backups/links"
        mkdir -p "${links_dir}"

        # --- Add a creation timestamp to the latest snapshot ---
        snapshots_dir="/data/backups/snapshots"
        links_dir="/data/backups/links"
        latest_snapshot=$(readlink -f "$snapshots_dir/daily.0")

        # Ensure latest snapshot always has a fresh timestamp
        echo "$(date -u +'%Y%m%dT%H%M%SZ')" > "${latest_snapshot}/.created_at"

        # --- Update symlinks for all snapshots ---
        for snap in "$snapshots_dir"/daily.*; do
            [ -d "$snap" ] || continue
            if [ -f "$snap/.created_at" ]; then
                timestamp=$(cat "$snap/.created_at")
            else
                timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
                echo "$timestamp" > "$snap/.created_at"
            fi
            ln -sfn "$snap" "${links_dir}/${timestamp}"
            fn_script_log_info "Updated symlink: ${links_dir}/${timestamp} -> $snap"
        done

        # --- Cleanup orphaned symlinks ---
        for link in "$links_dir"/*; do
            [ -L "$link" ] || continue   # only process symlinks
            ts=$(basename "$link")

            found=false
            for snap in "$snapshots_dir"/daily.*; do
                [ -d "$snap" ] || continue
                if [ -f "$snap/.created_at" ] && [ "$ts" = "$(cat "$snap/.created_at")" ]; then
                    found=true
                    break
                fi
            done

            if [ "$found" = false ]; then
                rm -f "$link"
                fn_script_log_info "Removed orphaned symlink: $link"
            fi
        done

        # Trigger alert
        alert="backup"
        alert.sh
    else
        fn_print_fail "rsnapshot backup failed"
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