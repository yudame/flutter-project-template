# Plan: Sphinx Documentation Site

**Tracking**: https://github.com/yudame/flutter-project-template/issues/10

## Goal

Add a published documentation site to this Flutter template repo, matching the pattern used in [django-project-template](https://github.com/yudame/django-project-template). Auto-built and deployed to GitHub Pages on every push to main.

## Current State

- 7 Markdown docs in `docs/`:
  - `architecture.md` — Reference guidelines + planned features
  - `implemented.md` — Documentation for already-built features
  - `setup_reference.md` — Environment setup and critical patterns
  - `database.md` — Database layer patterns (NEW)
  - `localization.md` — i18n guide (NEW)
  - `analytics.md` — Analytics patterns (NEW)
  - `testing.md` — Testing philosophy and patterns (NEW)
- 7 plan docs in `docs/plans/`
- `README.md` with scaffolding section
- No CI/CD workflows yet
- No `.github/` directory
- No docs site

## Approach

Use **Sphinx + myst_parser** so our existing Markdown files are used directly — no need to rewrite anything in RST. Only the index/toctree files will be RST.

Since this is a docs-only template (no Dart source code to document), we skip autodoc/apidoc entirely. Much simpler than the Django setup.

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
```rst
Flutter Project Template
========================

.. toctree::
   :maxdepth: 2
   :caption: Getting Started

   overview
   setup_reference

.. toctree::
   :maxdepth: 2
   :caption: Architecture

   architecture
   implemented

.. toctree::
   :maxdepth: 2
   :caption: Core Systems

   database
   localization
   analytics
   testing

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
At build time, copy/symlink these files into `docs/sphinx/source/`:
- `architecture.md`
- `implemented.md`
- `setup_reference.md`
- `database.md`
- `localization.md`
- `analytics.md`
- `testing.md`

Use copies in the build script (symlinks can cause issues in CI).

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
- Copy markdown files into source dir
- Run `sphinx-build -b html source build/html`
- Print success message with path

### 8. `docs/scripts/build_docs_ci.sh`
CI build script:
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
- **No plans in the docs site** — keep plans internal, not published

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
│   ├── database.md              # (unchanged)
│   ├── localization.md          # (unchanged)
│   ├── analytics.md             # (unchanged)
│   ├── testing.md               # (unchanged)
│   ├── plans/                   # (unchanged, not in docs site)
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
│       │   └── (copies of *.md at build time)
│       └── build/                # (gitignored)
└── ...
```

## Estimated Work

~10 files, all config/scaffolding. No content authoring needed (except `overview.md`). Should take one focused session.
