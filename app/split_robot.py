import os

file_path = 'lib/presentation/widgets/reacting_robot_widget.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# The avatar starts around line 368: "  Widget _buildRobotAvatar() {"
# We search for "  // ═══════════════════════════════════════════════" 
# followed by "  // ROBOT AVATAR — Full animated body"
header_avatar = "  // ═══════════════════════════════════════════════\n  // ROBOT AVATAR — Full animated body\n"

avatar_start = 0
quote_start = 0
dots_start = 0

for i, line in enumerate(lines):
    if "ROBOT AVATAR — Full animated body" in line:
        avatar_start = i - 1
    if "QUOTE BUBBLE" in line:
        quote_start = i - 1
    if "class _AnimatedDots" in line:
        dots_start = i

part_animator = ["part of 'reacting_robot_widget.dart';\n\n", "extension ReactingRobotAnimator on _ReactingRobotWidgetState {\n"]
part_bubble = ["part of 'reacting_robot_widget.dart';\n\n", "extension ReactingRobotBubble on _ReactingRobotWidgetState {\n"]

for i in range(avatar_start, quote_start):
    part_animator.append(lines[i])
part_animator.append("}\n")

for i in range(quote_start, dots_start):
    part_bubble.append(lines[i])
part_bubble.append("}\n\n")

for i in range(dots_start, len(lines)):
    part_bubble.append(lines[i])

with open('lib/presentation/widgets/reacting_robot_animator.dart', 'w', encoding='utf-8') as f:
    f.writelines(part_animator)

with open('lib/presentation/widgets/reacting_robot_bubble.dart', 'w', encoding='utf-8') as f:
    f.writelines(part_bubble)

# update main widget
new_main = lines[:avatar_start]

# inject part directives right after imports
imports_end = 0
for i, line in enumerate(new_main):
    if line.startswith('// ═══════════════════════════════════════════════════'):
        imports_end = i
        break

new_main.insert(imports_end, "part 'reacting_robot_animator.dart';\npart 'reacting_robot_bubble.dart';\n\n")

# Write new file
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_main)
print(f"avatar_start: {avatar_start}, quote_start: {quote_start}, dots_start: {dots_start}")
