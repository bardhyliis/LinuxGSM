#!/bin/bash
# LinuxGSM fix_arksa.sh module
# Author: Your Name
# Based on: fix_arksa.sh by Daniel Gibbs
# Description: Resolves issues with ARK: Survival Ascended (ASA) on Linux.
# Note: ASA has no native Linux binary. It requires Proton/Wine to run.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

##################################
# Proton / Wine sanity checks
##################################

# Check if Proton or Wine is available
if ! command -v proton &>/dev/null && ! command -v wine &>/dev/null; then
    fixname="missing Proton/Wine"
    fn_fix_msg_start
    echo -e "ARK: Survival Ascended requires Proton (recommended) or Wine."
    echo -e "No Proton or Wine runtime was found in PATH."
    echo -e "Please install Proton (via Steam) or Wine and configure LGSM to use it."
    fn_fix_msg_end
fi

##################################
# Workshop / SteamCMD fixes
##################################

# removes multiple appworkshop_2430930.acf if found.
steamappsfilewc="$(find "${HOME}" -name appworkshop_2430930.acf | wc -l)"
if [ "${steamappsfilewc}" -gt "1" ]; then
    fixname="multiple appworkshop acf files (ASA)"
    fn_fix_msg_start
    find "${HOME}" -name appworkshop_2430930.acf -exec rm -f {} \;
    fn_fix_msg_end
elif [ "${steamappsfilewc}" -eq "1" ]; then
    # Steam mods directory selector (~/.steam vs ~/Steam)
    steamappsfile=$(find "${HOME}" -name appworkshop_2430930.acf)
    steamappsdir=$(dirname "${steamappsfile}")
    steamappspath=$(
        cd "${steamappsdir}" || return
        cd ../
        pwd
    )

    # remove broken SteamCMD symlink
    if [ -L "${serverfiles}/Engine/Binaries/ThirdParty/SteamCMD/Linux" ]; then
        fixname="broken SteamCMD symlink (ASA)"
        fn_fix_msg_start
        unlink "${serverfiles:?}/Engine/Binaries/ThirdParty/SteamCMD/Linux"
        fn_fix_msg_end
        check_steamcmd.sh
    fi

    # remove invalid SteamCMD directory if steamcmd.sh missing
    if [ ! -f "${serverfiles}/Engine/Binaries/ThirdParty/SteamCMD/Linux/steamcmd.sh" ]; then
        fixname="remove invalid ASA SteamCMD directory"
        fn_fix_msg_start
        rm -rf "${serverfiles:?}/Engine/Binaries/ThirdParty/SteamCMD/Linux"
        fn_fix_msg_end
        check_steamcmd.sh
    fi

    # fix incorrect steamapps symlink
    if [ -d "${serverfiles}/Engine/Binaries/ThirdParty/SteamCMD/Linux" ] && \
       [ -L "${serverfiles}/Engine/Binaries/ThirdParty/SteamCMD/Linux/steamapps" ] && \
       [ "$(readlink "${serverfiles}/Engine/Binaries/ThirdParty/SteamCMD/Linux/steamapps")" != "${steamappspath}" ]; then
        fixname="incorrect steamapps symlink (ASA)"
        fn_fix_msg_start
        unlink "${serverfiles:?}/Engine/Binaries/ThirdParty/SteamCMD/Linux/steamapps"
        fn_fix_msg_end
    fi

    # create steamapps symlink if missing
    if [ ! -L "${serverfiles}/Engine/Binaries/ThirdParty/SteamCMD/Linux/steamapps" ]; then
        fixname="steamapps symlink (ASA)"
        fn_fix_msg_start
        ln -s "${steamappspath}" "${serverfiles}/Engine/Binaries/ThirdParty/SteamCMD/Linux/steamapps"
        fn_fix_msg_end
    fi
fi

##################################
# Proton launch reminder
##################################

fixname="Proton launch reminder"
fn_fix_msg_start
echo -e "Reminder: ARK: Survival Ascended only ships Windows binaries."
echo -e "LinuxGSM must be configured to launch the server using Proton, e.g.:"
echo -e "  proton run ${serverfiles}/ShooterGame/Binaries/Win64/ShooterGameServer.exe <args>"
echo -e "Check your start parameters and Proton installation."
fn_fix_msg_end
