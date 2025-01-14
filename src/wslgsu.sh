# shellcheck shell=bash
isService=0
isWakeup=0
wa_gs_commd=""
wa_gs_dscp=""
wa_gs_name=""
wa_gs_user="root"

help_short="wslgsu [-u USERNAME] [-n NAME] [-S] SERVICE/COMMAND\nwslgsu [-hvw]"

while [ "$1" != "" ]; do
	case "$1" in
		-w|--wakeup) isWakeup=1; break;;
		-u|--user) shift; wa_gs_user="$1"; shift;;
		-n|--name) shift; wa_gs_name="$1"; shift;;
		-S|--service) isService=1; shift;;
		-h|--help) help "wslact" "$help_short"; exit;;
		-v|--version) version; exit;;
		*) wa_gs_commd="$*";break;;
	esac
done

debug_echo "isService: $isService"
debug_echo "isWakeup: $isWakeup"
debug_echo "wa_gs_commd: $wa_gs_commd"
debug_echo "wa_gs_dscp: $wa_gs_dscp"
debug_echo "wa_gs_name: $wa_gs_name"

wslutmpbuild=$(wslu_get_build)
[ "$wslutmpbuild" -ge "$BN_MAY_NINETEEN" ] || (echo "This tool is not supported before version 1903."; exit 34)

if [[ "$wa_gs_commd" != "" ]] || [[ $isWakeup -eq 1 ]]; then
	debug_echo "command or wakeup exist, executing"
	tmp_location="$(wslvar -s TMP)"
	tpath="$(double_dash_p "$tmp_location")" # Windows Temp, Win Double Sty.
	tpath_linux="$(wslpath "$tmp_location")" # Windows Temp, Linux WSL Sty.
	script_location_win="$(wslvar -s USERPROFILE)\\wslu" #  Windows wslu, Win Double Sty.
	script_location="$(wslpath "$script_location_win")" # Windows wslu, Linux WSL Sty.

	debug_echo "tmp_location: $tmp_location"
	debug_echo "tpath: $tpath"
	debug_echo "tpath_linux: $tpath_linux"
	debug_echo "script_location_win: $script_location_win"
	debug_echo "script_location: $script_location"

	# Check presence of sudo.ps1 and 
	wslu_file_check "$script_location" "sudo.ps1"
	wslu_file_check "$script_location" "runHidden.vbs"

	# check if it is a service, a command or it just want to wakeup
	if [[ $isWakeup -eq 1 ]]; then
		debug_echo "Entering wakeup"
		# handling no name given case
		if [[ "$wa_gs_name" = "" ]]; then
			debug_echo "No name given, using default"
			wa_gs_name="Wakeup"
		fi
		wa_gs_commd="wsl.exe -d $WSL_DISTRO_NAME echo"
		wa_gs_dscp="Wake up WSL Distro $WSL_DISTRO_NAME when computer start up; Generated By WSL Utilities"
	elif [[ $isService -eq 1 ]]; then
	# service
		debug_echo "Entering service"
		# handling no name given case
		if [[ "$wa_gs_name" = "" ]]; then
			debug_echo "No name given, using default"
			wa_gs_name="$wa_gs_commd"
		fi
		wa_gs_commd="wsl.exe -d $WSL_DISTRO_NAME -u $wa_gs_user service $wa_gs_commd start"
		wa_gs_dscp="Start service $wa_gs_name from $WSL_DISTRO_NAME when computer start up; Generated By WSL Utilities"
	else
	# command
		debug_echo "Entering command"
		# handling no name given case
		if [[ "$wa_gs_name" = "" ]]; then
			debug_echo "No name given, automatically generate"
			wa_gs_name=$(basename "$(echo "$wa_gs_commd" | awk '{print $1}')")
		fi
		wa_gs_commd="wsl.exe -d $WSL_DISTRO_NAME -u $wa_gs_user $wa_gs_commd"
		wa_gs_dscp="Executing following command \`$wa_gs_name\` from $WSL_DISTRO_NAME when computer start up; Generated By WSL Utilities"
	fi

	debug_echo "wa_gs_commd: $wa_gs_commd"
	debug_echo "wa_gs_dscp: $wa_gs_dscp"

	# Keep the name always unique; such random, much wow
	tmp_rand="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 6 | head -n 1)"

	debug_echo "tmp_rand: $tmp_rand"

	# shellcheck disable=SC2028
	tee "$tpath_linux"/tmp.ps1 >/dev/null << EOF 
Import-Module 'C:\\WINDOWS\\system32\\WindowsPowerShell\\v1.0\\Modules\\Microsoft.PowerShell.Utility\\Microsoft.PowerShell.Utility.psd1';
\$action = New-ScheduledTaskAction -Execute 'C:\\Windows\\System32\\wscript.exe' -Argument '$script_location_win\\runHidden.vbs $wa_gs_commd';
\$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries;
\$trigger =  New-ScheduledTaskTrigger -AtLogOn -User \$env:userdomain\\\$env:username; \$trigger.Delay = 'PT2M';
\$task = New-ScheduledTask -Action \$action -Trigger \$trigger -Description \"$wa_gs_dscp\" -Settings \$settings;
Register-ScheduledTask -InputObject \$task -TaskPath '\\' -TaskName 'WSLUtilities_Actions_Startup_${wa_gs_name}_${tmp_rand}' | out-null;
EOF

	debug_echo "$(cat "$tpath_linux"/tmp.ps1)"
	echo "${warn} WSL Utilities is adding \"${wa_gs_name}\" to Task Scheduler; A UAC Prompt will show up later. Allow it if you know what you are doing."
	if winps_exec "$script_location_win"\\sudo.ps1 "$tpath"\\tmp.ps1; then
		debug_echo "Task Scheduler added"
		rm -rf "$tpath_linux/tmp.ps1"
		echo "${info} Task \"${wa_gs_name}\" added."
	else
		rm -rf "$tpath_linux/tmp.ps1"
		error_echo "Adding Task \"${wa_gs_name}\" failed." 1
	fi
else
	error_echo "No input, aborting" 21
fi

unset isService
unset wa_gs_commd
unset wa_gs_name
unset wa_gs_user
