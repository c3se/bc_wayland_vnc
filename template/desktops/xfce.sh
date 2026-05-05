export XDG_RUNTIME_DIR=$(mktemp -d)
export VNC_CONFIG_DIR=$(mktemp -d -p $XDG_RUNTIME_DIR)
export VNC_CONFIG_FILE=$( mktemp -p $VNC_CONFIG_DIR )
export SESSION_FILE=$(mktemp)
export WAYVNC_UDS_PATH=$XDG_RUNTIME_DIR/wayvnc-uds-$SLURM_JOBID
export WAYVNC_CTL_PATH=$XDG_RUNTIME_DIR/wayvnc-ctl-$SLURM_JOBID
export VNC_DISPLAY_FILE=$(mktemp)
export XFCE_PID_FILE=$(mktemp)
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -sha384 \
	-days 3650 -nodes -keyout $VNC_CONFIG_DIR/tls_key.pem -out $VNC_CONFIG_DIR/tls_cert.pem \
	-subj /CN=localhost \
	-addext subjectAltName=DNS:localhost,DNS:localhost,IP:127.0.0.1

module use "$MODULEPATH:/apps/Test/fmodules/all"
module load labwc Xfce wayvnc FFmpeg sway

cat > $VNC_CONFIG_FILE << EOF
use_relative_paths=true
enable_auth=true
enable_pam=true
private_key_file=tls_key.pem
certificate_file=tls_cert.pem
EOF

# Try to delay startup of swaybg so that it covers xfdesktop, better ways might exist
sleepstr1="while [ \$(ps -p \$(pgrep -U \$(id -u) xfce4-session | tail -n1) 1>/dev/null && echo 0 || echo 1) ]; do sleep 0.1; done; sleep 0.5"
sleepstr2="while [ \$(ps -p \$(pgrep -U \$(id -u) xfdesktop | tail -n1) 1>/dev/null && echo 0 || echo 1) ]; do sleep 0.1; done; sleep 0.5"
sleepstr3="while [ \$(ps -p \$(pgrep -U \$(id -u) xfce4-panel | tail -n1) 1>/dev/null && echo 0 || echo 1) ]; do sleep 0.1; done; sleep 0.5"

cat > $SESSION_FILE << EOF
echo "\$WAYLAND_DISPLAY" > $VNC_DISPLAY_FILE
xfce4-session &
export XFCE_PID="\$!"
wayvnc -f120 -C $VNC_CONFIG_FILE -S $WAYVNC_CTL_PATH -u $WAYVNC_UDS_PATH &
$sleepstr1
$sleepstr2
$sleepstr3
swaybg -i $EBROOTXFCE/share/backgrounds/xfce/xfce-leaves.svg -m fill &
wait \$XFCE_PID
EOF

chmod 744 $SESSION_FILE
export WLR_BACKENDS=headless
export WLR_LIBINPUT_NO_DEVICES=1
export XDG_SESSION_TYPE=wayland
has_gpu=$(nvidia-smi &> /dev/null && echo 1 || echo 0)
if [ "$has_gpu" -eq 1 ]; then
   export WLR_RENDER_DRM_DEVICE=$(readlink -f /dev/dri/by-path/pci-$(nvidia-smi --query-gpu=gpu_bus_id | tail -n1 | cut -c 5- | tr '[:upper:]' '[:lower:]')-render)
   export WLR_RENDERER=vulkan
   export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json
   export VK_IMPLICIT_LAYER_PATH=/usr/share/vulkan/implicit_layer.d/
   export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
   export __EGL_VENDOR_LIBRARY_DIRS=/usr/share/glvnd/egl_vendor.d/
   export GBM_BACKENDS_PATH=/usr/lib64/gbm
   export GBM_BACKEND=nvidia-drm
else
   export WLR_RENDERER=pixman
fi
eval $(dbus-launch --sh-syntax)
labwc -S $SESSION_FILE &
PID=$!
module purge
rfbwebsockify $port --unix-target=$WAYVNC_UDS_PATH &
# pidwait for display server.

echo "Display is $(cat $VNC_DISPLAY_FILE)"

echo "xfce pid is $(cat $XFCE_PID_FILE)"

wait $PID
