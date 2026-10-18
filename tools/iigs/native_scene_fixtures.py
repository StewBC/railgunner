"""Snapshots for native pixel proofs; no scheduling/performance model."""
import struct
from native_render_assets import source_frames
from native_game_pixels import render

def snapshot(objects=(), *, glyphs=None, colors=None, present=0):
    glyphs=bytes((i*13+32)&255 for i in range(1000)) if glyphs is None else bytes(glyphs)
    colors=bytes(i%15+1 for i in range(1000)) if colors is None else bytes(colors)
    slots=[[0]*8 for _ in range(24)]
    for slot,obj in objects:slots[slot]=obj
    return glyphs+colors+b''.join(struct.pack('<8H',*o) for o in slots)+struct.pack('<2H',present,3)

def obj(x,y,ptr=0xca,color=3,attr=1,kind=2,player=0,flags=3):
    return [x+24,y+50,ptr,player,color,attr,kind,flags]

def fixtures():
    frames,lookup,players=source_frames()
    pointer=next(i for i,f in enumerate(lookup) if f==30)
    cases=[]
    before=snapshot([(0,obj(120,85,0xf8,7,0,0)),(1,obj(20,12)),(2,obj(250,140))])
    cases.append(('unchanged',before,before))
    for name,x,y in [('hud',110,-8),('hud_odd',111,1),('left',-13,90),('right',310,90),('bottom',150,193),('above',100,-40),('outside_left',-24,80),('outside_right',320,80)]:
        cases.append((name,before,snapshot([(0,obj(x,y,0xf8,7,0,0)),(1,obj(x+1,y))])))
    hud_old=bytearray(1000);hud_colors=bytearray([15]*1000)
    hud_old[5]=0x53;hud_old[6]=0x55
    hud_new=bytearray(hud_old);hud_new[5]=0x20
    hud_new_colors=bytearray(hud_colors);hud_new_colors[6]=0
    cases.append(('hud_glyph_to_blank_and_color_zero',snapshot(glyphs=hud_old,colors=hud_colors),snapshot(glyphs=hud_new,colors=hud_new_colors)))
    cases.append(('despawn',before,snapshot()))
    cases.append(('spawn',snapshot(),before))
    overlap=[(0,obj(101,88,0xf8,7,0,0)),(1,obj(102,89,0xca,3,1,1)),(2,obj(103,90,0xca,5,1,2)),(3,obj(104,91,0xca,2,1,3)),(4,obj(105,92,pointer,8,1,4))]
    old=snapshot(overlap);new=[(s,o[:]) for s,o in overlap];new[1][1][0]+=3;new[1][1][4]=6
    cases.append(('stationary_overlap_priority',old,snapshot(new)))
    old=snapshot([(1,obj(100,80)),(2,obj(115,80)),(3,obj(130,80))]);new=snapshot([(2,obj(115,80)),(3,obj(130,80))])
    cases.append(('cell_expansion_chain',old,new))
    glyphs=bytearray(1000);colors=bytearray([11]*1000)
    # Current glyph regeneration must restore all four mine glyphs and rail states.
    for j,g in enumerate((0x53,0x55,0x57,0x59,0x51,0x52,0x20)):
        glyphs[12*40+17+j]=g
    old=snapshot([(0,obj(140,91,0xf8,7,0,0)),(1,obj(155,91))],glyphs=glyphs,colors=colors)
    changed=bytearray(glyphs);changed[12*40+18]=0x20;changed[12*40+19]=0x53
    new=snapshot([(0,obj(144,91,0xf8,7,0,0)),(1,obj(155,100))],glyphs=changed,colors=colors)
    cases.append(('current_rails_mines',old,new))
    colors2=bytearray(colors);colors2[12*40+20]=3
    cases.append(('glyph_change_under_stationary',new,snapshot([(0,obj(144,91,0xf8,7,0,0)),(1,obj(155,100))],glyphs=changed,colors=colors2)))
    # Ten actual art objects, deliberately seeded as placement stress, not a legal playthrough.
    ten=[(0,obj(148,96,0xf8,7,0,0))]+[(i,obj(20+(i%4)*75,20+(i//4)*95,0xca,2+i%4,1,1+i%3)) for i in range(1,8)]+[(8,obj(140,115,pointer,8,1,4)),(9,obj(170,85,pointer,5,1,4))]
    moved=[(s,o[:]) for s,o in ten]
    for s,o in moved:o[0]+=1 if s&1 else -1
    cases.append(('ten_real_assets_placement_stress',snapshot(ten),snapshot(moved)))
    cases.append(('title_to_play',snapshot(present=1),before))
    cases.append(('title_to_play_hud',snapshot(present=1),snapshot([(1,obj(111,-8))])))
    cases.append(('play_to_title',before,snapshot(present=1)))
    return cases

def background(snapshot):
    raw=bytearray(snapshot)
    for slot in range(24):struct.pack_into('<H',raw,2014+slot*16,0)
    return render(bytes(raw),sprite_top=8)[0]
