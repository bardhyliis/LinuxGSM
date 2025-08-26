#!/bin/bash
# LinuxGSM command_backup_rs.sh module
# Author: Bardhyl fork
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Creates an rsnapshot backup instead of a compressed archive.

commandname="BACKUP"
commandaction="Backup (rsnapshot)"
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
		if [ "$(find "${lockdir}/backup.lock" -mmin +60)" ]; then
			fn_print_warn_nl "Removing stale lockfile"
			fn_script_log_warn "Removing stale lockfile"
			rm -f "${lockdir:?}/backup.lock"
		else
			fn_print_info_nl "Lockfile found: Backup already running"
			fn_script_log_error "Backup already running: ${lockdir}/backup.lock"
			core_exit.sh
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
cmd_cp          /bin/cp

# Store actual snapshots here
snapshot_root   /data/backups/snapshots

# Retention policy: last 10 daily snapshots
retain  daily   10

rsync_long_args --relative --delete --delete-excluded

lockfile        /var/run/rsnapshot-${selfname}.pid

# Backup source: everything inside serverfiles
backup  /data/serverfiles/./   ./

# Optional exclusions
exclude *.log
exclude *.tmp

# Logging
loglevel 3
logfile /var/log/rsnapshot-${selfname}.log
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
	if [ "${stoponbackup}" == "off" ]; then
		if [ "${status}" != "0" ]; then
			fn_print_warn_nl "${selfname} is running, backup while live may risk corruption."
			fn_script_log_warn "Backup taken while server is running"
		fi
	elif [ "${status}" != "0" ]; then
		fn_print_restart_warning
		startserver="1"
		exitbypass=1
		command_stop.sh
		fn_firstcommand_reset
	fi
}

fn_backup_dir() {
	# Create lockfile directory if missing
	if [ ! -d "${lockdir}" ]; then
		mkdir -p "${lockdir}"
	fi
}

fn_backup_create_lockfile() {
	date '+%s' > "${lockdir:?}/backup.lock"
	fn_script_log_info "Backup lockfile generated: ${lockdir}/backup.lock"
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
        
        # --- Create/update date symlink in /data/backups/links ---
        # Why we create symlinks:
        # 1. Each snapshot folder created by rsnapshot is named daily.0, daily.1, etc.
        #    These names rotate with each backup, so daily.0 always points to the newest snapshot.
        # 2. To keep a permanent reference to the snapshot taken at a specific date/time,
        #    we create a symlink named with a UTC timestamp (ISO 8601 style, YYYYMMDDTHHMMSSZ)
        #    that points to the actual daily.0 snapshot folder at the time of backup.
        # 3. This symlink can be used later during restore, so you can reliably restore
        #    the exact snapshot taken at that timestamp, even after rsnapshot rotates
        #    daily.0 to daily.1, daily.1 to daily.2, etc.
        #    Example timestamp: 20250826T063012Z
        local links_dir="/data/backups/links"
        mkdir -p "${links_dir}"
        timestamp=$(date -u +'%Y%m%dT%H%M%SZ')
        latest_snapshot=$(readlink -f /data/backups/snapshots/daily.0)
        ln -sfn "${latest_snapshot}" "${links_dir}/${timestamp}"
        fn_script_log_info "Updated date symlink: ${links_dir}/${timestamp} -> ${latest_snapshot}"

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
