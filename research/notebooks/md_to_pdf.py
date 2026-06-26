#!/usr/bin/env python3
"""Convert implementation_plan.md to a professional PDF."""
import markdown
import os

MD_PATH = './implementation_plan.md'
OUT_DIR = './research'

with open(MD_PATH, 'r') as f:
    md_text = f.read()

# Convert GitHub-flavored alerts to styled HTML
import re
md_text = re.sub(r'> \[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\n>', lambda m: f'<div class="alert alert-{m.group(1).lower()}"><strong>{m.group(1)}:</strong>', md_text)
# Close unclosed alert divs (simplistic)
md_text = md_text.replace('\n\n---', '</div>\n\n---')

html_body = markdown.markdown(md_text, extensions=['tables', 'fenced_code', 'codehilite'])

html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
@page {{
    size: A4;
    margin: 2cm;
}}
body {{
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    font-size: 11pt;
    line-height: 1.5;
    color: #222;
    max-width: 190mm;
    margin: 0 auto;
}}
h1 {{
    font-size: 18pt;
    color: #1a237e;
    border-bottom: 3px solid #1a237e;
    padding-bottom: 8px;
    margin-top: 0;
}}
h2 {{
    font-size: 14pt;
    color: #283593;
    border-bottom: 1px solid #c5cae9;
    padding-bottom: 4px;
    margin-top: 24px;
}}
h3 {{
    font-size: 12pt;
    color: #3949ab;
    margin-top: 16px;
}}
table {{
    border-collapse: collapse;
    width: 100%;
    margin: 12px 0;
    font-size: 10pt;
}}
th, td {{
    border: 1px solid #c5cae9;
    padding: 6px 10px;
    text-align: left;
}}
th {{
    background-color: #e8eaf6;
    font-weight: bold;
    color: #1a237e;
}}
tr:nth-child(even) {{
    background-color: #f5f5f5;
}}
code {{
    background-color: #f5f5f5;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 10pt;
    font-family: 'Consolas', 'Courier New', monospace;
}}
pre {{
    background-color: #263238;
    color: #eeffff;
    padding: 12px;
    border-radius: 6px;
    font-size: 9pt;
    overflow-x: auto;
}}
pre code {{
    background: none;
    color: inherit;
    padding: 0;
}}
blockquote {{
    border-left: 4px solid #42a5f5;
    margin: 16px 0;
    padding: 8px 16px;
    background-color: #e3f2fd;
    font-style: italic;
}}
.alert {{
    border-left: 4px solid #ff9800;
    margin: 12px 0;
    padding: 8px 16px;
    background-color: #fff3e0;
    border-radius: 4px;
}}
.alert-important {{
    border-color: #f44336;
    background-color: #ffebee;
}}
.alert-warning {{
    border-color: #ff9800;
    background-color: #fff3e0;
}}
.alert-note {{
    border-color: #2196f3;
    background-color: #e3f2fd;
}}
hr {{
    border: none;
    border-top: 2px solid #e0e0e0;
    margin: 24px 0;
}}
strong {{
    color: #1a237e;
}}
</style>
</head>
<body>
{html_body}
</body>
</html>"""

# Save HTML first
html_path = os.path.join(OUT_DIR, 'implementation_plan.html')
with open(html_path, 'w') as f:
    f.write(html)
print(f"HTML saved: {html_path}")

# Try weasyprint for PDF
try:
    from weasyprint import HTML
    pdf_path = os.path.join(OUT_DIR, 'implementation_plan.pdf')
    HTML(string=html).write_pdf(pdf_path)
    print(f"PDF saved: {pdf_path}")
except Exception as e:
    print(f"WeasyPrint failed: {e}")
    # Fallback: try wkhtmltopdf
    import subprocess
    try:
        pdf_path = os.path.join(OUT_DIR, 'implementation_plan.pdf')
        subprocess.run(['wkhtmltopdf', '--quiet', '--page-size', 'A4',
                        '--margin-top', '20', '--margin-bottom', '20',
                        '--margin-left', '20', '--margin-right', '20',
                        html_path, pdf_path], check=True)
        print(f"PDF saved (wkhtmltopdf): {pdf_path}")
    except Exception as e2:
        print(f"wkhtmltopdf also failed: {e2}")
        print(f"HTML is available at: {html_path}")
        print("Open it in a browser and print to PDF (Ctrl+P)")
