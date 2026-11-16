#!/usr/bin/env python3
"""Copy this standalone distribution into ~/Rice/kanso without touching other rice.

Source files stay in the extracted archive. Existing Kanso gets an immutable backup
outside ~/Rice; the user chooses if/when to remove it.
"""
from __future__ import annotations
import argparse
import os
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOME = Path.home()
DEST = HOME / 'Rice' / 'kanso'
BACKUP_ROOT = HOME / 'Rice-backups'
MANIFEST = Path(os.environ.get('XDG_STATE_HOME', str(HOME / '.local/state'))) / 'kanso-standalone/restore.json'


def install(destination: Path, confirm_upgrade: bool) -> int:
    destination = destination.expanduser().absolute()
    if HERE == destination or HERE in destination.parents:
        print('Source directory is already under the chosen destination; nothing copied')
        return 0 if HERE == destination else 2
    if (HERE/'NATIVE-PREVIEW-NOTICE.md').exists():
        print('Private preview: installation is intentionally disabled.', file=sys.stderr)
        return 2
    if not (HERE/'shell.qml').is_file() or not (HERE/'native/CMakeLists.txt').is_file():
        print('Incomplete Kanso source', file=sys.stderr)
        return 2
    if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
        print('Refusing to overwrite a symlink or non-directory:', destination, file=sys.stderr)
        return 2
    if destination.exists() and not confirm_upgrade:
        print('Destination already exists:', destination, file=sys.stderr)
        print('Use --upgrade to back it up first; does not overwrite in place.', file=sys.stderr)
        return 2
    if destination.exists() and MANIFEST.is_file():
        print('Kanso is active; controller manifest exists:', MANIFEST, file=sys.stderr)
        print('Back up the manifest and use the current controller restore before a structural upgrade.', file=sys.stderr)
        return 2
    destination.parent.mkdir(parents=True, exist_ok=True)
    archived = None
    if destination.exists():
        BACKUP_ROOT.mkdir(parents=True, exist_ok=True)
        stamp = time.strftime('%Y%m%d-%H%M%S')
        archived = BACKUP_ROOT / f'kanso-before-update-{stamp}'
        if archived.exists():
            print('Backup already exists:', archived, file=sys.stderr)
            return 2
        shutil.move(str(destination), str(archived))
    try:
        shutil.copytree(HERE, destination, ignore=shutil.ignore_patterns('__pycache__','*.pyc','.git','.build'))
    except (OSError, shutil.Error) as error:
        print('Installation failed:', error, file=sys.stderr)
        if archived and not destination.exists():
            shutil.move(str(archived), str(destination))
        return 1
    print('Kanso installed:', destination)
    if archived: print('Previous version backed up:', archived)
    print('Next: build kanso-native with CMake, then run:')
    print(' ', destination/'native/bin/kanso-native', 'doctor preflight')
    print('See the project README for dependencies and wallpaper setup.')
    return 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', type=Path, default=DEST)
    parser.add_argument('--upgrade', action='store_true', help='Archive an existing inactive Kanso')
    args = parser.parse_args()
    sys.exit(install(args.destination, args.upgrade))
