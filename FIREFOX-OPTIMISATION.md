# Firefox optimisation record

Date: 2026-08-28

This records the conservative Firefox changes made for an Arch Linux laptop
with 8 GiB RAM running Hyprland.

## Original state

- Firefox was not installed before this work. It is now the Arch package
  `firefox 154.0-1` from the configured official Arch repository.
- The active profile is
  `/home/kiy/.mozilla/firefox/y07w7tai.default-release`.
- The profile was newly created for this setup and had no third-party
  extensions or user-created bookmarks, passwords, cookies, history, or
  sessions before the work. Firefox-generated profile databases and defaults
  were preserved.
- The session is Wayland/Hyprland:
  `XDG_SESSION_TYPE=wayland`, `WAYLAND_DISPLAY=wayland-1`,
  `XDG_CURRENT_DESKTOP=Hyprland`, and `DISPLAY=:0`.
- Existing relevant environment values were
  `GDK_BACKEND=wayland,x11,*`, `GDK_SCALE=1`,
  `QT_QPA_PLATFORM=wayland;xcb`, `XDG_BACKEND=wayland`, and
  `MOZ_ENABLE_WAYLAND=1`.
- `MOZ_ENABLE_WAYLAND=1` comes from the existing Omarchy default at
  `/usr/share/omarchy/default/hypr/envs.lua`. That system file was not edited.
  Firefox 154 was also tested without the variable and still appeared as a
  native Wayland client, so no additional obsolete override was added.
- Existing extensions were Firefox built-ins only: WebCompat, Form Autofill,
  Picture-in-Picture, IPP activator, Add-ons search detection, the built-in
  New Tab component, and the default theme. Inactive built-in themes remain
  optional and were not removed.
- No custom `user.js` existed before this work. Firefox's normal `prefs.js`
  was recorded before changes and was not hand-edited while Firefox was running.

## Backup

The pre-change profile/configuration backup is:

`/home/kiy/firefox-optimisation-backups/20260828-014411-pre-change/`

It contains a copy of the Firefox configuration directory and
`baseline-record.txt`, including the original `profiles.ini`, environment,
preferences, extension metadata, and checksums. The profile was new and was
active during the copy; rapidly changing empty IndexedDB files could not all
be copied, but the important configuration files were captured. Do not delete
this backup until the new setup has been used successfully.

## Hardware and graphics findings

- GPU: Intel WhiskeyLake-U GT2 / UHD Graphics 620 (`8086:3ea0`).
- Kernel graphics driver: `i915`.
- Mesa OpenGL reports accelerated rendering and the Intel UHD 620 renderer.
- EGL's Wayland platform reports the same accelerated Intel renderer.
- VA-API uses the Intel iHD driver from `intel-media-driver 26.2.4-1`.
- `vainfo` exposes hardware VLD decode for H.264, HEVC, VP8, and VP9. AV1
  decode was not exposed by this GPU/driver combination.
- Firefox telemetry recorded `gfx.linux_window_protocol=wayland` and decoder
  support for H.264, HEVC, VP8, and VP9.

No force-enable or force-disable graphics preferences were added. WebRender,
WebGL, sandboxing, site isolation/Fission, WebRTC, DRM, JavaScript, HTTPS
protections, certificate validation, and Firefox's normal cache/prefetch
defaults were left intact.

Useful commands for rechecking the system are:

```sh
glxinfo -B
eglinfo -B
vainfo
hyprctl clients -j | jq '.[] | select(.class == "firefox") | {pid,title,xwayland}'
```

In Firefox, `about:support` should be used for the user-visible final check;
the relevant entries are Window Protocol, Compositing, WebGL Renderer, and
hardware video decoding. `about:processes` shows live process and memory use.

## Changes made

### Firefox preferences

Created the small profile file
`/home/kiy/.mozilla/firefox/y07w7tai.default-release/user.js`:

```js
user_pref("dom.ipc.processCount", 4);
user_pref("dom.ipc.processCount.webIsolated", 2);
user_pref("browser.sessionstore.restore_on_demand", true);
```

Rationale:

- The two process-count values reduce duplicated baseline memory on an 8 GiB
  machine while retaining Fission/site isolation. They are limits, not a
  security disablement.
- Lazy session restoration keeps saved tabs in the session while avoiding
  loading every tab simultaneously after restart.

Firefox's built-in `browser.tabs.unloadOnLowMemory` remains enabled by
default. No manual cache-size, predictor, WebGL, sandbox, HTTPS, DRM, or
security-tuning preferences were added because their likely benefit was small
or their compatibility/security cost was unjustified.

Firefox also currently has `extensions.autoDisableScopes=0` in generated
`prefs.js` as a consequence of registering the locally placed, signed AMO
XPI files. It is not in `user.js`, is not a performance setting, and was not
used to weaken site security. A future clean reinstall through the Add-ons
Manager or restoring the backup will remove this profile-install artifact.

### Extensions

Installed from the official Mozilla Add-ons download endpoints:

- [uBlock Origin](https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/),
  by Raymond Hill, version 1.74.0, ID `uBlock0@raymondhill.net` — **Keep**.
- [Auto Tab Discard](https://addons.mozilla.org/en-US/firefox/addon/auto-tab-discard/),
  by tlintspr, version 0.7.3, ID
  `{c2c003ee-bd69-42a2-b0e9-6f34222cb046}` — **Keep**.

uBlock Origin's normal default filter lists were retained. No second ad
blocker or overlapping privacy blocker was installed.

Auto Tab Discard was configured through its options page as follows:

- time-based discard period: 25 minutes;
- six-tab trigger retained;
- pinned tabs protected;
- tabs playing audio protected;
- paused media protected;
- changed form data protected;
- no invented whitelist entries were added;
- memory-triggered discard and idle-time discard were not enabled.

Extension classification after inspection:

- Keep: uBlock Origin; Auto Tab Discard; Firefox's WebCompat, Form Autofill,
  Picture-in-Picture, IPP activator, Add-ons search detection, New Tab, and
  default theme components.
- Optional: inactive built-in Firefox themes (Alpenglow, Compact Dark, and
  Compact Light). They were left installed because they are built-ins and do
  not create the background-work concerns of third-party extensions.
- Remove: none.
- Potentially problematic: none identified.

## Wayland and Hyprland integration

Firefox is running natively under Wayland. Hyprland's client data showed
`xwayland=false` for Firefox after installation, restart, and functional
tests. Monitor scale is 1.0 at 1920x1080, so no fractional-scaling workaround
was appropriate. GTK/Wayland integration was left to the existing session
defaults; no custom CSS/theme framework or Hyprland configuration was added.

Smooth scrolling, touchpad scrolling, the GTK file picker, downloads, and
Firefox's normal dark/light integration were not overridden with obscure
preferences.

## Verification and observations

Completed checks:

- Firefox started successfully after installation and after a full restart.
- A normal HTTPS page (`example.com`) loaded successfully.
- WebGL 2 context creation succeeded and reported an Intel renderer.
- YouTube's Big Buck Bunny test video created a video element, reached
  `readyState=4`, had no media error, and advanced playback for five seconds.
  The test was muted to avoid unexpectedly playing sound; the video selected
  by YouTube was 854x480 rather than a controlled 1080p stream.
- Both requested extensions were active after restart:
  `active=true`, `userDisabled=false`, and `appDisabled=false`.
- Auto Tab Discard's settings were read back after restart and still reported
  25 minutes, pinned/audio/paused-media/form protection enabled.
- Firefox remained `xwayland=false` after restart.

Approximate aggregate RSS samples over the Firefox parent and descendants:

| Sample | Processes | Aggregate RSS | Notes |
|---|---:|---:|---|
| Before changes, five active test sites | not retained as an exact count | about 3.1 GiB | rough startup/page-load sample |
| After changes, five active test sites | 18 | about 2.5 GiB | rough settled sample; network/YouTube CPU was still noisy |
| After restart, blank/settled browser | 11 | about 1.3 GiB | includes Firefox and extension/process overhead |

The five-tab comparison is directional rather than a benchmark: page content,
network state, and process lifetime were not perfectly identical. The useful
result is that the conservative process cap reduced the observed five-tab RSS
without disabling site isolation or acceleration.

Opening a native file chooser and selecting a real download destination was
not automated because it requires an interactive user path choice. No
download, bookmark, password, cookie, history, or session data was deleted.
For the final user check, open a normal download link and an HTML file input,
then confirm the GTK chooser and the configured Downloads directory behave as
expected.

## Reverting

The safest complete rollback is recoverable because the current profile is
moved aside before the backup is restored. Close Firefox first:

```sh
firefox --quit

stamp=$(date +%Y%m%d-%H%M%S)
mv /home/kiy/.mozilla/firefox "/home/kiy/.mozilla/firefox.after-optimisation-$stamp"
cp -a /home/kiy/firefox-optimisation-backups/20260828-014411-pre-change/firefox \
  /home/kiy/.mozilla/firefox
```

The moved `firefox.after-optimisation-*` directory is a recovery copy. Keep
it until the restored profile has been checked.

To disable only the performance preferences while preserving current Firefox
data, close Firefox and rename the file we created:

```sh
mv /home/kiy/.mozilla/firefox/y07w7tai.default-release/user.js \
   /home/kiy/.mozilla/firefox/y07w7tai.default-release/user.js.optimisation-disabled
```

Restart Firefox after either rollback. The diagnostic-only packages can be
removed separately if no longer useful:

```sh
sudo pacman -R mesa-utils libva-utils
```

Do not remove `intel-media-driver`, Mesa, FFmpeg, or Firefox as part of a
rollback unless that is separately intended.
