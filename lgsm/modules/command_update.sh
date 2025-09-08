#!/bin/bash
# LinuxGSM command_update.sh module
# Author: Daniel Gibbs
# Contributors: https://linuxgsm.com/contrib
# Website: https://linuxgsm.com
# Description: Handles updating of servers.

commandname="UPDATE"
commandaction="Updating"
moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"
fn_firstcommand_set

# If the environment variable INLINE_SERVERVERSION is set, use it as the serverversion.
# This will override the value that would normally be read from instance.cfg.
# If INLINE_SERVERVERSION is not set, the script continues normally using the configured server version.
if [ -n "$INLINE_SERVERVERSION" ]; then
	fn_print_info_nl "Using inline game version: $INLINE_SERVERVERSION"
	#serverversion overwritten
    serverversion="$INLINE_SERVERVERSION"
fi

fn_print_dots ""
check.sh
core_logs.sh
check_last_update.sh

if [ "${shortname}" == "ts3" ]; then
	update_ts3.sh
elif [ "${shortname}" == "mc" ]; then
	update_mc.sh
elif [ "${shortname}" == "fm" ]; then
	update_fm.sh
elif [ "${shortname}" == "rm" ]; then
	update_rm.sh
elif [ "${shortname}" == "quilt" ]; then
	update_quilt.sh
elif [ "${shortname}" == "fabric" ]; then
	update_fabric.sh
elif [ "${shortname}" == "mohist" ]; then
	update_mohist.sh
elif [ "${shortname}" == "neoforge" ]; then
	update_neoforge.sh
elif [ "${shortname}" == "purpur" ]; then
	update_purpur.sh
elif [ "${shortname}" == "spigot" ]; then
	update_spigot.sh
elif [ "${shortname}" == "tmodloader" ]; then
	update_tmodloader.sh
elif [ "${shortname}" == "mcb" ]; then
	update_mcb.sh
elif [ "${shortname}" == "pmc" ] || [ "${shortname}" == "vpmc" ] || [ "${shortname}" == "wmc" ]; then
	update_pmc.sh
elif [ "${shortname}" == "fctr" ]; then
	update_fctr.sh
elif [ "${shortname}" == "mta" ]; then
	update_mta.sh
elif [ "${shortname}" == "jk2" ]; then
	update_jk2.sh
elif [ "${shortname}" == "vints" ]; then
	update_vints.sh
elif [ "${shortname}" == "ut99" ]; then
	update_ut99.sh
elif [ "${shortname}" == "xnt" ]; then
	update_xnt.sh
else
	update_steamcmd.sh
fi

# remove update lockfile.
rm -f "${lockdir:?}/update.lock"

core_exit.sh
