userresources=$HOME/.Xresources
userdefaults=$HOME/.Xdefaults
usermodmap=$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap
# merge in defaults and keymaps
if [ -f $sysresources ]; then
    xrdb -merge $sysresources
fi
if [ -f $sysmodmap ]; then
    xmodmap $sysmodmap
fi
if [ -f "$userresources" ]; then
    xrdb -merge "$userresources"
fi
if [ -f "$userdefaults" ]; then
    xrdb -merge "$userdefaults"
fi
if [ -f "$usermodmap" ]; then
    xmodmap "$usermodmap"
fi
LANG='ja_JP' scim -d
export XMODIFIERS=@im=SCIM
export GTK_IM_MODULE="scim"
export QT_IM_MODULE="scim"
setxkbmap -layout us -variant dvorak -option compose:menu -option numpad:shift3 -option kpdl:semi -option keypad:atm -option caps:shift
#exec awesome
exec i3
