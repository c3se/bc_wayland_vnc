# Make temporary xrdp .ini file pointing to right certs etc
TMPINI=$(mktmp)
echo $INITEMPLATE \
  | sed "s%certificate=*.%certificate=$HOME/.config/xrdp/xrdp.crt%g" \
  | sed "s%key_file=.*%key_file=$HOME/.config/xrdp/xrdp.key%g" \
  | sed "s%LogFile=.*%LogFile=/dev/stdout%g" \
  > $TMPINI

# Get xrdp port
port=$(find_port)

# Ensure .xsession is correctly set up.
# dbus-launch is needed for multiple WMs.
echo 'eval $(dbus-launch --sh-syntax)
xfce4-session' > $HOME/.xsession
chmod 744 $HOME/.xsession

# Start xrdp server listening to port in nodaemon mode
xrdp -p $port -c $TMPINI -n&

# Run xrdp-sesrun to force initiation of our session to ensure right cgroup.
DISPLAY=$(xrdp-sesrun -P $port | grep -oP 'display=\K.*(?= \w)')

# pidwait for display server.
pidwait -ef "Xorg $DISPLAY"
