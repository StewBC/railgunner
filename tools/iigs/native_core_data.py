"""Explicit selected C64 data declarations for native gameplay groups.

Mutable declarations are emitted into GAME's cleared state region. Immutable
lookup tables remain outside that region. No original fixed address is retained.
"""
import ast
import re
from native_core import numeric


def strip_comment(line):
    quote=None;escaped=False
    for i,char in enumerate(line):
        if escaped:escaped=False;continue
        if char=='\\' and quote:escaped=True;continue
        if char in ('"',"'"):
            if quote==char:quote=None
            elif quote is None:quote=char
        if char==';' and quote is None:return line[:i]
    return line


def split_values(text):
    parts=[];start=0;quote=None;escaped=False;depth=0
    for i,char in enumerate(text):
        if escaped:escaped=False;continue
        if char=='\\' and quote:escaped=True;continue
        if char in ('"',"'"):
            if quote==char:quote=None
            elif quote is None:quote=char
        if quote:continue
        if char=='(':depth+=1
        elif char==')':depth-=1
        elif char==',' and depth==0:parts.append(text[start:i].strip());start=i+1
    if quote or depth:raise ValueError('Unbalanced selected data expression')
    parts.append(text[start:].strip());return parts


def collect(adapter,path,selected):
    selected=set(selected);seen=set();scopes=[];procedure=False;current=None;rows=[]
    for lineno,line in enumerate((adapter.root/path).read_text().splitlines(),1):
        code=strip_comment(line).strip()
        if not code:continue
        if code.startswith('.scope '):scopes.append(code.split()[1]);current=None;continue
        if code=='.endscope':scopes.pop();current=None;continue
        if code.startswith('.proc '):procedure=True;current=None;continue
        if code=='.endproc':procedure=False;current=None;continue
        if code.startswith('.segment '):current=None;continue
        if procedure:continue
        if re.match(r'^\w+\s*=',code):current=None;continue
        match=re.match(r'^(\w+):\s*(.*)$',code)
        if match:
            name,code=match.groups();current='::'.join(scopes+[name])
            if current in selected:
                if current in seen:raise ValueError(f'{path}:{lineno}: repeated selected declaration')
                seen.add(current);adapter.symbols.add(current)
        if current not in selected or not code:continue
        if not code.startswith(('.res ','.byte ','.word ')):
            raise ValueError(f'{path}:{lineno}: unsupported selected data {code}')
        rows.append((path,lineno,current,scopes[:],code))
    if seen!=selected:raise ValueError(f'{path}: missing selected data {sorted(selected-seen)}')
    return rows


def emit(adapter,rows,initialized=(),all_layout=None):
    mutable=[];immutable=[];layout={};emitted=set();initialized=set(initialized)
    for path,line,name,scope,code in rows:
        try:
            directive,body=code.split(None,1)
            label=adapter.flat(name) if name not in emitted else '';emitted.add(name)
            if directive=='.res':
                parts=split_values(body)
                if len(parts)>1 and numeric(parts[1],adapter.values)!=0:raise ValueError('Nonzero mutable initializer needs explicit support')
                count=numeric(parts[0],adapter.values)
                if count<0:raise ValueError('Negative data length')
                mutable.append(f'{label} ds {count}');layout.setdefault(name,{'width':1,'count':0});layout[name]['count']+=count
            else:
                values=[];width=1 if directive=='.byte' else 2
                for token in split_values(body):
                    if token.startswith('"'):
                        if width!=1:raise ValueError('String in word data')
                        value=ast.literal_eval(token)
                        values.extend(str(x) for x in value.encode('ascii'))
                    else:
                        value=adapter.expression(token,scope,None)
                        if width==1:
                            if value.startswith('<'):value=value[1:]
                            elif value.startswith('>'):value='('+value[1:]+'|-8)'
                        values.append(value)
                record=f"{label} dc i{width}'{','.join(values)}'"
                if all_layout is not None:
                    all_layout.setdefault(name,{'width':width,'count':0});all_layout[name]['count']+=len(values)
                if name in initialized:
                    if width!=1:raise ValueError('Initialized mutable frontend data must be bytes')
                    mutable.append(record)
                    immutable.append(f"{'native_initial__'+label if label else ''} dc i1'{','.join(values)}'")
                    layout.setdefault(name,{'width':1,'count':0});layout[name]['count']+=len(values)
                else:immutable.append(record)
        except (ValueError,KeyError) as error:raise ValueError(f'{path}:{line}: {error}') from error
    return mutable,immutable,layout
