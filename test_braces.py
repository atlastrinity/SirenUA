import re
with open('ContentViewV4.swift') as f:
    text = f.read()

# remove string literals
text = re.sub(r'".*?"', '""', text)
# remove single line comments
text = re.sub(r'//.*', '', text)
# remove multi line comments
text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)

lines = text.split('\n')
with open('ContentViewV4.swift') as f:
    orig_lines = f.read().split('\n')

depth = 0
for i, line in enumerate(lines):
    old_depth = depth
    depth += line.count('{')
    depth -= line.count('}')
    print(f"{i+1:3} [{old_depth:2} -> {depth:2}] {orig_lines[i]}")
