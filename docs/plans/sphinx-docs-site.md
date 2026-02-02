# Plan: Sphinx Documentation Site

## Goal

Add a published documentation site to this Flutter template repo, matching the pattern used in [django-project-template](https://github.com/yudame/django-project-template). Auto-built and deployed to GitHub Pages on every push to main.

## Current State

- 3 Markdown docs: `architecture.md` (665 lines), `implemented.md` (816 lines), `setup_reference.md` (753 lines)
- `README.md` (242 lines)
- No CI/CD, no `.github/` directory, no docs site

## Approach

Use **Sphinx + myst_parser** so our existing Markdown files are used directly — no need to rewrite anything in RST. Only the index/toctree files will be RST.

Since this is a docs-only template (no Dart source code), we skip autodoc/apidoc entirely. Much simpler than the Django setup.

---

## Files to Create

### 1. `docs/sphinx/source/conf.py`
Sphinx configuration:
- Theme: `sphinx_rtd_theme`
- Extensions: `myst_parser` only (no autodoc — no source code to document)
- MyST extensions: colon_fence, deflist, tasklist, smartquotes, linkify
- Project: "Flutter Project Template"
- Pull in custom CSS

### 2. `docs/sphinx/source/index.rst`
Main toctree pointing to our existing Markdown files:
```
Flutter Project Template
========================

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   overview
   implemented
   architecture
   setup_reference

Indices and tables
==================
* :ref:`search`
```

### 3. `docs/sphinx/source/overview.md`
New file — brief intro page covering:
- What this template is (docs-only Flutter architecture reference)
- Who it's for (small teams 2-5 people using AI-assisted development)
- How to use it (copy patterns into your project)
- Links to each section

### 4. Symlinks or copies for existing docs
Symlink `docs/sphinx/source/implemented.md` → `../../implemented.md` (and same for architecture.md, setup_reference.md) so content lives in one place. If symlinks cause CI issues, the build script will copy them instead.

### 5. `docs/sphinx/source/_static/css/custom.css`
Light custom theming (color variables, code block styling). Match the Django template's approach but with Flutter-appropriate colors (blue/cyan).

### 6. `docs/sphinx/Makefile`
Standard Sphinx Makefile with targets:
- `make html` — build
- `make clean` — clean build dir
- `make preview` — build and open in browser

### 7. `docs/scripts/build_docs.sh`
Local build script:
- Ensure pip deps installed (sphinx, sphinx-rtd-theme, myst-parser, linkify-it-py)
- Copy/symlink markdown files into source dir
- Run `sphinx-build -b html source build/html`
- Print success message with path

### 8. `docs/scripts/build_docs_ci.sh`
CI build script (simpler than Django's — no runtime dependency):
- Install deps
- Copy markdown files into sphinx source dir
- Build HTML
- Verify output exists

### 9. `.github/workflows/docs.yml`
GitHub Actions workflow:
- **Trigger**: push to main (paths: `docs/**`, `.github/workflows/docs*.yml`), PRs to main, manual dispatch
- **Build job**: checkout → setup Python 3.12 → install Sphinx deps → run `build_docs_ci.sh` → upload artifact
- **Deploy job**: deploy to GitHub Pages (main branch only)
- Same permissions/concurrency pattern as Django template

### 10. `.gitignore` update
Add `docs/sphinx/build/` to gitignore.

---

## What We're NOT Doing

- **No autodoc/apidoc** — no Dart source code in this repo
- **No complex CI fallback script** — Django needed 419 lines because it has a runtime dependency. We don't.
- **No RST rewrites** — myst_parser lets Sphinx consume our existing Markdown directly
- **No content changes** — existing docs stay as-is. We're just wrapping them in a site.

## Structure After Implementation

```
flutter-project-template/
├── .github/
│   └── workflows/
│       └── docs.yml
├── docs/
│   ├── architecture.md          # (unchanged)
│   ├── implemented.md           # (unchanged)
│   ├── setup_reference.md       # (unchanged)
│   ├── plans/
│   ├── scripts/
│   │   ├── build_docs.sh        # Local build
│   │   └── build_docs_ci.sh     # CI build
│   └── sphinx/
│       ├── Makefile
│       ├── source/
│       │   ├── conf.py
│       │   ├── index.rst
│       │   ├── overview.md       # New intro page
│       │   ├── _static/
│       │   │   └── css/
│       │   │       └── custom.css
│       │   └── (symlinks or copies of *.md at build time)
│       └── build/                # (gitignored)
└── ...
```

## Estimated Work

~10 files, all config/scaffolding. No content authoring needed. Should take one focused session.
