"""Strict C64-source adapter for Railgunner's bank-local native gameplay.

Only explicitly selected procedures are emitted. Hardware services and storage
are replaced by the audited native manifest, never by dropping instructions.
Unsupported selected syntax and unresolved names stop the build.
"""
from pathlib import Path
import ast
import operator
import re

BRANCHES={'bcc':'bcs','bcs':'bcc','beq':'bne','bne':'beq','bmi':'bpl','bpl':'bmi','bvc':'bvs','bvs':'bvc'}
OPS=set('adc and asl bit clc cld cmp cpx cpy dec dex dey eor inc inx iny jmp jsr lda ldx ldy lsr nop ora pha php pla plp rol ror rts sbc sec sta stx sty tax tay txa tya'.split())|set(BRANCHES)
IDENT=r'(?<![$\w:])(?:::)?[A-Za-z_]\w*(?:::[A-Za-z_]\w*)*'
BINARY={ast.Add:operator.add,ast.Sub:operator.sub,ast.Mult:operator.mul,ast.FloorDiv:operator.floordiv,ast.Div:operator.floordiv,ast.Mod:operator.mod,ast.LShift:operator.lshift,ast.RShift:operator.rshift,ast.BitAnd:operator.and_,ast.BitOr:operator.or_,ast.BitXor:operator.xor}


def numeric(text,values):
    text=re.sub(r"'([^'])'",lambda m:str(ord(m[1])),text)
    text=re.sub(r'\$([\da-fA-F]+)',r'0x\1',text)
    text=re.sub(r'%([01]+)',r'0b\1',text)
    def walk(node):
        if isinstance(node,ast.Constant) and isinstance(node.value,int):return node.value
        if isinstance(node,ast.Name):return values[node.id]
        if isinstance(node,ast.UnaryOp):
            n=walk(node.operand)
            if isinstance(node.op,ast.USub):return -n
            if isinstance(node.op,ast.UAdd):return n
            if isinstance(node.op,ast.Invert):return ~n
        if isinstance(node,ast.BinOp) and type(node.op) in BINARY:return BINARY[type(node.op)](walk(node.left),walk(node.right))
        raise ValueError('Unsupported constant expression: '+text)
    return walk(ast.parse(text,mode='eval').body)


class Adapter:
    def __init__(self,root,manifest):
        self.root=Path(root);self.manifest=manifest;self.values={};self.symbols=set(manifest['native_symbols']);self.rows=[];self.procedures={};self.dp={};self.branch=0;self.constants=[];self.hook_counts={};self.replacement_counts={}
    @staticmethod
    def flat(name):return name.removeprefix('::').replace('::','__')
    def constants_from(self,path):
        for lineno,line in enumerate((self.root/path).read_text().splitlines(),1):
            code=line.split(';',1)[0].strip()
            if not code:continue
            m=re.fullmatch(r'(\w+)\s*=\s*(.*)',code)
            if not m:raise ValueError(f'{path}:{lineno}: unsupported constant source {code}')
            name,text=m.groups();self.symbols.add(name)
            if name in self.manifest['storage_overrides']:continue
            if name in self.manifest.get('constant_overrides',{}):value=self.manifest['constant_overrides'][name]
            else:
                try:value=numeric(text,self.values)
                except KeyError:value=text
            if isinstance(value,int):self.values[name]=value
            self.constants.append((name,value))
    def selected_constants_from(self,path,selected):
        selected=set(selected);seen=set()
        for lineno,line in enumerate((self.root/path).read_text().splitlines(),1):
            code=line.split(';',1)[0].strip()
            match=re.fullmatch(r'(\w+)\s*=\s*(.*)',code)
            if not match or match[1] not in selected:continue
            name,text=match.groups()
            if name in seen or name in self.symbols:raise ValueError(f'{path}:{lineno}: selected constant collision {name}')
            value=numeric(text,self.values)
            self.symbols.add(name);self.values[name]=value;self.constants.append((name,value));seen.add(name)
        if seen!=selected:raise ValueError(f'{path}: selected constants missing {sorted(selected-seen)}')
    def direct_page_from(self,path):
        offset=2
        for lineno,line in enumerate((self.root/path).read_text().splitlines(),1):
            code=line.split(';',1)[0].strip()
            if not code:continue
            m=re.fullmatch(r'(\w+):\s*\.res\s+(\d+)',code)
            if not m:raise ValueError(f'{path}:{lineno}: unsupported direct-page source {code}')
            name,count=m.groups();count=int(count);self.dp[name]={'offset':offset,'width':1,'count':count};self.values[name]=offset;self.symbols.add(name);offset+=count
        if offset>256:raise ValueError('C64 gameplay direct page exceeds its separately owned 256 bytes')
        return offset
    def select(self,path,selected):
        scopes=[];procedure=None;selected=set(selected)
        for lineno,line in enumerate((self.root/path).read_text().splitlines(),1):
            code=line.split(';',1)[0].strip()
            if code.startswith('.scope '):scopes.append(code.split()[1]);continue
            if code=='.endscope':
                if not scopes:raise ValueError(f'{path}:{lineno}: unmatched scope')
                scopes.pop();continue
            if code.startswith('.proc '):
                if procedure is not None:raise ValueError(f'{path}:{lineno}: nested procedures unsupported')
                name=code.split()[1];procedure='::'.join(scopes+[name])
                if procedure in selected:
                    self.symbols.add(procedure);self.procedures[procedure]={'source':path,'line':lineno};self.rows.append((path,lineno,scopes[:],procedure,procedure+':',True))
                continue
            if code=='.endproc':procedure=None;continue
            if procedure not in selected or not code:continue
            m=re.match(r'^(\w+):\s*(.*)$',code)
            if m:self.symbols.add(procedure+'::'+m[1])
            self.rows.append((path,lineno,scopes[:],procedure,code,False))
        missing=selected-self.procedures.keys()
        if missing:raise ValueError(f'{path}: selected procedures absent: {sorted(missing)}')
    def resolve(self,name,scope,procedure):
        if name.startswith('::'):candidates=[name[2:]]
        else:
            parents=procedure.split('::') if procedure else scope[:]
            candidates=['::'.join(parents[:i]+[name]) for i in range(len(parents),-1,-1)]
        for candidate in candidates:
            if candidate in self.symbols:return self.flat(candidate)
        raise ValueError('Unresolved symbol '+name+' from '+str(procedure))
    def expression(self,text,scope,procedure):
        text=text.strip()
        prefix=''
        if text.startswith('#'):prefix='#';text=text[1:]
        tokens=re.findall(IDENT,text)
        blocked=set(tokens)&set(self.manifest['blocked_hardware'])
        if blocked:raise ValueError('Unreplaced C64 hardware operand: '+','.join(sorted(blocked)))
        # Fold entirely numeric expressions with C64 precedence first.
        try:value=numeric(text,self.values)
        except (KeyError,ValueError,SyntaxError,TypeError):value=None
        if value is not None:
            if not prefix and 0xc000<=value<=0xffff:
                raise ValueError('Literal C64 hardware/high-memory address must be replaced explicitly')
            return prefix+str(value)
        text=re.sub(r"'([^'])'",lambda m:str(ord(m[1])),text)
        tokens=re.findall(IDENT,text)
        blocked=set(tokens)&set(self.manifest['blocked_hardware'])
        if blocked:raise ValueError('Unreplaced C64 hardware operand: '+','.join(sorted(blocked)))
        text=re.sub(IDENT,lambda m:self.resolve(m[0],scope,procedure),text)
        # Selected source pointer expressions use unary low/high and +/- only.
        # ORCA's < and > unary byte operators are the proven Force convention.
        if any(op in text for op in ('<<','>>','&','|','^','*','/')):
            raise ValueError('Unfolded relocation expression needs explicit handling: '+text)
        return prefix+text.replace(' ','')
    def emit(self):
        lines=['; Generated from selected original C64 procedures. Native M=X=8, DBR=PBR, private D.']
        lines += [f'{name} equ {value}' for name,value in self.constants]
        lines += [f'{name} equ {entry["offset"]}' for name,entry in self.dp.items()]
        for path,lineno,scope,proc,code,entry in self.rows:
            try:
                if entry:lines += [f'; {path}:{lineno}',self.flat(proc)+' anop'];continue
                label='';m=re.match(r'^(\w+):\s*(.*)$',code)
                if m:label=self.flat(proc+'::'+m[1]);code=m[2]
                if not code:lines.append(label+' anop');continue
                op,_,operand=code.partition(' ');op=op.lower();operand=operand.strip()
                replaced=False
                for rule in self.manifest.get('instruction_replacements',{}).get(proc,[]):
                    if (op+' '+operand).lower()==rule['match'].lower():
                        key=(proc,rule['match']);self.replacement_counts[key]=self.replacement_counts.get(key,0)+1
                        if label:lines.append(label+' anop')
                        lines += [' '+instruction for instruction in rule['replace']]
                        replaced=True;break
                if replaced:continue
                if op == '.byte':
                    values=[numeric(part.strip(),self.values) for part in operand.split(',')]
                    if not values or any(v < -128 or v > 255 for v in values):raise ValueError('Selected inline byte table out of range')
                    lines.append(label+" dc i1'"+','.join(str(v) for v in values)+"'")
                    continue
                if op not in OPS:raise ValueError('Unsupported selected syntax: '+code)
                for hook in self.manifest.get('instruction_hooks',{}).get(proc,[]):
                    if (op+' '+operand).lower()==hook['match']:
                        key=(proc,hook['match']);self.hook_counts[key]=self.hook_counts.get(key,0)+1
                        lines += [' '+instruction for instruction in hook['before']]
                if op in ('asl','lsr','rol','ror') and not operand:operand='a'
                if operand.lower()=='a':value='a'
                else:
                    # Addressing punctuation is retained; names are scoped first.
                    index='';match=re.search(r',\s*([xy])$',operand,re.I)
                    if match:operand=operand[:match.start()].strip();index=','+match[1].lower()
                    if operand.startswith('(') and operand.endswith(')'):
                        value='('+self.expression(operand[1:-1],scope,proc)+')'+index
                    else:value=self.expression(operand,scope,proc)+index
                if op == 'sta' and index == ',y' and operand in self.dp:
                    # 6502 absolute,Y into ZP must follow relocated native D.
                    # STA preserves flags; swapping the index must preserve them too.
                    lines += [label+' php',' phx',' tyx',' sta '+self.expression(operand,scope,proc)+',x',' plx',' plp']
                    continue
                if op in BRANCHES:
                    self.branch+=1;skip=f'native_branch_{self.branch}'
                    lines += [f'{label} {BRANCHES[op]} {skip}',f' jmp {value}',skip+' anop']
                else:lines.append(f'{label} {op} {value}'.rstrip())
            except ValueError as error:raise ValueError(f'{path}:{lineno}: {error}') from error
        for proc,hooks in self.manifest.get('instruction_hooks',{}).items():
            for hook in hooks:
                if self.hook_counts.get((proc,hook['match']),0)!=hook['count']:
                    raise ValueError('Audited instruction hook did not match exactly: '+proc+' '+hook['match'])
        for proc,rules in self.manifest.get('instruction_replacements',{}).items():
            for rule in rules:
                if self.replacement_counts.get((proc,rule['match']),0)!=rule['count']:
                    raise ValueError('Audited instruction replacement did not match exactly: '+proc+' '+rule['match'])
        return '\n'.join(lines)+'\n'
