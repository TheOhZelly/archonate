---
name: archonate-diagnose-crash
description: Find out why a program crashed on an Archonate desktop (Hyprland on Arch/CachyOS) from its systemd-coredump record, and explain it to the user. Use when asked why something crashed, segfaulted or "just closed", or when started from Archonate's "Ask AI why" crash notification.
---

# Diagnosing a crash

Work from evidence, explain plainly, change nothing until the user agrees.

## Gather

1. The record: `coredumpctl info <pid> --no-pager` (signal, executable, command
   line, time, the stack trace if a core was kept). `coredumpctl list --no-pager`
   shows recent crashes if you have no PID.
2. The journal around it: `journalctl --since "<time - 1 min>" --until "<time + 10 s>" --no-pager`.
   Look for the last thing the program logged, GPU or kernel messages, OOM kills,
   and whether other programs died at the same moment (a crashed compositor takes
   its clients with it: those are victims, not causes).
3. Kernel lines: `journalctl -k --since ... --until ...` often name the library
   (`segfault at 68 ... in libaquamarine.so`).
4. Versions: `pacman -Qo <executable>` then `pacman -Qi <package>` for the version;
   `pacman -Q hyprland aquamarine mesa nvidia-utils` for the graphics stack;
   `grep -E "upgraded|installed" /var/log/pacman.log | tail -30` for recent
   updates (a crash that started right after an update is a strong clue).
5. If there is a core and gdb is installed: `coredumpctl debug <pid>` then `bt`.
   Without debug symbols, the library names in the frames still say a lot. Don't
   install anything to get symbols without asking.
6. Archonate's side: `archonate status --json` and `archonate doctor`.

## Decide whose it is

- **The program or a library** (most crashes): a segfault or abort inside its own
  code or a library it ships or links. Name the library from the frames or the
  kernel line.
- **The graphics stack**: frames in mesa, nvidia, aquamarine, wlroots, or kernel
  GPU messages at the same time.
- **Archonate**: only if it is one of Archonate's processes (`qs`, quickshell,
  hyprsunset started by Archonate) or the crash follows an Archonate action
  (rice/style switch, `hyprctl reload`). Config files cannot segfault a compiled
  program by themselves; say so rather than blaming them.
- **The setup**: out of memory, a full disk, a broken partial update.

Say how sure you are. One crash with no core is often not enough to be certain.

## Tell the user

- What crashed and when, in one line.
- The likely cause in plain words, and whose bug it is.
- What to do: a workaround, an update to wait for or install (`archonate update`),
  a setting to change, or where to report it upstream with what to attach
  (`coredumpctl info <pid>`, versions). Write the report text for them if useful.
- Whether it is likely to happen again, and what would confirm the theory next time.

## Don't

- No `sudo`, no restarting services, no editing configs, no reinstalling packages
  unless the user says yes to that exact step.
- Don't paste whole cores or huge logs back; quote the lines that matter.
