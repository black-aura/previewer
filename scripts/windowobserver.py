import argparse
import os
import re
import html
import atomacos
from PIL import ImageGrab

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

parser = argparse.ArgumentParser()
parser.add_argument('window', help='Substring of the plugin window title, e.g. "Mini V4"')
parser.add_argument('output', help='Output directory name, created under ui-elements/')
args = parser.parse_args()

OUT_DIR = os.path.join(SCRIPT_DIR, 'ui-elements', args.output)
IMG_DIR = os.path.join(OUT_DIR, 'img')
os.makedirs(IMG_DIR, exist_ok=True)

atomacos.launchAppByBundleId('com.ableton.Live')
live = atomacos.getAppRefByLocalizedName('Live')
windows = live.windows()
window = [w for w in windows if args.window in w.AXTitle][0]

counter = [0]

def safe_name(s):
    return re.sub(r'[^\w\-]', '_', str(s or ''))[:40]


def build_node(el, path_label='root'):
    attrs = {}
    try:
        ax_attr_names = el.ax_attributes
    except Exception:
        ax_attr_names = []
    for attr in ax_attr_names:
        try:
            attrs[attr] = getattr(el, attr)
        except Exception:
            attrs[attr] = None

    screenshot_filename = None
    frame = attrs.get('AXFrame')
    if frame:
        x, y = int(frame.x), int(frame.y)
        w, h = int(frame.width), int(frame.height)
        if w > 0 and h > 0:
            role = safe_name(attrs.get('AXRole'))
            label = safe_name(attrs.get('AXTitle') or attrs.get('AXDescription') or attrs.get('AXValue'))
            idx = counter[0]
            counter[0] += 1
            filename = f"{idx:04d}_{path_label}_{role}_{label}.png".replace('/', '_')
            filepath = os.path.join(IMG_DIR, filename)
            try:
                img = ImageGrab.grab(bbox=(x, y, x + w, y + h))
                img.save(filepath)
                screenshot_filename = filename
                print(f"  saved: {filename}  ({w}x{h})")
            except Exception as e:
                print(f"  skip {filename}: {e}")

    actions = None
    try:
        actions = el.getActions()
    except Exception:
        pass

    try:
        children = attrs.get('AXChildren') or []
    except Exception:
        children = []
    role = safe_name(attrs.get('AXRole'))
    label = safe_name(attrs.get('AXTitle') or attrs.get('AXDescription') or '')
    child_label = f"{path_label}_{role}_{label}"[:60]

    child_nodes = [build_node(child, child_label) for child in children]

    return {
        'attrs': attrs,
        'actions': actions,
        'screenshot': screenshot_filename,
        'children': child_nodes,
    }


def child_desc_path(parent_ax_path, child_attrs, child_idx):
    """Build a by-description accessor for a child, falling back to index."""
    child_title = child_attrs.get('AXTitle') or child_attrs.get('AXDescription') or ''
    base = f'{parent_ax_path}.AXChildren'
    if child_title:
        field = 'AXTitle' if child_attrs.get('AXTitle') else 'AXDescription'
        return f"[c for c in {base} if '{child_title}' in (getattr(c, '{field}', '') or '')][0]"
    return f'{base}[{child_idx}]'


def copy_btn(path):
    escaped = html.escape(path, quote=True)
    return (f'<button class="copy" data-path="{escaped}"'
            f' onclick="event.stopPropagation();navigator.clipboard.writeText(this.dataset.path);'
            f"this.textContent='✓';setTimeout(()=>this.textContent='⧉',1000)\""
            f' title="Copy path">⧉</button>')


def render_html(node, index_path=(), ax_path='window'):
    attrs = node['attrs']
    actions = node['actions']
    screenshot = node['screenshot']
    children = node['children']

    role = attrs.get('AXRole') or ''
    title = attrs.get('AXTitle') or attrs.get('AXDescription') or attrs.get('AXValue') or ''
    summary_text = html.escape(f"{role}  {title}".strip())

    path_str = 'window' + ''.join(f'.AXChildren[{i}]' for i in index_path)

    lines = ['<details open>']
    lines.append(f'  <summary><strong>{summary_text or "(element)"}</strong>'
                 f'  <span class="path">{html.escape(path_str)}'
                 f'{copy_btn(path_str)}'
                 f'</span></summary>')
    lines.append('  <div class="node">')

    # screenshot
    if screenshot:
        img_ref = html.escape('img/' + screenshot)
        lines.append(f'    <a href="{img_ref}" target="_blank">')
        lines.append(f'      <img src="{img_ref}" class="thumb">')
        lines.append('    </a>')

    # attribute table — index path + desc path as first rows
    lines.append('    <table>')
    lines.append(f'      <tr><td class="k">index_path</td>'
                 f'<td class="v">{html.escape(path_str)}{copy_btn(path_str)}</td></tr>')
    lines.append(f'      <tr><td class="k">desc_path</td>'
                 f'<td class="v">{html.escape(ax_path)}{copy_btn(ax_path)}</td></tr>')
    if actions:
        lines.append(f'      <tr><td class="k">actions</td>'
                     f'<td class="v">{html.escape(", ".join(actions))}</td></tr>')
    skip = {'AXChildren', 'AXChildrenInNavigationOrder'}
    for k, v in sorted(attrs.items()):
        if k in skip or v is None:
            continue
        lines.append(
            f'      <tr><td class="k">{html.escape(k)}</td>'
            f'<td class="v">{html.escape(str(v))}</td></tr>'
        )
    lines.append('    </table>')

    # children
    if children:
        lines.append('    <div class="children">')
        for i, child in enumerate(children):
            child_ax = child_desc_path(ax_path, child['attrs'], i)
            lines.append(render_html(child, index_path + (i,), child_ax))
        lines.append('    </div>')

    lines.append('  </div>')
    lines.append('</details>')
    return '\n'.join(lines)


CSS = """
body { font-family: monospace; font-size: 12px; background: #1a1a1a; color: #ddd; padding: 16px; }
details { margin: 4px 0 4px 16px; border-left: 1px solid #444; padding-left: 8px; }
summary { cursor: pointer; padding: 2px 4px; border-radius: 3px; }
summary:hover { background: #333; }
.node { margin: 6px 0 6px 8px; }
.thumb { max-width: 320px; max-height: 200px; border: 1px solid #555; margin: 4px 0; display: block; }
table { border-collapse: collapse; margin: 4px 0; }
td { padding: 1px 8px; vertical-align: top; }
td.k { color: #7ec8e3; white-space: nowrap; }
td.v { color: #c3e88d; word-break: break-all; }
tr:nth-child(even) { background: #232323; }
.children { margin-left: 8px; }
.path { color: #888; font-weight: normal; margin-left: 10px; font-size: 11px; }
.copy { background: none; border: 1px solid #555; border-radius: 3px; color: #888; cursor: pointer; font-size: 11px; margin-left: 6px; padding: 0 4px; vertical-align: middle; }
.copy:hover { border-color: #aaa; color: #ddd; }
"""

print(f"Saving screenshots to: {IMG_DIR}")
tree = build_node(window)
print(f"Done. {counter[0]} screenshots saved.")

html_path = os.path.join(OUT_DIR, 'report.html')
body = render_html(tree)
title = html.escape(args.window)
with open(html_path, 'w', encoding='utf-8') as f:
    f.write(f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>{title} UI Structure</title>
<style>{CSS}</style>
</head>
<body>
<h2>{title} — Window Structure</h2>
{body}
</body>
</html>
""")
print(f"Report: {html_path}")
