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

env_file="$(mktemp /tmp/XXXXXXXXXX-wsl2-systemd-env.sh)"

if [ -z "$SYSTEMD_PID" ] || [ "$SYSTEMD_PID" -ne 1 ]; then
    echo "System is not in systemd namespace - running script..."
    if [ -z "$SUDO_USER" ]; then
        echo "Exporting environment variables..."
        $(which bash) -c export >"$HOME/.profile-systemd"
    fi

    if [ "$USER" != "root" ]; then
        echo "User is not root - re-running script as sudo..."
        exec sudo /bin/sh "/etc/profile.d/00-wsl2-systemd.sh"
    fi
    echo "env_file=$env_file"
    echo "declare -x WSL_INTEROP='$WSL_INTEROP'" >$env_file
    echo "declare -x DISPLAY=$(ip route | awk '/^default/{print $3}'):0.0" >>$env_file

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
[ -n $(cat "$env_file" ) ] && source $env_file
unset env_file

if [ -d "$HOME/.wslprofile.d" ]; then
    for script in "$HOME/.wslprofile.d/"*; do
        source "$script"
    done
    unset script
fi
