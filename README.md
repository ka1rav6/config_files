# dotfiles

Every config file for one machine: a Hyprland desktop on Ubuntu 24.04, with a
Quickshell panel layer, a Lua-configured compositor, Neovim, zsh and about
forty smaller tools.

**This is a snapshot repo, not a symlink farm.** Nothing in `~` is a link into
here. `config-backup` walks a list of paths and *copies* them in; restoring
copies them back out. So you can delete this whole directory and the machine
keeps working — and editing a file in here changes nothing until you copy it
back.

## The machine this describes

| | |
| --- | --- |
| OS | Ubuntu 24.04.5 LTS (noble) |
| Compositor | Hyprland 0.56.2 — PPA build, configured in **Lua**, not `hyprland.conf` |
| Panel / dock / OSD | Quickshell 0.3.1, built from source against Qt 6.8.3 |
| Status bar | Waybar (fed by small C daemons over Hyprland IPC) |
| Launcher / logout | wofi, wlogout |
| Notifications | mako |
| Terminal | Ghostty (PPA), Kitty as fallback |
| Shell | zsh + oh-my-zsh |
| Editor | Neovim (LazyVim), VS Code user settings |
| Audio | PipeWire |
| Theming | `theme-switch` driving matugen |

Hardware-specific bits are in the tracked configs and will need editing:
`window-manager/hypr/monitors.lua` (two outputs, 1.5× internal panel),
`touchscreen.lua` (an ELAN digitizer that interrupt-storms and gets unbound by
tablet-mode), and `lid.lua`.

---

## Setting up a new Ubuntu machine

Steps 1–4 install software, step 5 drops every config into place, steps 6–11
are the parts that need a compiler, a service enabled, or a login. Do them in
order: the Quickshell build (4) has to exist before the restored launcher
wrapper (5) will run.

### 1. Repositories

These five supply Hyprland, Ghostty, fastfetch, the dank utilities and a
newer GCC — none of which noble has. Add them before installing anything.

```bash
sudo add-apt-repository -y ppa:cppiber/hyprland
sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu
sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
sudo add-apt-repository -y ppa:avengemedia/danklinux
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt update
```

### 2. apt packages

`packages_installed.txt` is the list of manually-installed packages from the
live machine (305 of them: the whole Hyprland stack, the C/C++ toolchain,
PipeWire, fonts).

```bash
xargs -a packages_installed.txt sudo apt install -y
```

That will almost certainly fail with `Unable to locate package`, and apt
installs **nothing** when any name on the command line is unknown — a handful
of entries (`code`, `brave-browser`, `docker.io`/`containerd.io`,
`claude-desktop`, `chatgpt`, `arduino`, `blender`) come from vendor repos or
downloaded `.deb`s that are not configured yet. Either add those repos first,
or install one package at a time so the unknown ones are the only casualties:

```bash
xargs -a packages_installed.txt -rn1 sudo apt install -y
```

It is much slower, and it prints a clean list of exactly what it could not
find, which is the list of vendor repos you still have to add.

`sudoapts.txt` is *not* an install list — it is a grep of shell history for
`sudo apt install`, failures included (there is a line in there where `neovide`
turned out not to be an apt package at all). It is a record of how the machine
got here, useful for archaeology, not for running.

### 3. The tools apt does not have

None of these are in this repo: the backup skips anything over 2 MB, which
means every compiled binary. Install them from upstream.

| Tool | Where it comes from | Lands in |
| --- | --- | --- |
| Neovim | upstream release tarball (apt's is too old for LazyVim) | `~/.local/bin/nvim` |
| matugen | `just theme-install-matugen` (after step 5) — not packaged for noble | `~/.local/bin/matugen` |
| yazi, just, zoxide | cargo, or GitHub releases | `~/.local/bin` |
| lazygit | GitHub release | `/usr/local/bin/lazygit` |
| cppman | `pipx install cppman` | pipx shim |
| rustup + cargo tools | `rustup`, then `cargo install cargo-tauri satty` | `~/.cargo/bin` |
| snaps | `sudo snap install obsidian glow asciiquarium go ruff` | snap |

`fd` on this machine is a symlink to apt's `fdfind`, and `eza` provides `ls` —
worth knowing, because `ls -1t DIR` under eza silently lists the current
directory instead of `DIR`, which breaks naive scripts.

### 4. Qt 6.8.3 and the Quickshell build

The panel layer is built from source, and the launcher wrapper restored in the
next step hardcodes both paths, so use exactly these:

1. Install Qt **6.8.3** `gcc_64` with the Qt online installer, to `~/Qt`.
2. Clone Quickshell to `~/dev/forks/quickshell` and build it, leaving the
   binary at `build/src/quickshell` and the QML modules at `build/qml_modules`.

`~/.local/bin/quickshell` (step 5) is a wrapper that puts Qt on `PATH`,
`LD_LIBRARY_PATH` and `QML2_IMPORT_PATH` and then execs that binary. To build
somewhere else, edit `qt_root` and `quickshell_root` in it.

### 5. Clone this repo and restore the configs

```bash
git clone git@github.com:ka1rav6/config_files.git ~/dotfiles
cd ~/dotfiles
python3 bootstrap.py --dry-run    # print every source -> destination
python3 bootstrap.py              # copy them into place
```

`bootstrap.py` reads the same path list the backup writes (see *What is
tracked* below) and copies each entry to where it came from. Directories are
**merged, not mirrored**, so anything already on the new machine that was never
backed up is left alone.

It is deliberately dumb: no diff, no undo. That is the fresh-machine tool. On a
machine that already has `~/.local/share/config-backup/`, use `just
restore-check` / `just restore` instead — those diff first and archive whatever
they overwrite (see *Known gaps*).

### 6. Compile the C daemons

Waybar's workspace clicks, the todo and KDE Connect feeds, and the tablet-mode
handler are small event-driven C programs, not scripts:

```bash
cd ~/.config/hypr/daemons
make && make install          # builds into build/, installs to ~/.local/bin
```

The tablet-mode daemon needs root (it drives an i2c bind/unbind) and is
installed separately — only on hardware that has the switch:

```bash
sudo ~/.config/hypr/scripts/install-touchscreen.sh
```

### 7. systemd user units

```bash
systemctl --user daemon-reload
systemctl --user enable --now hypr-log-persist.service
```

The restored `~/.config/systemd/user/` also carries `*.target.wants` symlinks
for the snap units; harmless if those snaps are absent.

### 8. zsh

```bash
chsh -s "$(which zsh)"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions \
  "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
  "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install
```

Run the oh-my-zsh installer **after** restoring, or let it move `.zshrc` aside
and put the restored one back. The restored `.zshrc` expects `$HOME/.oh-my-zsh`
and sources `~/.fzf.zsh`; without them it still loads, but loses completion,
the prompt and the fzf widgets. Note also that `cd` is wrapped by zoxide here,
so `cd <glob>` fails — which silently skips the rest of an `&&` chain.

### 9. Neovim

Nothing to do: `init.lua` bootstraps lazy.nvim and LazyVim on first launch. To
get the exact plugin versions from this snapshot rather than latest:

```bash
nvim --headless "+Lazy! restore" +qa
```

### 10. First login

Log out and pick **Hyprland** at the session picker. `hyprland.lua` is loaded
*instead of* `hyprland.conf` when it exists, and that choice is made once at
compositor startup — so switching between them needs a full re-login, not
`hyprctl reload`.

Two things to know before you start editing the compositor config:

- Under the Lua config, `hyprctl keyword …` is a **silent no-op** and
  `hyprctl dispatch` evaluates Lua rather than the old string form. Change the
  `.lua` file and `hyprctl reload`.
- `misc:allow_session_lock_restore` is set in `autostart.lua` on purpose. If
  the lock screen ever crashes, the session stays locked (correct) and without
  that setting the only way back in is a TTY.

### 11. After the first login

```bash
just theme                   # list the themes
just theme auto              # derive a palette from the wallpaper and apply it everywhere
just qs-status               # is the Quickshell layer alive?
just qs-debug                # run it in the foreground if it is not
```

Without matugen (step 3) `auto` silently falls back to an older hand-rolled
derivation — it works, and it is strictly worse.

`qs-debug` matters: a QML parse error makes Quickshell exit immediately and
silently when daemonized, so a broken panel looks identical to a missing one.

Two more things that are easy to misdiagnose:

- Bluetooth headphones connect without producing an audio sink until something
  selects the card's A2DP profile. `bt-connect` (restored into `~/.local/bin`)
  does that; the GUI does not.
- Screenshot tools cannot capture Quickshell surfaces — `grim` returns an empty
  image. An empty screenshot is not evidence that the panel is broken.

---

## What is tracked

The destination of each path is not stored as a plain list in this repo. It
lives in two places, both of which `bootstrap.py` reads so there is only one
source of truth:

- `DEFAULT_BACKUP_PATHS` inside `custom-binaries/bin/config-backup` — the
  backup tool, which the backup captures along with everything else in
  `~/.local/bin`.
- `backup_paths.json` — everything added later with `just add`.

The repo layout is `<category>/<basename of the original path>`, which is why
`editors/User` is VS Code and `config/config.jsonc` is a stray fastfetch file.

| In this repo | Goes to | What it is |
| --- | --- | --- |
| `clang/clang` | `~/.config/clang` | clang |
| `config/config.jsonc` | `~/.config/fastfetch/config.jsonc` | config.jsonc |
| `cppman/cppman` | `~/.config/cppman` | cppman |
| `custom-binaries/bin` | `~/.local/bin` | .local/bin scripts |
| `custom-binaries/mako-fzf-history` | `~/.local/bin/mako-fzf-history` | mako-fzf-history |
| `custom-binaries/now-playing-notify` | `~/.local/bin/now-playing-notify` | now-playing-notify |
| `custom-binaries/system-monitor-notify` | `~/.local/bin/system-monitor-notify` | system-monitor-notify |
| `custom/.selected_editor` | `~/.selected_editor` | .selected_editor |
| `custom/.zshenv` | `~/.zshenv` | .zshenv |
| `custom/applications` | `~/.local/share/applications` | applications |
| `custom/hyprtodo` | `~/.config/hyprtodo` | hyprtodo |
| `custom/Justfile` | `~/Justfile` | Justfile |
| `custom/keys.md` | `~/docs/notes/keys.md` | keys.md |
| `custom/nvim-ghostty.desktop` | `~/.local/share/applications/nvim-ghostty.desktop` | nvim-ghostty.desktop |
| `custom/wallpapers` | `~/media/pictures/wallpapers` | wallpapers |
| `custom/yazi_keys.md` | `~/docs/research/yazi_keys.md` | yazi_keys.md |
| `editors/nvim` | `~/.config/nvim` | Neovim configuration |
| `editors/User` | `~/.config/Code/User` | VS Code user settings |
| `fastfetch/fastfetch` | `~/.config/fastfetch` | fastfetch |
| `gsimplecal/gsimplecal` | `~/.config/gsimplecal` | gsimplecal |
| `gtk-3/gtk-3.0` | `~/.config/gtk-3.0` | gtk-3.0 |
| `gtk-4/gtk-4.0` | `~/.config/gtk-4.0` | gtk-4.0 |
| `htop/htop` | `~/.config/htop` | htop |
| `kdeconnect/kdeconnect` | `~/.config/kdeconnect` | kdeconnect |
| `matugen/matugen` | `~/.config/matugen` | matugen |
| `mimeapps/mimeapps.list` | `~/.config/mimeapps.list` | mimeapps.list |
| `opencode/opencode.json` | `~/.config/opencode/opencode.json` | opencode.json |
| `pipewire/pipewire` | `~/.config/pipewire` | pipewire |
| `quickshell/quickshell` | `~/.config/quickshell` | quickshell |
| `shell/.bashrc` | `~/.bashrc` | Bash shell configuration |
| `shell/.gitconfig` | `~/.gitconfig` | Git configuration |
| `shell/.profile` | `~/.profile` | Profile configuration |
| `shell/.tmux.conf` | `~/.tmux.conf` | TMUX configuration |
| `shell/.vimrc` | `~/.vimrc` | Vim configuration |
| `shell/.zshrc` | `~/.zshrc` | Zsh shell configuration |
| `sioyek/sioyek` | `~/.config/sioyek` | sioyek |
| `status-bars/waybar` | `~/.config/waybar` | Waybar status bar config |
| `status-bars/wofi` | `~/.config/wofi` | Wofi launcher config |
| `systemd/systemd` | `~/.config/systemd` | systemd |
| `terminals/ghostty` | `~/.config/ghostty` | Ghostty terminal emulator config |
| `terminals/kitty` | `~/.config/kitty` | Kitty terminal config |
| `tools/autostart` | `~/.config/autostart` | Application autostart config |
| `tools/btop` | `~/.config/btop` | Btop system monitor config |
| `tools/lazygit` | `~/.config/lazygit` | Lazygit configuration |
| `tools/mako` | `~/.config/mako` | Mako notification daemon config |
| `tools/neovide` | `~/.config/neovide` | Neovide config |
| `window-manager/hypr` | `~/.config/hypr` | Hyprland window manager config |
| `wlogout/wlogout` | `~/.config/wlogout` | wlogout |
| `xdg-desktop-portal/xdg-desktop-portal` | `~/.config/xdg-desktop-portal` | xdg-desktop-portal |
| `yazi/yazi` | `~/.config/yazi` | yazi |
| `zathura/zathura` | `~/.config/zathura` | zathura |

Not every directory here is live: `nwg-dock-hyprland/` and `nwg-drawer/` are
left over from an earlier dock and nothing in the path list points at them any
more.

### Excluded on purpose

`.gitignore` and the backup tool both drop machine-local state. The backup
skips, at any depth: `Cache`, `CachedData`, `Code Cache`, `GPUCache`,
`DawnCache`, `workspaceStorage`, `globalStorage`, `History`, `sync`, `logs`,
`node_modules`, `__pycache__`, `.venv`, `venv`, `build`, `dist`, `target`,
`zig-cache`, `zig-out`, `.cache` — plus **any file over 2 MB**, which is what
keeps every compiled binary in `~/.local/bin` out of here.

### Retired, but still installed

Each of these was replaced by something in the Quickshell layer or by a
keybind, and the binary was left on the machine. None is started at login and
none is referenced by any tracked config — so a `grep` for any of them turns up
nothing and looks like a missing dependency. This is the list that says
otherwise.

| Still installed | Where | Replaced by | Keep? |
| --- | --- | --- | --- |
| `nwg-drawer` | `/usr/bin` | wofi on `SUPER + S` | no — also `nwg-drawer/` here |
| `nwg-dock-hyprland` | `~/.local/bin` | the Quickshell dock | no — also `nwg-dock-hyprland/` here |
| `waycal` | `~/.cargo/bin` | the shell's clock popout | no |
| `kdeconnect-indicator` | `/usr/bin` | `custom/kdeconnect` in waybar → the Command Center | only if the waybar tray ever comes back |
| `nm-applet` | `/usr/bin` | Control Center → Wi-Fi | no |
| `blueman-applet` | `/usr/bin` | Control Center → Bluetooth | **yes** — `bt-pair` starts it on demand for its pairing agent |
| `wlsunset` | `/usr/bin` | nothing | **no, and it cannot work here**: `AQ_NO_ATOMIC=1` leaves aquamarine on the legacy DRM interface, which has no gamma. See `window-manager/hypr/autostart.lua`. |
| `delta` | `/usr/bin` | git's own pager | no — the config was removed on purpose |

The two `nwg-*` directories in this repo are the configs for tools in that
list, and go when they do.

---

---

## Day to day

From `~/Justfile` (itself tracked, as `custom/Justfile`):

```bash
just backup                  # snapshot every tracked path into ~/dotfiles and commit
just add <path>              # start tracking a new path
just restore-check           # what a restore would change — touches nothing
just restore                 # copy it all back, after confirming
just restore 1 3             # or 1-3, or `just restore hypr nvim` — only those entries
just restore-pushed          # hard-reset ~/dotfiles to origin/main first, then restore
```

`just restore` archives everything it is about to overwrite to
`~/.local/share/config-restore/pre-restore_<stamp>.tar.gz`, so restoring from
the wrong commit is itself undoable (`tar -xzf <archive> -C ~`).

After restoring `~/.config/hypr` or `~/.config/quickshell`, reload them —
neither rereads its config on its own:

```bash
hyprctl reload && just qs-reload
```

---

## Known gaps

**1. The restore tool is not in this repo.** `just restore` runs
`~/.local/share/config-backup/config_restore.py`, and nothing backs that
directory up. Only `config_backup.py` survives, as
`custom-binaries/bin/config-backup`, and only because `~/.local/bin/config-backup`
symlinks to it. `config_restore.py` imports `config_backup` as a module, so
restoring it needs both files side by side under their original `.py` names.
That is why `bootstrap.py` exists. To close the gap properly, add
`~/.local/share/config-backup` to the tracked paths (`just add`).

**2. `packages_installed.txt` is hand-maintained.** The backup does not
regenerate it, so it drifts. Refresh it by hand with
`apt-mark showmanual | sort > packages_installed.txt`, which also pulls in some
base-system noise the curated list does not have.

**3. There are secrets in here.** `shell/.gitconfig` carries an email and name,
and `kdeconnect/kdeconnect/` contains `privateKey.pem`, `certificate.pem` and
`trusted_devices` — the material that makes a phone trusted. Keep this
repository private, and on a new machine prefer pairing devices again over
trusting the restored keys.

**4. Restored directories are merged, never mirrored.** Files that exist
locally but were never backed up survive a restore. `just restore --clean`
mirrors exactly, which would delete every >2 MB binary the backup skipped —
run `just restore-check --clean` before ever using it.

**5. `hyprpm` plugins do not work on this machine** (root-owned cache, stale
ABI). That is why the window controls are a layer surface rather than a plugin.
