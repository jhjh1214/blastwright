#!/usr/bin/env python3
"""Static UI QA for the client code (no Roblox needed). Run from the project root:

    python tools/lint/ui_qa.py

It cannot replace looking at the game on real screen sizes, but it catches the classes of UI mistake that are easy to make
in code and hard to spot by eye:

  ERROR   placeholder text or ids left in (TODO, PLACEHOLDER, IMAGE_ID_HERE, lorem, rbxassetid://0)
  ERROR   a Kit.Button / Kit.SideButton / Kit.ActionButton built without an OnClick handler
  ERROR   a hand-written rbxassetid:// id outside the files that are allowed to hold asset ids
  ERROR   a ZIndex written as a bare number of 100 or more (use Theme.Z layers) or a negative one
  WARN    a button smaller than 40 px in either direction (touch targets)
  WARN    a frame or label with a fixed pixel width over 640 (may not fit a phone in portrait)
  WARN    a font outside the design system's families (FredokaOne display, BuilderSans body)

Exit code 1 when there are errors (warnings never fail the run).
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
CLIENT = os.path.join(ROOT, "src", "StarterPlayer", "StarterPlayerScripts", "Client")
ASSET_ID_FILES = {"Icons.luau", "ShopArt.luau", "AudioManager.luau"}  # the only places that may hold asset ids
PLACEHOLDER = re.compile(r"TODO|PLACEHOLDER|IMAGE_ID|lorem ipsum|rbxassetid://0\b", re.I)
ASSET_ID = re.compile(r"rbxassetid://\d+")
BUTTON_CALL = re.compile(r"(?<!function )Kit\.(Button|SideButton|ActionButton)\(")
ZINDEX_BARE = re.compile(r"ZIndex\s*=\s*(-?\d+)\b")
OFFSET_SIZE = re.compile(r"Size\s*=\s*UDim2\.fromOffset\((\d+)\s*,\s*(\d+)\)")
FONT_ENUM = re.compile(r"Enum\.Font\.(?!(?:FredokaOne|BuilderSans|BuilderSansBold|BuilderSansMedium)\b)\w+")


def logical_calls(text, start_pattern):
    """Yield (line_number, call_text) for each call whose parentheses balance, across lines."""
    for m in start_pattern.finditer(text):
        depth, i = 1, m.end()
        while i < len(text) and depth:
            depth += {"(": 1, ")": -1}.get(text[i], 0)
            i += 1
        yield text.count("\n", 0, m.start()) + 1, text[m.start():i]


def main():
    errors, warns = [], []
    files = []
    for folder, _dirs, names in os.walk(CLIENT):
        for n in names:
            if n.endswith(".luau"):
                files.append(os.path.relpath(os.path.join(folder, n), CLIENT))
    for name in sorted(files):
        path = os.path.join(CLIENT, name)
        text = open(path, encoding="utf8").read()
        lines = text.split("\n")
        for n, line in enumerate(lines, 1):
            code = line.split("--", 1)[0]
            if PLACEHOLDER.search(code):
                errors.append(f"{name}:{n}: placeholder text or id: {line.strip()[:90]}")
            if os.path.basename(name) not in ASSET_ID_FILES and ASSET_ID.search(code):
                errors.append(f"{name}:{n}: asset id outside Icons/ShopArt/AudioManager: {line.strip()[:90]}")
            m = ZINDEX_BARE.search(code)
            if m and (int(m.group(1)) >= 100 or int(m.group(1)) < 0):
                errors.append(f"{name}:{n}: ZIndex {m.group(1)} is outside the layer scheme (use Theme.Z): {line.strip()[:80]}")
            for m in OFFSET_SIZE.finditer(code):
                w, h = int(m.group(1)), int(m.group(2))
                if w > 640 and "UISizeConstraint" not in code and "Modal" not in code and "Rays" not in code and "rays" not in line:
                    warns.append(f"{name}:{n}: fixed width {w}px (check it fits a phone): {line.strip()[:70]}")
            if name != "Theme.luau" and FONT_ENUM.search(code):
                warns.append(f"{name}:{n}: font written directly, not part of the design system fonts: {FONT_ENUM.search(code).group(0)}")
        for n, call in logical_calls(text, BUTTON_CALL):
            if "OnClick" not in call:
                # a button whose click is wired afterwards (b.Activated) is common in list rows: only flag Kit buttons with no wiring nearby
                tail = "\n".join(lines[n - 1:n + 12])
                if "Activated" not in tail and "MouseButton1Click" not in tail and "OnClick" not in tail:
                    errors.append(f"{name}:{n}: Kit button with no OnClick and no Activated handler nearby")
            m = OFFSET_SIZE.search(call)
            if m and (int(m.group(1)) < 40 or int(m.group(2)) < 40) and "Visible = false" not in call:
                warns.append(f"{name}:{n}: small touch target {m.group(1)}x{m.group(2)}")
    for w in warns:
        print("WARN  " + w)
    for e in errors:
        print("ERROR " + e)
    print(f"\n{len(errors)} error(s), {len(warns)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
