"""Checked assembly-template edits, independent of horizontal column spacing.

Keep labels in column zero, quoted data and line boundaries significant. These
helpers only edit generated copies; they never reformat the source files.
"""
import re


def _pattern(anchor):
    # Quoted operands are literal (including their spaces). Only horizontal
    # whitespace outside strings is flexible; never let a match cross a line.
    parts = re.findall(r"'[^'\n]*'|\"[^\"\n]*\"|[ \t]+|\n|[^ \t\n'\"]+|['\"]", anchor)
    expression = ''.join('[ \\t]+' if part[0] in ' \t' else r'[ \t]*\n' if part == '\n' else re.escape(part)
                         for part in parts)
    return re.compile(r'^' + expression + (r'(?=[ \t\n;]|$)' if not anchor[-1].isspace() else ''), re.M)


def find_once(text, anchor):
    matches = list(_pattern(anchor).finditer(text))
    if len(matches) != 1:
        raise RuntimeError(f'Assembly anchor expected once, found {len(matches)}: {anchor!r}')
    return matches[0]


def replace_once(text, old, new):
    match = find_once(text, old)
    return text[:match.start()] + new + text[match.end():]


def replace_all(text, old, new, *, expected):
    pattern = _pattern(old)
    matches = list(pattern.finditer(text))
    if len(matches) != expected:
        raise RuntimeError(f'Assembly anchor expected {expected} times, found {len(matches)}: {old!r}')
    return pattern.sub(lambda match: new, text)


def label_offset(text, label):
    return find_once(text, label + ' ').start()
