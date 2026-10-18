#!/usr/bin/env python3
"""Launch a prebuilt native game or diagnostic using a supplied boot disk.

This creates private media only; the caller supplies their own GS/OS template.
--play boots normally without a debugger; the default diagnostic starts paused.
Use the reported debugger socket to stop/quit the owned emulator before reading
its private disk with Cadius. No shared disks/configuration are modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]


def run(command):
    process = subprocess.run([str(value) for value in command], cwd=ROOT,
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             timeout=120)
    if process.returncode:
        raise RuntimeError(process.stdout)
    return process.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rom', choices=['1', '3'], default='1', help='IIgs firmware profile; real game target defaults to ROM3')
    parser.add_argument('--play', action='store_true', help='Boot unpaused in a clean window without a debugger')
    parser.add_argument('--binary', type=Path, required=True, help='prebuilt native S16 executable')
    parser.add_argument('--manifest', type=Path, help='matching prebuilt manifest; defaults beside binary')
    parser.add_argument('--source', type=Path, required=True, help='matching native assembly source')
    parser.add_argument('--speed', choices=['2.8mhz', '7.159mhz', '14.3mhz', 'ludicrous'], default='2.8mhz')
    parser.add_argument('--template', required=True, type=Path)
    parser.add_argument('--volume', required=True, help='ProDOS template volume name')
    parser.add_argument('--emulator', type=Path,
                        default=Path('/Applications/GSSquared.app/Contents/MacOS/GSSquared'))
    args = parser.parse_args()
    if not args.template.is_file() or not args.emulator.is_file():
        parser.error('template and emulator must exist')
    if not args.volume.isalnum():
        parser.error('volume must contain only letters and digits')
    if not args.binary.is_file(): parser.error('binary does not exist')
    if not args.source.is_file(): parser.error('source does not exist')
    prebuilt_map = args.binary.parent / 'link.map'
    if not prebuilt_map.is_file(): prebuilt_map = args.binary.parent / 'native-link.log'
    folder = Path(tempfile.mkdtemp(prefix='railgunner-iigs-', dir='/tmp'))
    disk = folder / 'native.2mg'
    shutil.copy2(args.template, disk)
    shutil.copy2(args.binary, folder / 'Start')
    if prebuilt_map.is_file(): shutil.copy2(prebuilt_map, folder / 'native-link.log')
    (folder / 'native-build.log').write_text('Prebuilt: ' + str(args.binary) + '\n')
    manifest = args.manifest or args.binary.parent / 'manifest.json'
    if not manifest.is_file(): parser.error('matching manifest does not exist')
    manifest_text = manifest.read_text()
    build_metadata = json.loads(manifest_text)
    expected_binary = build_metadata.get('binary_sha256')
    if not expected_binary or hashlib.sha256((folder / 'Start').read_bytes()).hexdigest() != expected_binary:
        parser.error('binary does not match the supplied manifest')
    compiled_speed = build_metadata.get('build_speed') or build_metadata.get('speed')
    if compiled_speed and compiled_speed != args.speed:
        parser.error('launch speed must match the recorded build/test profile')
    (folder / 'build-manifest.json').write_text(manifest_text)
    fixture = args.source
    fixture_copy = folder / ('fixture' + fixture.suffix)
    shutil.copy2(fixture, fixture_copy)
    (folder / '_FileInformation.txt').write_text(
        'Start=Type(B3),AuxType(DB03),VersionCreate(00),MinVersion(80),Access(E3)\n')
    run(['cadius', 'DELETEFILE', disk, '/' + args.volume + '/System/Start'])
    run(['cadius', 'ADDFILE', disk, '/' + args.volume + '/System', folder / 'Start'])
    socket = folder / 'debug.sock'
    config = folder / 'native.gs2'
    game_build=args.binary and 'game_provenance' in build_metadata
    window_kind='native game' if game_build else 'native renderer'
    config.write_text('gs2_version = 1\nid = "' + str(uuid.uuid4()) + '"\n'
                      'name = "Railgunner ' + (window_kind if args.play else 'diagnostic') + '"\nplatform = "' + ('apple2gs_rom3' if args.rom == '3' else 'apple2gs') + '"\n'
                      'clock = "ntsc"\nspeed = "' + args.speed + '"\nscanner = "apple2gs"\nbuiltin = false\n'
                      '[[cards]]\nslot = 7\ncard = "bazfast3"\n'
                      '[[storage]]\nslot = 7\ndrive = 1\nimage = "native.2mg"\n')
    command = [str(args.emulator), str(config), '--no-quit-confirm']
    if not args.play: command += ['--debug', str(socket), '-s']
    with (folder / 'emulator.log').open('w') as log:
        process = subprocess.Popen(command, cwd=folder, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
    session = dict(rom=args.rom, pid=process.pid, disk=str(disk), socket=None if args.play else str(socket),
                   launch_mode='play' if args.play else 'diagnostic',
                   folder=str(folder), config=str(config), command=command,
                   template=str(args.template.resolve()), volume=args.volume, fixture=fixture.stem,
                   speed=args.speed, binary_sha256=hashlib.sha256((folder / 'Start').read_bytes()).hexdigest(),
                   fixture_sha256=hashlib.sha256(fixture_copy.read_bytes()).hexdigest(),
                   template_sha256=hashlib.sha256(args.template.read_bytes()).hexdigest(),
                   emulator_sha256=hashlib.sha256(args.emulator.read_bytes()).hexdigest())
    (folder / 'session.json').write_text(json.dumps(session, indent=2) + '\n')
    print(json.dumps(session, indent=2))


if __name__ == '__main__':
    main()
