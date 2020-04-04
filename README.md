gpufreq
=======

This script allows you to show the current GPU frequency of a Linux DRM GPU. It should work with
both AMD and Intel GPUs, though Intel is currently untested.


Installation
------------

Symlink or copy `gpufreq.lua` into your mpv scripts directory (e.g. `~/.config/mpv/scripts/`.) Then
run `ls /sys/class/drm/` to show a list of cards; usually your card should be `card0`.

Add a keybinding in your `input.conf` to the command `script-message show-gpu-freq "cardnamehere"`
where `cardnamehere` is the card identifier from the previous step. For example,
`U script-message show-gpu-freq "card0"` would show the frequency of `card0` when you press shift+u.
