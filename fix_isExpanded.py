import re

with open('Sources/NotchBox/ContentView.swift', 'r') as f:
    content = f.read()

# First, remove the declaration line: "@State private var isExpanded = false"
content = re.sub(r'\s*@State private var isExpanded = false\n', '\n', content)

# Then, replace all other occurrences of "isExpanded" with "islandManager.isExpanded"
# Be careful not to replace it if it's already "islandManager.isExpanded"
content = re.sub(r'(?<!islandManager\.)isExpanded', 'islandManager.isExpanded', content)

with open('Sources/NotchBox/ContentView.swift', 'w') as f:
    f.write(content)

