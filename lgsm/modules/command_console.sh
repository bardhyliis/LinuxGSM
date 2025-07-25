#!/bin/bash
# LinuxGSM command_console.sh module
# Author: Daniel Gibbs
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Gives access to the server tmux console.

commandname="CONSOLE"
commandaction="Access Console"
moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
fn_firstcommand_set

fn_print_header

check.sh

if [ "${consoleverbose}" == "yes" ]; then
	echo -e "* Verbose output: ${lightgreen}yes${default}"
elif [ "${consoleverbose}" == "no" ]; then
	echo -e "* Verbose output: ${red}no${default}"
else
	echo -e "* Verbose output: ${red}unknown${default}"
fi

if [ "${consoleinteract}" == "yes" ]; then
	echo -e "* Interactive output: ${lightgreen}yes${default}"
elif [ "${consoleinteract}" == "no" ]; then
	echo -e "* Interactive output: ${red}no${default}"
else
	echo -e "* Interactive output: ${red}unknown${default}"
fi
echo ""
fn_print_information_nl "Press ${italic}\"CTRL+b\"${default} then ${italic}\"d\"${default} to exit console."
fn_print_warning_nl "Do ${underline}NOT${default} press CTRL+c to exit. This will stop the server."
echo -e ""
#echo -e "${italic}https://docs.linuxgsm.com/commands/console${default}"
if ! fn_prompt_yn "Continue?" Y; then
	exitcode=0
	core_exit.sh
fi
fn_print_dots "Accessing console"
check_status.sh
if [ "${status}" != "0" ]; then
	fn_print_ok_nl "Accessing console"
	fn_script_log_pass "Console accessed"
	tmux -L "${socketname}" attach-session -t "${sessionname}"
	fn_print_ok_nl "Closing console"
	fn_script_log_pass "Console closed"
else
	fn_print_error_nl "Server not running"
	fn_script_log_error "Failed to access: Server not running"
	if fn_prompt_yn "Do you want to start the server?" Y; then
		exitbypass=1
		command_start.sh
		fn_firstcommand_reset
	fi
fi

core_exit.sh
