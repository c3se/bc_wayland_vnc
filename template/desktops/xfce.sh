# Make temporary xrdp .ini file pointing to right certs etc
TMPINI=$(mktemp)
echo "$INITEMPLATE" \
  | sed "s%certificate=*.%certificate=$HOME/.config/xrdp/xrdp.crt%g" \
  | sed "s%key_file=.*%key_file=$HOME/.config/xrdp/xrdp.key%g" \
  | sed "s%LogFile=.*%LogFile=/dev/stdout%g" \
  > $TMPINI

# Get xrdp port

# Ensure .xsession is correctly set up.
# dbus-launch is needed for multiple WMs.

ENV_VARS=""

if [[ ! -z "${OMP_NUM_THREADS}" ]]; then
    ENV_VARS="${ENV_VARS} OMP_NUM_THREADS=${OMP_NUM_THREADS}"
fi
if [[ ! -z "${TMPDIR}" ]]; then
    ENV_VARS="${ENV_VARS} TMPDIR=${TMPDIR}"
fi
if [[ ! -z "${SNIC_TMP}" ]]; then
    ENV_VARS="${ENV_VARS} SNIC_TMP=${SNIC_TMP}"
fi
if [[ ! -z "${APPTAINER_CACHEDIR}" ]]; then
    ENV_VARS="${ENV_VARS} APPTAINER_CACHEDIR=${APPTAINER_CACHEDIR}"
fi
if [[ ! -z "${VGL_DISPLAY}" ]]; then
    ENV_VARS="${ENV_VARS} VGL_DISPLAY=${VGL_DISPLAY}"
fi

runstr="'eval \$(dbus-launch --sh-syntax) && xfce4-session' > \$HOME/.xsession"
echo "echo $runstr" ' && eval $(dbus-launch --sh-syntax) && ' "${ENV_VARS} " 'xfce4-session' > $HOME/.xsession
chmod 744 $HOME/.xsession
# Start xrdp server listening to port in nodaemon mode
xrdp -p $port -c $TMPINI -n&

# Run xrdp-sesrun to force initiation of our session to ensure right cgroup.
DISPLAY=$(xrdp-sesrun -P $port | grep -oP 'display=\K.*(?= \w)')
echo "Display is $DISPLAY"
# start guacd
guacd -l $guacdport -b $(hostname -i) -C $HOME/.config/xrdp/xrdp.crt -K $HOME/.config/xrdp/xrdp.key -Linfo -f &
# pidwait for display server.
sleep 300

PID=$(pgrep -f "Xorg $DISPLAY ")
tail --pid "$PID" -f /dev/null & wait $!
