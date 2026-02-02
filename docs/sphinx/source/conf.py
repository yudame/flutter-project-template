# Sphinx configuration for Flutter Project Template

project = 'Flutter Project Template'
copyright = '2025, yudame'
author = 'yudame'
release = '0.1.0'

# Extensions
extensions = [
    'myst_parser',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# HTML output
html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']
html_css_files = ['css/custom.css']

# MyST settings (Markdown support)
myst_enable_extensions = [
    "colon_fence",
    "deflist",
    "html_admonition",
    "html_image",
    "linkify",
    "smartquotes",
    "tasklist",
]

myst_heading_anchors = 3

# Source file suffixes
source_suffix = {
    '.rst': 'restructuredtext',
    '.md': 'markdown',
}
