#!/usr/bin/env python3
"""Compare declared native CORETEST modules with the host semantic oracle."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
import sys
import time
import native_oracle

ROOT = Path(__file__).resolve().parents[2]

class Controller:
    def __init__(self, client, mapping, base):
        self.client, self.mapping, self.base = client, mapping, base
        self.seq = self.word('core_completed_seq')
        self.game = self.word('core_game_base', 4)
        self.dp = self.word('core_game_dp')
        assert 0 < self.game < 0x1000000 and self.dp % 256 == 0
    def read(self, address, count):
        return b''.join(self.client.read_mem(0, address+i, min(65536,count-i)) for i in range(0,count,65536))
    def word(self, name, width=2):
        return int.from_bytes(self.read(self.base+self.mapping['mailbox'][name],width),'little')
    def command(self, command, call=0, a=0, x=0, y=0, carry=0, variant=0, ticks=1, inputs=None):
        # Only command through input bytes: explicit offsets avoid dependence on padding.
        start=self.mapping['mailbox']['core_command']
        data=bytearray(self.mapping['mailbox']['core_input_runstop']-start+1)
        for name,value,width in [('core_command',command,2),('core_variant',variant,2),('core_ticks',ticks,2),('core_call_id',call,2),('core_arg_a',a,1),('core_arg_x',x,1),('core_arg_y',y,1),('core_arg_carry',carry,1)]:
            off=self.mapping['mailbox'][name]-start
            data[off:off+width]=value.to_bytes(width,'little')
        for name,value in (inputs or {}).items():
            if name not in ('dirs','fire','key_s','key_i','runstop'):
                raise ValueError('Unknown input field: '+name)
            if not 0<=value<=255:
                raise ValueError('Input byte out of range: '+name)
            off=self.mapping['mailbox']['core_input_'+name]-start
            data[off]=value
        self.client.write_mem(0,self.base+start,bytes(data))
        self.seq=(self.seq+1)&65535
        self.client.write_mem(0,self.base+self.mapping['mailbox']['core_request_seq'],self.seq.to_bytes(2,'little'))
        deadline=time.monotonic()+5
        # Guest publishes completed_seq last, then leaves all result bytes
        # immutable until the next request. One read observes that whole record.
        mailbox=self.mapping['mailbox'];first=mailbox['core_completed_seq']
        end=max(mailbox['core_status']+2,mailbox['core_ret_p']+1,first+2)
        while True:
            result=self.read(self.base+first,end-first)
            if int.from_bytes(result[:2],'little')==self.seq:break
            if time.monotonic()>deadline: raise TimeoutError('Native command did not complete')
            time.sleep(.002)
        self.last_completion=(first,result)
        at=mailbox['core_status']-first
        status=int.from_bytes(result[at:at+2],'little')
        assert status==0,status
        at=mailbox['core_ret_a']-first;raw=result[at:at+4]
        return dict(zip(('a','x','y','p'),raw))
    def invoke(self,name,**args):
        return self.command(3,self.mapping['calls'][name],**args)
    def snapshot(self,fields):
        spaces={'game':self.game,'dp':self.dp,'driver':self.base}
        result={}
        images={}
        starts={}
        for space,base in spaces.items():
            selected=[self.mapping['state'][name] for name in fields if self.mapping['state'][name]['space']==space]
            if not selected:
                continue
            spans=[(part['offset'],part['offset']+spec['width']*part['count'])
                   for spec in selected
                   for part in spec.get('parts',[spec])]
            start=min(start for start,end in spans)
            end=max(end for start,end in spans)
            starts[space]=start
            images[space]=self.read(base+start,end-start)
        for name in fields:
            spec=self.mapping['state'][name]
            raw=b''.join(images[spec['space']][part['offset']-starts[spec['space']]:
                         part['offset']-starts[spec['space']]+spec['width']*part['count']]
                         for part in spec.get('parts',[spec]))
            assert len(raw)==spec['width']*spec['count'], 'Invalid state-map parts: '+name
            values=[int.from_bytes(raw[i:i+spec['width']],'little') for i in range(0,len(raw),spec['width'])]
            result[name]=values[0] if spec['count']==1 else values
        return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--session',type=Path,required=True)
    p.add_argument('--map',type=Path,required=True)
    p.add_argument('--base',type=lambda v:int(v,0),default=0xa0000)
    args=p.parse_args()
    session=json.loads(args.session.read_text()); mapping=json.loads(args.map.read_text())
    folder=args.session.parent
    assert hashlib.sha256((folder/'Start').read_bytes()).hexdigest()==session['binary_sha256']
    manifest=json.loads((folder/'build-manifest.json').read_text())
    expected=[v for k,v in manifest['hashes'].items() if k.endswith('/state-map.json')]
    assert len(expected)==1 and hashlib.sha256(args.map.read_bytes()).hexdigest()==expected[0], 'State map does not match private build manifest'

    sys.path.insert(0,str(ROOT.parent.parent/'external/gssquared/clients/python/src'))
    from gs2debug import Client
    built,oracle_manifest=native_oracle.build()
    binary=folder/'host-oracle'
    shutil.copy2(built,binary)
    (folder/'host-oracle-manifest.json').write_text(json.dumps(oracle_manifest,indent=2)+'\n')
    client=Client(); checks=[]
    try:
        client.connect(session['socket']); client.hello(); client.continue_()
        deadline=time.monotonic()+180
        while True:
            signature=client.read_mem(0,args.base+mapping['mailbox']['core_mailbox'],8)
            ready=client.read_mem(0,args.base+mapping['mailbox']['core_ready'],2)
            if signature==mapping['signature'].encode() and ready==b'\1\0':break
            if time.monotonic()>deadline:raise TimeoutError('CORETEST did not boot at expected base')
            time.sleep(.1)
        ctl=Controller(client,mapping,args.base)
        commands=['bare']
        required={'objects.'+name for name in ('flags','kind','x_frac','x_lo','x_hi','y_frac','y_int','sprite_ptr','sprite_color','sprite_attr','vx_frac','vx_lo','vx_hi','vy_frac','vy_int','hitbox_id','anim_state','user','reserved')}
        required.update(('free_stack','free_count','cells.glyph','cells.color'))
        assert required <= mapping['state'].keys(), 'Incomplete native state map'

        fields=[n for n in mapping['state'] if n.startswith('objects.') or n in ('free_stack','free_count','cells.glyph','cells.color')]
        def compare(label):
            expected=native_oracle.run_commands('\n'.join(commands+['dump'])+'\n',binary=binary)[-1]
            actual=ctl.snapshot(fields)
            for name in fields:
                if actual[name]!=expected[name]:
                    raise AssertionError(f'{label}: {name}: native={actual[name]!r} oracle={expected[name]!r}')
            checks.append(label)
        ctl.command(1); compare('bare')
        def call(native,host,**kw):
            ret=ctl.invoke(native,**kw); commands.append('call '+host); compare(host); return ret
        call('objects::init','objects_init')
        def seed(name,index,value):
            spec=mapping['state'][name]
            address={'game':ctl.game,'dp':ctl.dp,'driver':ctl.base}[spec['space']]+spec['offset']+index*spec['width']
            client.write_mem(0,address,value.to_bytes(spec['width'],'little'))
            commands.append(f'set {name} {index} {value}')
        for slot in (0,1,23):
            for i,name in enumerate(sorted(required)):
                if name.startswith('objects.'):seed(name,slot,33+i)
            compare(f'seed slot {slot}')
            call('objects::clear_slot',f'objects_clear_slot {slot}',x=slot)
        call('objects::init','objects_init')
        call('objects::alloc','objects_alloc')
        for i,name in enumerate(sorted(required)):
            if name.startswith('objects.'):seed(name,1,71+i)
        call('objects::discard_new','objects_discard_new 1',x=1)
        call('objects::alloc','objects_alloc')
        call('objects::discard_new','objects_discard_new 1',x=1)

        for slot in range(1,24):
            ret=call('objects::alloc','objects_alloc')
            assert ret['x']==slot and not(ret['p']&1)
        ret=call('objects::alloc','objects_alloc'); assert ret['p']&1
        call('objects::retire','objects_retire 0',x=0)
        for slot in (1,7,23):call('objects::retire',f'objects_retire {slot}',x=slot)
        call('objects::reap','objects_reap')
        call('objects::hide_all','objects_hide_all')
        call('screen_clear','screen_clear')
        for x,y,value in [(0,0,65),(39,24,255),(20,12,0),(1,23,127)]:
            call('screen_put_xy',f'screen_put_xy {x} {y} {value}',a=value,x=x,y=y)
            ret=call('screen_get_xy',f'screen_get_xy {x} {y}',x=x,y=y);assert ret['a']==value
            call('screen_color_xy',f'screen_color_xy {x} {y} 175',a=175,x=x,y=y)
        for row in (0,12,24):call('screen_color_row',f'screen_color_row {row} 175',a=175,y=row)
        for value in range(256):
            ret=ctl.invoke('ascii_to_screen',a=value)
            expected=native_oracle.run_commands(f'call ascii_to_screen {value}\n',binary=binary)[0]['value']
            assert ret['a']==expected, (value,ret,expected)
        checks.append('all 256 ASCII conversions')
        for x,y in ((0,0),(39,24),(17,11)):
            ctl.invoke('screen_addr_xy',x=x,y=y)
            ptr=ctl.read(ctl.dp+mapping['raw_dp']['ptr_lo']['offset'],2)
            assert int.from_bytes(ptr,'little')==(ctl.game+mapping['native_symbols']['SCREEN_RAM']+y*40+x)&65535
        checks.append('screen address corners and interior')
        text=b' AZ09!?_az\0'
        fixture=ctl.game+mapping['native_symbols']['native_fixture_data']
        client.write_mem(0,fixture,text)
        for name,value in [('ptr_lo',fixture&255),('ptr_hi',(fixture>>8)&255)]:
            client.write_mem(0,ctl.dp+mapping['raw_dp'][name]['offset'],bytes([value]))
        call('screen_print','screen_print_fixture 3 4',x=3,y=4)
        if 'objects::mux_objects_dirty' in mapping['native_symbols']:
            dirty=ctl.game+mapping['native_symbols']['objects::mux_objects_dirty']
            client.write_mem(0,dirty,b'\0')
            ctl.invoke('objects::mark_dirty')
            assert ctl.read(dirty,1)==b'\1'
            checks.append('render dirty publication')
        else:raise AssertionError('Missing render-dirty symbol')
        result={'pass':True,'scope':'N1 group1 pool and valid-coordinate cells; no fixed-tick gameplay or performance claim','checks':checks,'fields':fields,'session':session,'map_sha256':hashlib.sha256(args.map.read_bytes()).hexdigest(),'oracle_binary_sha256':oracle_manifest['binary_sha256'],'helper_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
        (folder/'core-proof.json').write_text(json.dumps(result,indent=2)+'\n')
        print(json.dumps({'pass':True,'checks':len(checks),'fields':len(fields),'proof':str(folder/'core-proof.json')}))
    finally:
        client.quit()

if __name__=='__main__':main()
