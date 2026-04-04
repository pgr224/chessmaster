import os
import re

def find_unmatched_braces(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # We'll just look for '${' followed by no '}' before a quote
                # Or we can just print any line containing '${' that doesn't contain '}'
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if '${' in line and '}' not in line:
                        # multi-line interpolations exist, but let's see
                        print(f"Possible unmatched brace in {path}:{i+1}: {line.strip()}")

find_unmatched_braces('lib')
