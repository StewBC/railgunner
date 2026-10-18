#!/usr/bin/env python3
"""Specialized lifecycle extension of the accepted native CPU/display ABI check.
Requires a fresh owned windowed session; records distinct caller 01/E1 bitmaps.
"""
from pathlib import Path
import hashlib

BASE=Path(__file__).with_name('native_abi_test.py')
source=BASE.read_text()
def replace(old,new):
 global source
 assert source.count(old)==1,old
 source=source.replace(old,new)
replace("    args = parser.parse_args()", "    parser.add_argument('--early-after-backup', action='store_true')\n    args = parser.parse_args()\n    if args.already_running:\n        raise RuntimeError('Distinct caller buffers require a fresh native entry')")
replace("            if args.pattern_display:\n", """            shadow = read(0xe0c035, 1)
            client.write_mem(0, 0xe0c035, bytes([shadow[0] | 8]))
            pattern01 = bytes((i*13+7) & 255 for i in range(32000))
            for offset in range(0, 32000, 4096):
                client.write_mem(0, 0x012000+offset, pattern01[offset:offset+4096])
            client.write_mem(0, 0xe0c035, shadow)
            original_bank01 = read(0x012000, 32000)
            if args.pattern_display:
""")
replace("            original_display = read(0xe12000, 32768)\n", "            original_display = read(0xe12000, 32768)\n            assert original_bank01 != original_display[:32000], 'Caller buffers must be distinct'\n")
replace("            reach(arm('main_loop'))", """            reach(arm('ng_initial_copied' if args.early_after_backup else 'main_loop'))
            assert int.from_bytes(read(address('swl_saved_valid'), 2), 'little') == 1
            saved01_load = read(address('swl_restore_word'), 4)
            assert saved01_load[0] == 0xbf
            saved01_address = int.from_bytes(saved01_load[1:], 'little')
            assert read(saved01_address, 32000) == original_bank01
            result['bank01_backup_address'] = saved01_address
            result['early_after_backup'] = args.early_after_backup""")
replace("            if args.game:\n                client.key_down(224,64)", "            if args.early_after_backup:\n                target=address('ng_exit')\n                client.set_regs(REG_PC|REG_PB, pc=target&65535, pb=target>>16)\n            elif args.game:\n                client.key_down(224,64)")
replace("            if args.game:\n                client.key_up(20,64)", "            if args.game and not args.early_after_backup:\n                client.key_up(20,64)")
replace("        result['before_quit'] = actual", """        result['before_quit'] = actual
        result['bank01_matches'] = read(0x012000, 32000) == original_bank01
        result['bank01_sha256'] = hashlib.sha256(original_bank01).hexdigest()
        result['backup_flag_cleared'] = read(address('swl_saved_valid'), 2) == b'\\0\\0'
        result['base_helper_sha256'] = hashlib.sha256(BASE.read_bytes()).hexdigest()
        assert result['bank01_matches'] and result['backup_flag_cleared'], result
""")
replace("('abi-' + args.scenario + '.json')", "('specialized-abi-' + args.scenario + ('-early' if args.early_after_backup else '') + '.json')")
exec(compile(source, str(Path(__file__)), 'exec'))
