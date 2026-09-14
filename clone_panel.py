#!/usr/bin/env python3
"""
clone_panel.py — Clone Cinnamon panel applet layouts between panels.

Reads the live dconf state under /org/cinnamon/, then writes back an
updated enabled-applets list (and next-applet-id) according to the
chosen mode. Also copies any per-instance JSON settings files under
~/.cinnamon/configs/<applet-uuid>/<instance-id>.json so cloned applets
keep their own settings instead of fighting over one file.

MODES
  mirror  Replace the target panel's applets entirely with a clone of
          the source panel's applets (existing target applets removed).
  merge   Keep the target panel's existing applets; add any source-panel
          applets whose uuid isn't already present on the target panel.
  select  Only clone the specific applet uuid(s) you list, appended to
          whatever is already on the target panel.

USAGE
  # Preview only, no changes written:
  ./clone_panel.py --mode mirror --source 1 --target 3 --dry-run

  # Actually apply:
  ./clone_panel.py --mode mirror --source 1 --target 3

  # Merge panel1's extras into panel2, keeping panel2's own applets:
  ./clone_panel.py --mode merge --source 1 --target 2

  # Clone just two specific applets from panel1 onto panel2:
  ./clone_panel.py --mode select --source 1 --target 2 \\
      --applets sound@cinnamon.org,printers@cinnamon.org

After running for real, log out/in or run:
  cinnamon --replace &disown
to reload the panels.
"""

import argparse
import ast
import shutil
import subprocess
import sys
from pathlib import Path


def dconf_read(key):
    result = subprocess.run(
        ["dconf", "read", key], capture_output=True, text=True, check=True
    )
    out = result.stdout.strip()
    if not out:
        return None
    return ast.literal_eval(out)


def dconf_write(key, value_repr):
    subprocess.run(["dconf", "write", key, value_repr], check=True)


def parse_applets(raw_list):
    """Turn ['panel1:left:1:uuid:instance', ...] into dicts."""
    entries = []
    for item in raw_list:
        parts = item.split(":")
        # uuid can itself contain ':'? In practice Cinnamon uuids don't,
        # so a straight split is safe; instance id is always the last field,
        # panel/zone/order are always the first three.
        panel, zone, order, uuid, instance = (
            parts[0], parts[1], parts[2], ":".join(parts[3:-1]), parts[-1]
        )
        entries.append({
            "panel": panel,       # e.g. 'panel1'
            "zone": zone,         # left/center/right
            "order": order,
            "uuid": uuid,
            "instance": instance,
            "raw": item,
        })
    return entries


def format_entry(e):
    return f"{e['panel']}:{e['zone']}:{e['order']}:{e['uuid']}:{e['instance']}"


def copy_applet_config(uuid, old_instance, new_instance, dry_run):
    cfg_dir = Path.home() / ".cinnamon" / "configs" / uuid
    old_file = cfg_dir / f"{old_instance}.json"
    new_file = cfg_dir / f"{new_instance}.json"
    if old_file.exists():
        print(f"  config: {old_file.name} -> {new_file.name}")
        if not dry_run:
            shutil.copy2(old_file, new_file)
        return True
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--mode", choices=["mirror", "merge", "select"], required=True)
    ap.add_argument("--source", required=True, help="source panel number, e.g. 1")
    ap.add_argument("--target", required=True, help="target panel number, e.g. 3")
    ap.add_argument("--applets", default="",
                     help="comma-separated uuid list, required for --mode select")
    ap.add_argument("--dry-run", action="store_true",
                     help="show what would happen without writing anything")
    args = ap.parse_args()

    source_panel = f"panel{args.source}"
    target_panel = f"panel{args.target}"

    raw_applets = dconf_read("/org/cinnamon/enabled-applets") or []
    next_id = dconf_read("/org/cinnamon/next-applet-id")
    if next_id is None:
        next_id = 1

    entries = parse_applets(raw_applets)

    source_entries = [e for e in entries if e["panel"] == source_panel]
    if not source_entries:
        print(f"No applets found on {source_panel}. Nothing to clone.")
        sys.exit(1)

    if args.mode == "select":
        wanted = {u.strip() for u in args.applets.split(",") if u.strip()}
        if not wanted:
            print("Error: --mode select requires --applets uuid1,uuid2,...")
            sys.exit(1)
        source_entries = [e for e in source_entries if e["uuid"] in wanted]
        missing = wanted - {e["uuid"] for e in source_entries}
        if missing:
            print(f"Warning: these uuids weren't found on {source_panel}: {missing}")

    target_entries = [e for e in entries if e["panel"] == target_panel]
    other_entries = [e for e in entries if e["panel"] not in (source_panel, target_panel)]

    if args.mode == "mirror":
        kept_target = []  # wipe target entirely
    elif args.mode == "merge":
        existing_uuids = {e["uuid"] for e in target_entries}
        source_entries = [e for e in source_entries if e["uuid"] not in existing_uuids]
        kept_target = target_entries
    else:  # select
        kept_target = target_entries

    print(f"Mode: {args.mode}   Source: {source_panel}   Target: {target_panel}")
    if args.dry_run:
        print("(dry run — no changes will be written)\n")

    cloned = []
    for e in source_entries:
        new_instance = str(next_id)
        next_id += 1
        new_entry = dict(e)
        new_entry["panel"] = target_panel
        new_entry["instance"] = new_instance
        cloned.append(new_entry)

        print(f"Clone {e['uuid']} (id {e['instance']} -> {new_instance}) "
              f"onto {target_panel}:{e['zone']}:{e['order']}")
        copy_applet_config(e["uuid"], e["instance"], new_instance, args.dry_run)

    final_entries = other_entries + \
        [e for e in entries if e["panel"] == source_panel] + \
        kept_target + cloned

    # Preserve a stable, readable order: original relative order first,
    # then newly appended clones at the end.
    seen = set()
    ordered = []
    for e in entries:
        key = e["raw"]
        if e["panel"] == target_panel and e not in kept_target and args.mode == "mirror":
            continue  # dropped by mirror
        if key not in seen:
            ordered.append(e)
            seen.add(key)
    for e in cloned:
        ordered.append(e)

    final_list = [format_entry(e) for e in ordered]

    print("\nFinal enabled-applets:")
    for item in final_list:
        print(f"  {item}")
    print(f"\nnext-applet-id will become: {next_id}")

    if args.dry_run:
        print("\nDry run complete — nothing written.")
        return

    gvariant_list = "[" + ", ".join(f"'{s}'" for s in final_list) + "]"
    dconf_write("/org/cinnamon/enabled-applets", gvariant_list)
    dconf_write("/org/cinnamon/next-applet-id", str(next_id))

    print("\nDone. Restart Cinnamon to see the change:")
    print("  cinnamon --replace &disown")


if __name__ == "__main__":
    main()
