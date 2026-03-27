import os
import re

def fix_with_values(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace withValues(alpha: X) with withOpacity(X)
                # Using regex to handle various spacing
                new_content = re.sub(r'\.withValues\s*\(\s*alpha\s*:\s*([^)]+)\)', r'.withOpacity(\1)', content)
                
                if content != new_content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Fixed {path}")

if __name__ == "__main__":
    fix_with_values('d:/PP942920DRIVE/PROJECTS/chess/app/lib')
