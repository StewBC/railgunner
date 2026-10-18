#!/usr/bin/env python3
"""Fail-closed syntax, binding and hook checks for the native C64 adapter."""
from pathlib import Path
import tempfile
from native_core import Adapter


def adapt(source,**changes):
    with tempfile.TemporaryDirectory(prefix='railgunner-adapter-') as folder:
        root=Path(folder);(root/'input.asm').write_text(source)
        policy={'native_symbols':[],'storage_overrides':{},'blocked_hardware':['VIC_BORDER','SID_V1_FL']}
        policy.update(changes);a=Adapter(root,policy)
        if changes.get('test_dp'):
            (root/'zp.asm').write_text('list: .res 4\n');a.direct_page_from('zp.asm')
        if changes.get('test_constants'):a.selected_constants_from('input.asm',changes['test_constants'])
        a.select('input.asm',['foo::test']);return a.emit()


def rejected(body,**changes):
    try:adapt('.scope foo\n.proc test\n'+body+'\n.endproc\n.endscope\n',**changes)
    except ValueError:return
    raise AssertionError('Unexpectedly accepted: '+body)

result=adapt('LOCAL=1+2*3\n.scope foo\n.proc test\n lda #LOCAL\n.endproc\n.endscope\n',test_constants=['LOCAL'])
assert 'lda #7' in result
rejected('rts',test_constants=['MISSING'])
result=adapt('.scope foo\n.proc test\n lda #(1+2*3)\n beq done\ndone: rts\n.endproc\n.endscope\n')
assert 'lda #7' in result
assert 'bne native_branch_' in result and 'jmp foo__test__done' in result
rejected(' sei')
rejected(' sta $D020')
rejected(' lda #SID_V1_FL')
rejected(' jsr missing')
assert "dc i1'0,255'" in adapt('.scope foo\n.proc test\n .byte 0,$FF\n.endproc\n.endscope\n')
rejected(' .res 1')
rejected(' .byte 256')
result=adapt('.scope foo\n.proc test\n sta list,y\n rts\n.endproc\n.endscope\n',test_dp=True)
assert 'php\n phx\n tyx\n sta 2,x\n plx\n plp' in result
rejected(' lda #symbol*2',native_symbols=['symbol'])
policy={'foo::test':[{'match':'sta tmp0','before':['and #15'],'count':1}]}
result=adapt('.scope foo\n.proc test\n sta tmp0\n rts\n.endproc\n.endscope\n',native_symbols=['tmp0'],instruction_hooks=policy)
assert 'and #15' in result
rejected(' rts',instruction_hooks=policy)
rejected(' sta tmp0\n sta tmp0',native_symbols=['tmp0'],instruction_hooks=policy)
replacement={'foo::test':[{'match':'sta VIC_BORDER','replace':['sta native_border'],'count':1}]}
result=adapt('.scope foo\n.proc test\n sta VIC_BORDER\n rts\n.endproc\n.endscope\n',native_symbols=['native_border'],instruction_replacements=replacement)
assert 'sta native_border' in result and 'sta VIC_BORDER' not in result
rejected(' rts',instruction_replacements=replacement)
rejected(' sta VIC_BORDER\n sta VIC_BORDER',native_symbols=['native_border'],instruction_replacements=replacement)
print('PASS: precedence/scoped branches; rejected hardware, IRQ, unknown syntax/names and changed hook sites')
