#!/usr/bin/env python3
"""Verify startup/exit on a fresh private native session, before its first entry.

Requires the expected relocated base from a matching prior private launch. The
entry breakpoint validates the signature before any injected state change.
--scenario alloc-failure injects carry at the native allocation-result branch;
it exercises that error path, not actual Memory Manager resource exhaustion.
The owned private emulator is quit after the check, including on failure.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def regs(raw):
    values = dict(zip(('pc', 'a', 'x', 'y', 'sp', 'd'), struct.unpack_from('<6H', raw, 16)))
    values.update(p=raw[13], db=raw[14], pb=raw[15])
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session', type=Path, required=True)
    parser.add_argument('--base', type=lambda s: int(s, 0), required=True)
    parser.add_argument('--scenario', choices=['quit', 'alloc-failure'], required=True)
    parser.add_argument('--game',action='store_true',help='Native game: use held Ctrl-Q and verify drained Tool9 ownership')
    parser.add_argument('--post-quit-check', action='store_true', help='Also check that QuitGS leaves the native image without entering the ROM BRK monitor')
    parser.add_argument('--initial-shr', action='store_true', help='Diagnostic: enable caller SHR mode before native entry')
    parser.add_argument('--pattern-display', action='store_true', help='Diagnostic: initialize caller pixel bytes before native entry')
    parser.add_argument('--poison-failed-handle', action='store_true', help='Inject an undefined nonzero handle result on the error branch')
    parser.add_argument('--dispose-with-private-dp', action='store_true', help='Diagnostic override of D at DisposeHandle call')
    parser.add_argument('--already-running', action='store_true', help='Normal quit using saved entry fields of the matching running binary')
    parser.add_argument('--gssquared-source', type=Path,
                        default=ROOT.parent.parent / 'external/gssquared')
    args = parser.parse_args()
    session = json.loads(args.session.read_text())
    folder = args.session.parent
    manifest = json.loads((folder / 'build-manifest.json').read_text())
    symbols = manifest['symbols']
    if hashlib.sha256((folder / 'Start').read_bytes()).hexdigest() != session['binary_sha256']:
        raise RuntimeError('Private binary does not match session metadata')
    sys.path.insert(0, str(args.gssquared_source / 'clients/python/src'))
    from gs2debug import Client, BP_KIND_EXEC, BP_FLAG_ENABLED, BP_FLAG_TEMPORARY, REG_PC, REG_PB, REG_P, REG_D
    result = dict(scope='native GS/OS CPU and display restoration', scenario=args.scenario,
                  session=session, base=args.base,
                  helper_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    client = Client()
    try:
        client.connect(session['socket'])
        client.hello()
        client.pause()
        client.wait_stopped(timeout=5)

        def read(address, count):
            return b''.join(client.read_mem(0, address + offset, min(4096, count - offset))
                            for offset in range(0, count, 4096))

        def address(name):
            return args.base + symbols[name]

        def arm(name):
            return client.bp_set(kind=BP_KIND_EXEC, address=address(name),
                                 flags=BP_FLAG_ENABLED | BP_FLAG_TEMPORARY)

        def reach(bp, timeout=120):
            client.continue_()
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                try:
                    event = client.wait_stopped(timeout=min(5, deadline - time.monotonic()))
                except (TimeoutError, OSError):
                    continue
                if event.bp_id != bp:
                    raise RuntimeError('Unexpected emulator stop: %r' % event)
                return regs(client.get_regs())
            raise TimeoutError('Expected native breakpoint was not reached')

        hardware = {'old_shr': 0xe0c029, 'old_border': 0xe0c034,
                    'old_shadow': 0xe0c035, 'old_speed': 0xe0c036}
        if args.already_running:
            if args.scenario != 'quit':
                raise RuntimeError('Failure injection requires a fresh startup')
            if read(address('debug_signature'), 8) != b'RGNATIVE':
                raise RuntimeError('Relocated base/signature does not match')
            def word(name):
                return int.from_bytes(read(address(name), 2), 'little')
            entry = dict(sp=word('debug_entry_sp'), p=word('debug_entry_p') & 255,
                         db=word('debug_entry_dbr') & 255, d=word('old_dp'))
            instruction = read(address('restore_display'), 4)
            if instruction[0] != 0xbf:  # LDA long,X saved-display buffer
                raise RuntimeError('Unexpected restoration load instruction')
            saved = int.from_bytes(instruction[1:], 'little')
            original_display = read(saved, 32768)
            original_dp = read(address('saved_caller_dp'), 4)
            original_hardware = {name: read(address(name), 1) for name in hardware}
            result['entry_origin'] = 'Matching native prologue saved fields'
        else:
            entry = reach(arm('native_entry'))
            if read(address('debug_signature'), 8) != b'RGNATIVE':
                raise RuntimeError('Relocated base/signature does not match')
            if args.initial_shr:
                mode = read(0xe0c029, 1)[0] | 0x80
                client.write_mem(0, 0xe0c029, bytes([mode]))
                result['injected_initial_c029'] = mode
            if args.pattern_display:
                pattern = bytes(((i * 37 + (i >> 8) * 11) & 255) for i in range(32000))
                for offset in range(0, len(pattern), 4096):
                    client.write_mem(0, 0xe12000 + offset, pattern[offset:offset+4096])
                result['injected_pixel_pattern'] = 'i*37+(i>>8)*11 modulo256'
            original_display = read(0xe12000, 32768)
            original_tool_page = read(0xe10000, 2048)
            result['entry_tool_page'] = original_tool_page.hex()
            original_dp = read(entry['d'], 4)
            original_hardware = {name: read(location, 1) for name, location in hardware.items()}
            result['entry_origin'] = 'CPU snapshot at actual native entry'
        result['entry'] = entry
        if args.scenario == 'alloc-failure':
            at = reach(arm('native_alloc_result'))
            # Explicitly inject the allocation-error branch after returned
            # handle words have been popped. QuitGS releases process resources, including the real handle.
            client.set_regs(REG_P, p=at['p'] | 1)
            if args.poison_failed_handle:
                client.write_mem(0, address('dp_handle'), bytes.fromhex('ffffffff'))
                result['injected_handle_result'] = 'ffffffff'
        else:
            if not args.already_running:
                reach(arm('native_alloc_result'))
                handle = int.from_bytes(read(address('dp_handle'), 4), 'little')
                result['allocated_handle'] = handle
                result['allocated_handle_bytes'] = read(handle, 32).hex()
            reach(arm('main_loop'))
            load = read(address('restore_display'), 4)
            if load[0] != 0xbf:
                raise RuntimeError('Unexpected saved-display restoration instruction')
            saved_address = int.from_bytes(load[1:], 'little')
            saved_snapshot = read(saved_address, 32768)
            result['saved_display_address'] = saved_address
            result['saved_vs_entry_differences'] = [i for i, (a, b) in enumerate(zip(saved_snapshot, original_display)) if a != b]
            if args.game:
                client.key_down(224,64)  # SDL left Control, KMOD_LCTRL
                client.key_down(20,64)   # Q, held until shutdown recognizes it
            else:
                client.key_down(41)  # documented SDL Escape scancode
                client.key_up(41)
            at_shutdown = reach(arm('shutdown'), timeout=20)
            result['at_shutdown'] = at_shutdown
            if args.game:
                client.key_up(20,64)
                client.key_up(224,0)
            result['shutdown_tool_page'] = read(0xe10000, 2048).hex()
            if 'allocated_handle' in result:
                result['shutdown_handle_bytes'] = read(result['allocated_handle'], 32).hex()
            region = read(address('shutdown'), 180)
            offset = region.find(bytes.fromhex('a20203220000e1'))
            if offset >= 0:
                call_address = address('shutdown') + offset + 3
                bp = client.bp_set(kind=BP_KIND_EXEC, address=call_address,
                                   flags=BP_FLAG_ENABLED | BP_FLAG_TEMPORARY)
                at_tool = reach(bp, timeout=20)
                result['before_mm_shutdown'] = at_tool
                result['mm_shutdown_argument'] = read(at_tool['sp'] + 1, 2).hex()
                result['before_mm_globals'] = {name: read(address(name), 4).hex()
                                              for name in ('user_id', 'dp_handle', 'memory_active', 'tool_active') if name in symbols}
                result['before_mm_caller_dp'] = read(entry['d'], 4).hex()
                result['original_caller_dp'] = original_dp.hex()
        if args.dispose_with_private_dp:
            at_dispose = reach(arm('native_dispose_call'), timeout=20)
            result['before_dispose'] = at_dispose
            result['dispose_argument'] = read(at_dispose['sp'] + 1, 4).hex()
            private_dp = int.from_bytes(read(address('debug_dp'), 2), 'little')
            client.set_regs(REG_D, d=private_dp)
            result['diagnostic_dispose_dp'] = private_dp
        actual = reach(arm('native_quit'), timeout=20)
        result['before_quit'] = actual
        if args.game:
            result['input_cleanup']={name:int.from_bytes(read(address(name),2),'little') for name in ['input_pending','input_tool_owned','input_mode_owned','input_cleanup_error','input_old_mode','input_exit_mode']}
            assert not any(result['input_cleanup'][name] for name in ['input_pending','input_tool_owned','input_mode_owned','input_cleanup_error']),result['input_cleanup']
            assert not (result['input_cleanup']['input_old_mode']^result['input_cleanup']['input_exit_mode'])&1,result['input_cleanup']
        result['cpu_matches'] = {name: actual[name] == entry[name]
                                 for name in ('sp', 'd', 'db', 'p')}
        restored_display = read(0xe12000, 32768)
        result['display_matches'] = restored_display == original_display
        differences = [i for i, (a, b) in enumerate(zip(restored_display, original_display)) if a != b]
        result['display_difference_count'] = len(differences)
        result['display_difference_examples'] = [{'offset': i, 'entry': original_display[i], 'restored': restored_display[i]} for i in differences[:64]]
        if args.scenario == 'quit':
            result['restored_vs_saved_differences'] = [i for i, (a, b) in enumerate(zip(restored_display, saved_snapshot)) if a != b]
        result['caller_dp_matches'] = read(entry['d'], 4) == original_dp
        if 'debug_cleanup_error' in symbols:
            result['cleanup_error'] = int.from_bytes(read(address('debug_cleanup_error'), 2), 'little')
            if result['cleanup_error']:
                raise AssertionError('DisposeHandle returned error %04x' % result['cleanup_error'])
        result['hardware_original'] = {name: value.hex() for name, value in original_hardware.items()}
        result['hardware_actual'] = {name: read(location, 1).hex() for name, location in hardware.items()}
        masks = {name: (0x0f if name == 'old_border' else 0xff) for name in hardware}
        result['hardware_comparison_masks'] = masks
        result['hardware_matches'] = {name: (int(result['hardware_actual'][name], 16) & masks[name]) == (value[0] & masks[name])
                                      for name, value in original_hardware.items()}
        if not all(result['cpu_matches'].values()):
            raise AssertionError('Restoration mismatch; see retained abi evidence JSON')
        if not result['display_matches'] or not result['caller_dp_matches'] or not all(result['hardware_matches'].values()):
            raise AssertionError('Restoration mismatch; see retained abi evidence JSON')
        client.continue_()
        if args.post_quit_check:
            time.sleep(3)
            client.pause()
            client.wait_stopped(timeout=5)
            post = regs(client.get_regs())
            result['after_quit_cpu'] = post
            pc = post['pb'] * 65536 + post['pc']
            result['quit_left_native_image'] = not (args.base <= pc < args.base + symbols['native_end'])
            if not result['quit_left_native_image'] or pc == 0x00c071:
                raise AssertionError('QuitGS did not leave native code safely; see retained evidence')
        result['pass'] = True
        print(json.dumps({k: result[k] for k in ('scenario', 'cpu_matches', 'display_matches', 'caller_dp_matches', 'hardware_matches', 'pass')}, indent=2))
    except Exception as exc:
        result['error'] = str(exc)
        try:
            client.pause()
            client.wait_stopped(timeout=5)
            result['failure_cpu'] = regs(client.get_regs())
            result['failure_globals'] = {name: read(address(name), 4).hex() for name in ('user_id', 'dp_handle', 'memory_active', 'tool_active') if name in symbols}
            result['failure_trace'] = [entry.hex() for entry in client.get_trace(ago=0, count=512).entries]
        except Exception as diagnostic_error:
            result['failure_capture_error'] = str(diagnostic_error)
        raise
    finally:
        try:
            client.quit()
        finally:
            client.close()
            (folder / ('abi-' + args.scenario + '.json')).write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
