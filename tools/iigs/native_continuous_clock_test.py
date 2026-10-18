#!/usr/bin/env python3
"""Run the native clock's real deadline/drop/wrap engine in Golden Gate.

The temporary ORCA/C main only reports the assembly self-test result. It is not
linked into the native game. This checks arithmetic, not live GS/OS timing.
"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/iigs/native-continuous-clock-test'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wrapper = OUT / 'wrapper.s'
    reporter = OUT / 'reporter.c'
    wrapper.write_text(' case on\nclock_test_entry START\n longa on\n longi on\n'
                       ' phb\n phk\n plb\n jsr clock_selftest\n plb\n rtl\n'
                       ' copy src/iigs/continuous_clock.asm\nraster_line lda #0\n rts\n END\n')
    reporter.write_text('#include <stdio.h>\nextern unsigned clock_test_entry(void);\n'
                        'int main(void) { unsigned result=clock_test_entry(); '
                        'printf("native deadline/drop/wrap selftest: %u\\n",result); '
                        'return result; }\n')
    asm_obj = OUT / 'assembly'
    c_obj = OUT / 'reporter'
    binary = OUT / 'clock-test'
    commands = [
        ['iix', 'assemble', str(wrapper), 'keep=' + str(asm_obj)],
        ['iix', 'compile', str(reporter), 'keep=' + str(c_obj)],
        ['iix', 'link', str(c_obj), str(asm_obj), 'keep=' + str(binary)],
        ['iix', str(binary)],
    ]
    logs = []
    for index, command in enumerate(commands):
        result = subprocess.run(command, cwd=ROOT, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=60)
        (OUT / ('step-%d.log' % index)).write_text(result.stdout)
        logs.append(dict(command=command, returncode=result.returncode))
        if result.returncode:
            raise SystemExit(result.stdout)
    if result.stdout.strip() != 'native deadline/drop/wrap selftest: 0':
        raise SystemExit('Missing successful native self-test completion')
    # ORCA/M requires LONGA directives as well as runtime SEP/REP. These
    # linked sequences guard byte-path immediates that the arithmetic-only
    # self-test cannot execute without live hardware.
    machine_code = binary.read_bytes()
    byte_paths = {
        'IRQ-state byte immediate': ('08e220682904c22029ff00', 2),
        'C041 byte read and mask': ('e220af41c0e02908c22029ff00', 1),
        'C046 byte read and mask': ('e220af46c0e02908c22029ff00', 2),
    }
    for label, (encoded, expected) in byte_paths.items():
        if machine_code.count(bytes.fromhex(encoded)) != expected:
            raise SystemExit('Incorrect linked instruction width: ' + label)
    paths = [ROOT / 'src/iigs/continuous_clock.asm', wrapper, reporter, binary]
    (OUT / 'manifest.json').write_text(json.dumps(dict(
        scope='Native arithmetic only; live GS/OS clock integration is separate',
        commands=logs, hashes={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in paths}), indent=2) + '\n')
    print(result.stdout.strip())
    gate_test()


def gate_test():
    """Execute real due/cache/dispatch code; only hardware sample is substituted.

    Controlled sample epochs reproduce races between cheap tick read and the
    raster-bracketed sampler. The unchanged real sampler remains linked above
    and its hardware instruction widths are checked by the first test.
    """
    source=(ROOT/'src/iigs/continuous_clock.asm').read_text()
    source=source.replace('clock_sample              lda #4096',
                          'clock_hardware_sample     lda #4096')
    lines=[' case on','clock_gate_entry START',' longa on',' longi on',
           ' php',' phb',' phk',' plb',' lda $20',' pha',' lda $22',' pha',
           ' lda #tc_tick',' sta $20',' lda #^tc_tick',' sta $22',' cld',' cli']
    checks=[]
    def emit(text):lines.extend(text.splitlines())
    def put(label,value):
        emit(f' lda #{value&65535}\n sta {label}')
    def put32(label,value):
        put(label,value);put(label+'+2',value>>16)
    def expect(label,value):
        i=len(checks)+1;checks.append((label,value))
        emit(f' lda {label}\n cmp #{value}\n beq tc_ok_{i}\n lda #{i}\n jmp tc_done\ntc_ok_{i} anop')
    def due(expected):
        emit(' jsr clock_due\n sta tc_result');expect('tc_result',expected)
    def reset():
        emit(' jsr clock_reset\n stz tc_samples\n stz tc_sample_fault')
    def epoch(tick,time,sampled=None):
        put32('tc_tick',tick);put32('tc_sample_epoch',tick if sampled is None else sampled)
        put32('tc_sample_time',time)
    reset()
    for phase_line,expected in ((200,1254),(0,1192),(191,1001),(192,1262)):
        put32('clock_time',1000);put('clock_line',phase_line)
        emit(' jsr clock_arm_vbl');expect('clock_next',expected);expect('clock_next+2',0)
    put32('clock_time',0xfffffffe);put('clock_line',193)
    emit(' jsr clock_arm_vbl');expect('clock_next',259);expect('clock_next+2',0)
    reset();put32('clock_next',262);epoch(0,0);due(0)
    expect('tc_samples',1);expect('clock_checked_valid',1)
    # Same tick must ignore speculative different sampler inputs.
    put32('tc_sample_time',262);put32('tc_sample_epoch',1);due(0);expect('tc_samples',1)
    epoch(1,262);due(1);expect('clock_delivered',1);expect('clock_next',524)
    epoch(4,1048);due(1);expect('clock_delivered',2);expect('clock_dropped',2)
    # Tick changes during full sample: cache accepted tick6, never pre-read5.
    epoch(5,1572,6);due(1);expect('clock_checked_tick',6);expect('tc_samples',4)
    put32('tc_tick',6);due(0);expect('tc_samples',4)
    # A profiling sample between due calls must not steal a future dispatch.
    put32('tc_sample_epoch',7);put32('tc_sample_time',1834)
    emit(' jsr clock_sample');expect('clock_checked_tick',6)
    due(0);expect('tc_samples',5)
    put32('tc_tick',7);due(1);expect('tc_samples',6);expect('clock_checked_tick',7)
    for before,after in ((65535,65536),(0xffffffff,0)):
        reset();put32('clock_next',262);epoch(before,0);due(0)
        epoch(after,262);due(1);expect('tc_samples',2)
        expect('clock_checked_tick',after&65535);expect('clock_checked_tick+2',after>>16)
    # Existing fault checked before same-tick fast return.
    put('clock_fault',1);due(0);expect('tc_samples',2)
    # IRQ-off invocation is rejected even when the OS tick is unchanged.
    emit(' stz clock_fault\n sei');due(0);emit(' cli')
    expect('clock_fault',1);expect('tc_samples',2)
    # Neither a failed full sample nor dispatch watchdog may publish a cache.
    reset();put32('clock_next',262);epoch(1,262);put('tc_sample_fault',1)
    due(0);expect('clock_checked_valid',0)
    reset();put32('clock_next',262);epoch(65,262*65)
    due(0);expect('clock_fault',1);expect('clock_checked_valid',0)
    # reset invalidates a previously used cache, including both tick words.
    put32('clock_checked_tick',0xffffffff);put('clock_checked_valid',1)
    emit(' jsr clock_reset');expect('clock_checked_tick',0)
    expect('clock_checked_tick+2',0);expect('clock_checked_valid',0)
    emit(' lda #0\ntc_done sta tc_result\n pla\n sta $22\n pla\n sta $20\n lda tc_result\n plb\n plp\n rtl')
    emit(source)
    emit("""clock_sample inc tc_samples
 lda tc_sample_epoch
 sta clock_before
 lda tc_sample_epoch+2
 sta clock_before+2
 lda tc_sample_time
 sta clock_time
 lda tc_sample_time+2
 sta clock_time+2
 lda tc_sample_fault
 sta clock_fault
 rts
raster_line lda #0
 rts
tc_tick ds 4
tc_sample_epoch ds 4
tc_sample_time ds 4
tc_sample_fault ds 2
tc_samples ds 2
tc_result ds 2
 END""")
    wrapper=OUT/'gate.s';wrapper.write_text('\n'.join(lines)+'\n')
    reporter=OUT/'gate.c'
    reporter.write_text('#include <stdio.h>\nextern unsigned clock_gate_entry(void);\n'
                        'int main(void){unsigned r=clock_gate_entry();'
                        'printf("native clock gate selftest: %u\\n",r);return r;}\n')
    commands=[['iix','assemble',str(wrapper),'keep='+str(OUT/'gate-asm')],
              ['iix','compile',str(reporter),'keep='+str(OUT/'gate-c')],
              ['iix','link',str(OUT/'gate-c'),str(OUT/'gate-asm'),'keep='+str(OUT/'gate-test')],
              ['iix',str(OUT/'gate-test')]]
    for i,command in enumerate(commands):
        result=subprocess.run(command,cwd=ROOT,text=True,stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT,timeout=60)
        (OUT/f'gate-{i}.log').write_text(result.stdout)
        if result.returncode:raise SystemExit(result.stdout)
    if result.stdout.strip()!='native clock gate selftest: 0':
        raise SystemExit(result.stdout+'\nChecks: '+repr(checks))
    (OUT/'gate-checks.json').write_text(json.dumps(checks,indent=2)+'\n')
    print(result.stdout.strip()+f' ({len(checks)} assertions)')


if __name__ == '__main__':
    main()
