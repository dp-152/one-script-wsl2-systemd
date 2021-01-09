SYSTEMD_EXE="$(command -v systemd)"

if [ -z "$SYSTEMD_EXE" ]; then
        if [ -x "/usr/lib/systemd/systemd" ]; then
                SYSTEMD_EXE="/usr/lib/systemd/systemd"
        else
                SYSTEMD_EXE="/lib/systemd/systemd"
        fi
fi

SYSTEMD_EXE="$SYSTEMD_EXE --unit=multi-user.target" # snapd requires multi-user.target not basic.target
SYSTEMD_PID="$(ps -eo pid=,args= | awk '$2" "$3=="'"$SYSTEMD_EXE"'" {print $1}')"

if [ -z "$SYSTEMD_PID" ] || [ "$SYSTEMD_PID" -ne 1 ]; then
	echo "System is not in systemd namespace - running script..."
        if [ -z "$SUDO_USER" ]; then
                export > "$HOME/.profile-systemd"
        fi

        if [ "$USER" != "root" ]; then
                exec sudo /bin/sh "/etc/profile.d/00-wsl2-systemd.sh"
        fi

	env_file="/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)-wsl2-systemd-env.sh"

        echo "WSL_INTEROP='$WSL_INTEROP'" > $env_file
        echo "DISPLAY='$(awk '/nameserver/ { print $2":0" }' /etc/resolv.conf)'" >> $env_file

	. $env_file
	unset env_file

        if [ -z "$SYSTEMD_PID" ]; then
                env -i /usr/bin/unshare --fork --mount-proc --pid -- sh -c "
                        mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
                        exec $SYSTEMD_EXE
                       " &
                while [ -z "$SYSTEMD_PID" ]; do
                        SYSTEMD_PID="$(ps -eo pid=,args= | awk '$2" "$3=="'"$SYSTEMD_EXE"'" {print $1}')"
                        sleep 1
                done
        fi

        exec /usr/bin/nsenter --all --target "$SYSTEMD_PID" -- su - "$SUDO_USER"
fi

unset SYSTEMD_EXE
unset SYSTEMD_PID

[ -f "$HOME/.profile-systemd" ] && source "$HOME/.profile-systemd"

if [ -d "$HOME/.wslprofile.d" ]; then
        for script in "$HOME/.wslprofile.d/"*; do
                source "$script"
        done
        unset script
fi
echo "Systemd environment loaded"
clear

