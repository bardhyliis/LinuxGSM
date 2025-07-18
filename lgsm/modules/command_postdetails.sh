#!/bin/bash
# LinuxGSM command_postdetails.sh module
# Author: Daniel Gibbs
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Strips sensitive information out of Details output.

commandname="POST-DETAILS"
commandaction="Post Details"
moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
fn_firstcommand_set

fn_bad_postdetailslog() {
	fn_print_fail_nl "Unable to create temporary file ${postdetailslog}."
	core_exit.sh
}

# source all of the modules defined in the details command.
info_messages.sh

# Remove any existing postdetails.log file.
if [ -f "${postdetailslog}" ]; then
	rm -f "${postdetailslog:?}"
fi

# Rather than a one-pass sed parser, default to using a temporary directory.
if [ "${exitbypass}" ]; then
	postdetailslog="${alertlog}"
else
	# Run checks and gathers details to display.
	check.sh
	info_game.sh
	info_distro.sh
	info_messages.sh
	for queryip in "${queryips[@]}"; do
		query_gamedig.sh
		if [ "${querystatus}" == "0" ]; then
			break
		fi
	done
	touch "${postdetailslog}" || fn_bad_postdetailslog
	{
		fn_info_messages_distro
		fn_info_messages_server_resource
		fn_info_messages_gameserver_resource
		fn_info_messages_gameserver
		fn_info_messages_script
		fn_info_messages_backup
		# Some game servers do not have parms.
		if [ "${shortname}" != "jc2" ] && [ "${shortname}" != "jc3" ] && [ "${shortname}" != "dst" ] && [ "${shortname}" != "pz" ] && [ "${engine}" != "renderware" ]; then
			fn_info_messages_commandlineparms
		fi
		fn_info_messages_ports_edit
		fn_info_messages_ports
		fn_info_messages_select_engine
		fn_info_messages_statusbottom
	} | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g" | tee -a "${postdetailslog}" > /dev/null 2>&1
fi

fn_print_dots "termbin.com"
link=$(cat "${postdetailslog}" | {
	nc -w 3 termbin.com 9999
	echo $? > /tmp/nc_exit_status
} | tr -d '\n\0')
nc_exit_status=$(cat /tmp/nc_exit_status)
if [ "${nc_exit_status}" -ne 0 ]; then
	fn_print_error_nl "Failed to post to termbin.com"
	fn_script_log_error "Failed to post to termbin.com"
else
	fn_print_ok_nl "termbin.com for 30D"
	fn_script_log_pass "termbin.com for 30D"
	pdurl="${link}"

	if [ "${firstcommandname}" == "POST-DETAILS" ]; then
		echo -e ""
		echo -e "Please share the following url for support: "
		echo -e "${italic}${pdurl}${default}"
	fi
	fn_script_log_info "${pdurl}"
	alerturl="${pdurl}"
fi

if [ -z "${exitbypass}" ]; then
	core_exit.sh
fi
