#!/usr/bin/env python3
"""Check selected original data binding without assembling a new gameplay group."""
from pathlib import Path
import json
from native_core import Adapter
from native_core_data import collect,emit,split_values,strip_comment
ROOT=Path(__file__).resolve().parents[2]
policy=json.loads((ROOT/'src/iigs/core-manifest.json').read_text());policy['native_symbols']=[]
a=Adapter(ROOT,policy);a.constants_from('src/c64/sys/const.asm')
rail=['rail_data::'+name for name in 'dmg_d dmg_e dmg_f dmg_va dmg_vb dmg_vc ghij_stack heal_mark_d heal_mark_e heal_mark_f heal_mark_va heal_mark_vb heal_mark_vc dmg_amt hit_left hit_slot'.split()]
rows=collect(a,'src/c64/game/rail.asm',rail)
mutable,immutable,layout=emit(a,rows)
assert not immutable and sum(x['count'] for x in layout.values())==397
bullets=['bullets::'+name for name in 'bullet_active bullet_col bullet_row bullet_half bullet_dir bullet_phase bullet_hold fire_lock'.split()]
mutable,immutable,layout=emit(a,collect(a,'src/c64/render/bullets.asm',bullets))
assert not immutable and sum(x['count'] for x in layout.values())==7*a.values['BULLET_MAX']+1
tables=['rail::'+name+'_glyph' for name in 'd e f a b c'.split()]
mutable,immutable,layout=emit(a,collect(a,'src/c64/game/rail.asm',tables))
assert not mutable and len(immutable)==6
assert strip_comment(' .byte "A;B",0 ; ignored')==' .byte "A;B",0 '
assert split_values("'A',\"B,C\",(2+3)")==["'A'",'"B,C"','(2+3)']
try:collect(a,'src/c64/game/rail.asm',['rail_data::not_real'])
except ValueError:pass
else:raise AssertionError('Missing data binding accepted')
all_layout={}
rows=collect(a,'src/c64/data/strings.asm',['hs_line_1'])
mutable,immutable,layout=emit(a,rows,initialized=['hs_line_1'],all_layout=all_layout)
assert layout['hs_line_1']=={'width':1,'count':38}
assert all_layout['hs_line_1']=={'width':1,'count':38}
assert mutable[0].startswith("hs_line_1 dc i1'")
assert immutable[0].startswith("native_initial__hs_line_1 dc i1'")
assert mutable[0].split(' dc ')[1]==immutable[0].split(' dc ')[1]
print('PASS: original397byte rail state, bullet arrays, six glyph tables, quoted delimiters, missing-binding rejection')
