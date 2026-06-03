#!/usr/bin/env python3
"""
build_site.py — Static documentation site generator for nbbbenuts.

Parses man/*.Rd and vignettes/*.Rmd, generates a self-contained HTML site
in docs_build/site/ that can be served locally with Python's HTTP server.

Usage:
    python3 docs_build/build_site.py          # build
    python3 docs_build/build_site.py --serve  # build + serve on port 8080
"""

import re
import sys
import html
import shutil
import pathlib
import textwrap
import markdown as md
from jinja2 import Environment, BaseLoader

ROOT    = pathlib.Path(__file__).parent.parent
MANDIR  = ROOT / "man"
VIGDIR  = ROOT / "vignettes"
OUTDIR  = pathlib.Path(__file__).parent / "site"

# ── Colour palette ─────────────────────────────────────────────────────────────
BLUE      = "#003A80"
BLUE_LIGHT= "#005BB5"
GOLD      = "#F0A500"
RED_CODE  = "#C0392B"
BG_CODE   = "#f4f7fb"

# ── Reference index: section → [function names] ────────────────────────────────
REFERENCE = [
    ("Données de référence", [
        "load_master_data", "rebuild_master_data",
        "rc_communes_2019", "rc_communes_2025",
        "rc_arrondissements_2019", "rc_nuts3_2021", "rc_postal",
    ]),
    ("Identifiants de classification", [
        "classification_reference",
        "get_all_classification_nodes", "get_conversion_matrix",
        "list_available_conversions",
        "check_conversion_path", "print_conversion_check",
    ]),
    ("Conversion de codes", [
        "convert_codes", "convert_dataset",
    ]),
    ("Lookup et validation", [
        "validate_codes", "get_label", "get_crosswalk",
    ]),
    ("Conversions ambiguës (M:N)", [
        "split_ambiguous", "split_weights_template",
        "register_split_weights", "get_split_weights",
        "list_split_weights", "clear_split_weights",
    ]),
    ("Rebasement longitudinal", [
        "rebase_series",
    ]),
    ("Diagnostic et détection", [
        "diagnose_classification", "detect_classification",
        "fuzzy_match_names", "identify_from_names",
    ]),
    ("Visualisation", [
        "visualize_classification_graph",
        "visualize_conversion_matrix", "visualize_hierarchy",
    ]),
]

ARTICLES = [
    ("introduction",     "Getting started"),
    ("conversions",      "Conversions géographiques"),
    ("ambiguous-splits", "Conversions ambiguës"),
    ("diagnostics",      "Diagnostic et détection"),
]


# ── Rd parser ──────────────────────────────────────────────────────────────────

def rd_tag(text, tag):
    """Extract content of \\tag{...} from Rd source (handles one level of nesting)."""
    pattern = rf"\\{re.escape(tag)}\{{"
    pos = text.find(f"\\{tag}{{")
    if pos == -1:
        return ""
    depth, start = 0, pos + len(tag) + 2
    for i, ch in enumerate(text[pos + len(tag) + 1:], pos + len(tag) + 1):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start:i].strip()
    return ""


def rd_all_tags(text, tag):
    """Extract all \\tag{...} occurrences."""
    results, pos = [], 0
    while True:
        pos = text.find(f"\\{tag}{{", pos)
        if pos == -1:
            break
        depth, start = 0, pos + len(tag) + 2
        for i, ch in enumerate(text[pos + len(tag) + 1:], pos + len(tag) + 1):
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    results.append(text[start:i].strip())
                    pos = i + 1
                    break
        else:
            break
    return results


def rd_to_html(text):
    """Very light Rd → HTML converter."""
    # Strip comments
    text = re.sub(r"%.*", "", text)
    # \code{x} → <code>x</code>
    text = re.sub(r"\\code\{([^}]*)\}", lambda m: f"<code>{html.escape(m.group(1))}</code>", text)
    # \link[pkg]{x} or \link{x} → just the label
    text = re.sub(r"\\link(?:\[[^\]]*\])?\{([^}]*)\}", r'<a href="reference/\1.html">\1</a>', text)
    # \emph{x} → <em>x</em>
    text = re.sub(r"\\emph\{([^}]*)\}", r"<em>\1</em>", text)
    # \strong{x} → <strong>x</strong>
    text = re.sub(r"\\strong\{([^}]*)\}", r"<strong>\1</strong>", text)
    # \pkg{x} → <strong>x</strong>
    text = re.sub(r"\\pkg\{([^}]*)\}", r"<strong>\1</strong>", text)
    # \url{x} → <a href>
    text = re.sub(r"\\url\{([^}]*)\}", r'<a href="\1">\1</a>', text)
    # \donttest{...} / \dontrun{...} → keep content, strip wrapper
    text = re.sub(r"\\dont(?:test|run)\{([\s\S]*?)\}", r"\1", text)
    # \if / \ifelse
    text = re.sub(r"\\ifelse\{[^}]*\}\{[^}]*\}\{([^}]*)\}", r"\1", text)
    # \cr → <br>
    text = text.replace("\\cr", "<br>")
    # \n paragraphs
    text = re.sub(r"\n{2,}", "</p><p>", text)
    # Remaining backslash-commands: strip
    text = re.sub(r"\\[a-zA-Z]+\{([^}]*)\}", r"\1", text)
    text = re.sub(r"\\[a-zA-Z]+", "", text)
    # Braces
    text = text.replace("{", "").replace("}", "")
    return f"<p>{text.strip()}</p>"


def parse_rd(path):
    """Parse a .Rd file into a dict of key→html-string sections."""
    src = path.read_text(encoding="utf-8")

    def get(tag):
        return rd_to_html(rd_tag(src, tag))

    def get_raw(tag):
        return rd_tag(src, tag).strip()

    name  = get_raw("name")
    alias = rd_all_tags(src, "alias")
    title = get_raw("title")
    desc  = get("description")
    detl  = get("details") if "\\details{" in src else ""
    val   = get("value") if "\\value{" in src else ""

    # Usage block
    usage_raw = rd_tag(src, "usage")
    usage = html.escape(usage_raw) if usage_raw else ""

    # Arguments
    args_block = rd_tag(src, "arguments")
    args = []
    if args_block:
        for m in re.finditer(r"\\item\{([^}]*)\}\{([\s\S]*?)(?=\\item\{|$)", args_block):
            aname = m.group(1).strip()
            adesc = rd_to_html(m.group(2).strip())
            args.append((aname, adesc))

    # Examples
    ex_raw = rd_tag(src, "examples")
    if ex_raw:
        ex_raw = re.sub(r"\\dont(?:test|run)\{([\s\S]*?)\}", r"\1", ex_raw)
        ex_raw = re.sub(r"\\[a-zA-Z]+\{([^}]*)\}", r"\1", ex_raw)
        ex_raw = ex_raw.replace("{", "").replace("}", "").strip()
        examples = html.escape(ex_raw)
    else:
        examples = ""

    return {
        "name": name,
        "aliases": alias,
        "title": title,
        "description": desc,
        "details": detl,
        "value": val,
        "usage": usage,
        "args": args,
        "examples": examples,
    }


# ── Rmd parser ─────────────────────────────────────────────────────────────────

def parse_rmd(path):
    """Extract title from YAML front matter and convert body to HTML."""
    src = path.read_text(encoding="utf-8")

    # Title
    m = re.search(r'^title:\s+"?([^"\n]+)"?', src, re.MULTILINE)
    title = m.group(1) if m else path.stem

    # Strip YAML front matter
    body = re.sub(r"^---\n.*?---\n", "", src, flags=re.DOTALL).strip()

    # Strip knitr chunk options
    body = re.sub(r"```\{r[^}]*\}", "```r", body)

    # Inline backtick code blocks stay as-is for markdown
    html_body = md.markdown(body, extensions=["fenced_code", "tables", "toc"])

    return {"title": title, "body": html_body}


# ── HTML templates ─────────────────────────────────────────────────────────────

BASE_CSS = f"""
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
body {{ font-family: system-ui, -apple-system, sans-serif; color: #212529;
        background: #fff; line-height: 1.65; }}
a {{ color: {BLUE}; text-decoration: none; }}
a:hover {{ text-decoration: underline; }}
code, pre {{ font-family: "SFMono-Regular", Consolas, monospace; }}
code {{ background: {BG_CODE}; border: 1px solid #d8e3f0; border-radius: .25em;
       padding: .1em .35em; font-size: .875em; color: {RED_CODE}; }}
pre {{ background: #1e2431; color: #abb2bf; padding: 1.1rem 1.4rem;
      border-radius: .45rem; overflow-x: auto; margin: 1.2rem 0; }}
pre code {{ background: none; border: none; color: inherit; padding: 0; font-size: .875rem; }}

/* Navbar */
nav {{ background: {BLUE}; padding: .7rem 2rem; display: flex;
      align-items: center; gap: 2rem; position: sticky; top:0; z-index:100;
      box-shadow: 0 2px 8px rgba(0,0,0,.2); }}
nav .brand {{ color:#fff; font-weight:700; font-size:1.1rem; letter-spacing:.04em; }}
nav a {{ color:rgba(255,255,255,.85); font-size:.9rem; }}
nav a:hover {{ color:#fff; text-decoration:none; }}
nav .search-box {{ margin-left:auto; }}
nav .search-box input {{
  border:none; border-radius:.25rem; padding:.3rem .75rem;
  font-size:.85rem; width:200px; }}

/* Layout */
.page {{ max-width:1200px; margin:0 auto; padding:2rem 1.5rem; }}

/* Sidebar */
.layout {{ display:flex; gap:2.5rem; }}
.sidebar {{ width:240px; flex-shrink:0; }}
.sidebar h4 {{ font-size:.78rem; text-transform:uppercase; letter-spacing:.08em;
               color:#6c757d; margin:1.2rem 0 .4rem; }}
.sidebar a {{ display:block; padding:.25rem .5rem; font-size:.875rem;
              border-radius:.25rem; color:#444; }}
.sidebar a:hover, .sidebar a.active {{
  background:{BG_CODE}; color:{BLUE}; font-weight:600; text-decoration:none; }}
.main-content {{ flex:1; min-width:0; }}

/* Hero (home) */
.hero {{ background:linear-gradient(135deg,{BLUE} 0%,{BLUE_LIGHT} 100%);
         color:#fff; padding:3rem 2.5rem; border-radius:.6rem; margin-bottom:2.5rem; }}
.hero h1 {{ font-size:2rem; font-weight:700; margin-bottom:.75rem; }}
.hero p {{ font-size:1.05rem; opacity:.9; margin-bottom:1.2rem; max-width:640px; }}
.hero a {{ color:{GOLD}; font-weight:600; }}

/* Cards (home) */
.cards {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(270px,1fr));
          gap:1.25rem; margin-bottom:2.5rem; }}
.card {{ border:1px solid #dee2e6; border-radius:.5rem; padding:1.25rem;
         transition:box-shadow .15s; }}
.card:hover {{ box-shadow:0 4px 16px rgba(0,58,128,.12); }}
.card h3 {{ font-size:1rem; color:{BLUE}; margin-bottom:.4rem; }}
.card p {{ font-size:.875rem; color:#555; }}

/* Reference */
.ref-section h2 {{ color:{BLUE}; border-bottom:2px solid {BLUE}; padding-bottom:.4rem;
                   margin:2rem 0 1rem; font-size:1.15rem; }}
.ref-table {{ width:100%; border-collapse:collapse; margin-bottom:1.5rem; }}
.ref-table td {{ padding:.45rem .75rem; border-bottom:1px solid #f0f0f0;
                 font-size:.9rem; vertical-align:top; }}
.ref-table td:first-child {{ width:240px; }}
.ref-table td:first-child a {{ font-family:monospace; font-weight:600;
                                color:{BLUE}; font-size:.9rem; }}
.ref-table tr:hover td {{ background:#f8f9ff; }}

/* Function page */
.fn-title {{ font-size:1.5rem; font-weight:700; color:{BLUE}; margin-bottom:.3rem; }}
.fn-usage {{ background:#1e2431; color:#abb2bf; padding:1rem 1.4rem;
             border-radius:.4rem; overflow-x:auto; margin:1rem 0; font-size:.875rem; }}
.fn-section-title {{ font-size:1rem; font-weight:700; color:#333;
                     margin:1.5rem 0 .6rem; border-left:3px solid {BLUE};
                     padding-left:.6rem; }}
.arg-name {{ font-family:monospace; color:{RED_CODE}; font-size:.875rem;
             font-weight:600; white-space:nowrap; }}
.arg-desc {{ font-size:.875rem; }}
.arg-row {{ display:flex; gap:1.25rem; padding:.5rem 0;
            border-bottom:1px solid #f0f0f0; }}

/* Articles */
.article-body h1,h2,h3 {{ color:{BLUE}; margin:1.5rem 0 .6rem; }}
.article-body h1 {{ font-size:1.6rem; }}
.article-body h2 {{ font-size:1.2rem; border-bottom:1px solid #e9ecef;
                    padding-bottom:.3rem; }}
.article-body h3 {{ font-size:1rem; }}
.article-body p  {{ margin-bottom:.9rem; }}
.article-body ul, .article-body ol {{ padding-left:1.5rem; margin-bottom:.9rem; }}
.article-body li {{ margin-bottom:.25rem; font-size:.95rem; }}
.article-body table {{ border-collapse:collapse; width:100%; margin:1rem 0; }}
.article-body th {{ background:{BLUE}; color:#fff; padding:.45rem .75rem;
                    text-align:left; font-size:.875rem; }}
.article-body td {{ padding:.4rem .75rem; border-bottom:1px solid #dee2e6;
                    font-size:.875rem; }}

/* Search highlight */
.highlight {{ background:#fff3cd; }}

/* Footer */
footer {{ text-align:center; padding:2rem 0; font-size:.82rem; color:#aaa;
          border-top:1px solid #e9ecef; margin-top:4rem; }}

/* Responsive */
@media(max-width:768px) {{
  .layout {{ flex-direction:column; }}
  .sidebar {{ width:100%; }}
  nav {{ gap:1rem; }}
  nav .search-box {{ display:none; }}
}}
"""

NAVBAR_TPL = """
<nav>
  <a class="brand" href="{{ root }}index.html">📦 nbbbenuts</a>
  <a href="{{ root }}index.html">Accueil</a>
  <a href="{{ root }}reference/index.html">Référence</a>
  <a href="{{ root }}articles/index.html">Articles</a>
  <a href="{{ root }}news.html">News</a>
  <div class="search-box">
    <input type="text" id="search-input" placeholder="Rechercher…" oninput="doSearch(this.value)">
  </div>
</nav>
"""

SEARCH_JS = """
<script>
(function(){
  var idx = null;
  fetch(root + 'search.json').then(r=>r.json()).then(d=>{idx=d});
  window.doSearch = function(q){
    if(!q||q.length<2){hideResults();return;}
    if(!idx) return;
    q = q.toLowerCase();
    var hits = idx.filter(e=>(e.name||'').toLowerCase().includes(q)||(e.title||'').toLowerCase().includes(q)||(e.body||'').toLowerCase().includes(q)).slice(0,12);
    showResults(hits, q);
  };
  function showResults(hits, q){
    var el = document.getElementById('search-results');
    if(!el){ el=document.createElement('div'); el.id='search-results';
      el.style.cssText='position:fixed;top:52px;right:1rem;width:340px;background:#fff;border:1px solid #dee2e6;border-radius:.5rem;box-shadow:0 8px 24px rgba(0,0,0,.15);z-index:999;max-height:420px;overflow-y:auto;';
      document.body.appendChild(el); }
    if(!hits.length){el.innerHTML='<p style="padding:.75rem 1rem;color:#888;font-size:.875rem">Aucun résultat.</p>';return;}
    el.innerHTML = hits.map(h=>'<a href="'+h.url+'" style="display:block;padding:.6rem 1rem;border-bottom:1px solid #f0f0f0;font-size:.875rem;color:#003A80;text-decoration:none;" onmouseover="this.style.background=\'#f8f9ff\'" onmouseout="this.style.background=\'\'"><strong>'+h.name+'</strong><br><span style="color:#666;font-size:.8rem">'+h.title+'</span></a>').join('');
  }
  function hideResults(){var el=document.getElementById('search-results');if(el)el.innerHTML='';}
  document.addEventListener('click',function(e){if(!e.target.closest('#search-results')&&!e.target.closest('#search-input'))hideResults();});
})();
</script>
"""

PAGE_TPL = Environment(loader=BaseLoader()).from_string("""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{ title }} — nbbbenuts</title>
<style>{{ css }}</style>
</head>
<body>
<script>var root='{{ root }}';</script>
{{ navbar }}
<div class="page">
{{ content }}
</div>
<footer>nbbbenuts {{ version }} &nbsp;·&nbsp; Documentation générée le {{ date }}</footer>
{{ search_js }}
</body>
</html>
""")


# ── Page builders ──────────────────────────────────────────────────────────────

def sidebar_html(root="", active=""):
    def cls(key):
        return ' class="active"' if active == key else ""
    lines = ['<div class="sidebar">',
             '<h4>Navigation</h4>',
             f'<a href="{root}index.html"{cls("")}>🏠 Accueil</a>',
             f'<a href="{root}reference/index.html"{cls("ref")}>📚 Référence</a>',
             f'<a href="{root}articles/index.html"{cls("art")}>📖 Articles</a>',
             f'<a href="{root}news.html"{cls("news")}>📋 News</a>',
             '</div>']
    return "\n".join(lines)


def render(path, title, content, root="", css=BASE_CSS, date="", version="0.1.0"):
    navbar = Environment(loader=BaseLoader()).from_string(NAVBAR_TPL).render(root=root)
    html_out = PAGE_TPL.render(
        title=title, css=css, navbar=navbar, content=content,
        root=root, search_js=SEARCH_JS, date=date, version=version,
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html_out, encoding="utf-8")
    print(f"  ✓ {path.relative_to(OUTDIR)}")


def build_home(date, version):
    sections = "\n".join(
        f'<div class="card"><h3><a href="reference/{fns[0]}.html">{sec}</a></h3>'
        f'<p>{", ".join(f"<code>{f}</code>" for f in fns[:3])}{"…" if len(fns)>3 else ""}</p></div>'
        for sec, fns in REFERENCE
    )
    content = f"""
<div class="hero">
  <h1>📦 nbbbenuts</h1>
  <p>Convertir les codes géographiques belges entre systèmes de classification
  (NIS, NUTS, postaux) et entre versions temporelles (NIS 2019/2025/BEFORE_2019,
  NUTS 2021/2027). Inclut le rebasement longitudinal, les splits M:N pondérés
  et les outils de diagnostic.</p>
  <a href="reference/index.html">→ Voir la référence complète</a>
  &nbsp;&nbsp;
  <a href="articles/index.html">→ Guides</a>
</div>
<h2 style="margin-bottom:1rem;color:#333;font-size:1.15rem">Fonctions par thème</h2>
<div class="cards">{sections}</div>
<h2 style="margin-bottom:.75rem;color:#333;font-size:1.15rem">Démarrage rapide</h2>
<pre><code class="language-r">library(nbbbenuts)
master_data &lt;- load_master_data()

# Convertir des communes NIS 2019 vers NUTS3
convert_codes(c(21004L, 11002L), "NIS_COMMUNE_2019", "NUTS3_2021", master_data)

# Valider des codes
validate_codes(c(21004L, 99999L), "NIS_COMMUNE_2019", master_data)

# Récupérer les noms officiels
get_label(c(21004L, 11002L), "NIS_COMMUNE_2019", master_data, lang = "fr")</code></pre>
"""
    render(OUTDIR / "index.html", "Accueil", content, root="", date=date, version=version)


def build_reference_index(date, version):
    body = '<div class="ref-section">'
    for sec, fns in REFERENCE:
        body += f'<h2>{sec}</h2><table class="ref-table">'
        for fname in fns:
            rd_path = MANDIR / f"{fname}.Rd"
            title = ""
            if rd_path.exists():
                src = rd_path.read_text(encoding="utf-8")
                title = rd_tag(src, "title")
            body += f'<tr><td><a href="{fname}.html"><code>{fname}</code></a></td><td>{html.escape(title)}</td></tr>'
        body += "</table>"
    body += "</div>"
    layout = f'<div class="layout">{sidebar_html(root="../", active="ref")}<div class="main-content"><h1 style="color:{BLUE};margin-bottom:1.5rem">Référence</h1>{body}</div></div>'
    render(OUTDIR / "reference" / "index.html", "Référence", layout, root="../", date=date, version=version)


def build_function_pages(date, version):
    all_fns = [fn for _, fns in REFERENCE for fn in fns]
    for fname in all_fns:
        rd_path = MANDIR / f"{fname}.Rd"
        if not rd_path.exists():
            continue
        doc = parse_rd(rd_path)

        # Breadcrumb
        section_name = next((s for s, fns in REFERENCE if fname in fns), "")
        crumbs = f'<p style="font-size:.8rem;color:#888;margin-bottom:1rem"><a href="index.html">Référence</a> › {section_name}</p>'

        body = crumbs
        body += f'<div class="fn-title">{html.escape(doc["title"])}</div>'
        body += f'<p style="font-family:monospace;font-size:.9rem;color:#666;margin-bottom:1rem">{doc["name"]}</p>'
        body += doc["description"]

        if doc["usage"]:
            body += f'<div class="fn-section-title">Usage</div>'
            body += f'<pre class="fn-usage">{doc["usage"]}</pre>'

        if doc["args"]:
            body += f'<div class="fn-section-title">Arguments</div>'
            for aname, adesc in doc["args"]:
                body += f'<div class="arg-row"><div style="min-width:180px" class="arg-name">{html.escape(aname)}</div><div class="arg-desc">{adesc}</div></div>'

        if doc["details"]:
            body += f'<div class="fn-section-title">Détails</div>{doc["details"]}'

        if doc["value"]:
            body += f'<div class="fn-section-title">Valeur retournée</div>{doc["value"]}'

        if doc["examples"]:
            body += f'<div class="fn-section-title">Exemples</div>'
            body += f'<pre><code class="language-r">{doc["examples"]}</code></pre>'

        layout = f'<div class="layout">{sidebar_html(root="../", active="ref")}<div class="main-content">{body}</div></div>'
        render(OUTDIR / "reference" / f"{fname}.html", doc["title"], layout, root="../", date=date, version=version)


def build_articles(date, version):
    # Index
    cards = ""
    for slug, title in ARTICLES:
        cards += f'<div class="card"><h3><a href="{slug}.html">{title}</a></h3></div>'
    body = f'<h1 style="color:{BLUE};margin-bottom:1.5rem">Articles</h1><div class="cards">{cards}</div>'
    layout = f'<div class="layout">{sidebar_html(root="../", active="art")}<div class="main-content">{body}</div></div>'
    render(OUTDIR / "articles" / "index.html", "Articles", layout, root="../", date=date, version=version)

    # Individual articles
    for slug, art_title in ARTICLES:
        # Try name variants
        candidates = [
            VIGDIR / f"{slug}.Rmd",
            VIGDIR / f"{slug.replace('-', '_')}.Rmd",
        ]
        rmd_path = next((p for p in candidates if p.exists()), None)
        if not rmd_path:
            continue
        doc = parse_rmd(rmd_path)
        crumbs = f'<p style="font-size:.8rem;color:#888;margin-bottom:1rem"><a href="index.html">Articles</a></p>'
        body = f'{crumbs}<div class="article-body"><h1>{html.escape(doc["title"])}</h1>{doc["body"]}</div>'
        layout = f'<div class="layout">{sidebar_html(root="../", active="art")}<div class="main-content">{body}</div></div>'
        render(OUTDIR / "articles" / f"{slug}.html", doc["title"], layout, root="../", date=date, version=version)


def build_news(date, version):
    news_path = ROOT / "NEWS.md"
    if news_path.exists():
        body = md.markdown(news_path.read_text(encoding="utf-8"))
    else:
        body = "<p>Pas de notes de version disponibles.</p>"
    layout = f'<div class="layout">{sidebar_html(root="", active="news")}<div class="main-content"><h1 style="color:{BLUE};margin-bottom:1.5rem">News</h1><div class="article-body">{body}</div></div></div>'
    render(OUTDIR / "news.html", "News", layout, root="", date=date, version=version)


def build_search_index():
    """JSON index for client-side search."""
    import json
    entries = []
    all_fns = [fn for _, fns in REFERENCE for fn in fns]
    for fname in all_fns:
        rd_path = MANDIR / f"{fname}.Rd"
        if not rd_path.exists():
            continue
        src = rd_path.read_text(encoding="utf-8")
        title = rd_tag(src, "title")
        desc  = rd_tag(src, "description")
        entries.append({"name": fname, "title": title,
                        "body": desc[:200], "url": f"reference/{fname}.html"})
    for slug, title in ARTICLES:
        candidates = [VIGDIR / f"{slug}.Rmd", VIGDIR / f"{slug.replace('-','_')}.Rmd"]
        rmd = next((p for p in candidates if p.exists()), None)
        if rmd:
            body = rmd.read_text(encoding="utf-8")[:500]
            entries.append({"name": slug, "title": title,
                            "body": body, "url": f"articles/{slug}.html"})
    out = OUTDIR / "search.json"
    out.write_text(json.dumps(entries, ensure_ascii=False), encoding="utf-8")
    print(f"  ✓ search.json ({len(entries)} entries)")


# ── Main ───────────────────────────────────────────────────────────────────────

def build():
    import datetime
    date    = datetime.date.today().strftime("%d/%m/%Y")
    version = "0.1.0"

    if OUTDIR.exists():
        shutil.rmtree(OUTDIR)
    OUTDIR.mkdir(parents=True)

    print("\n🔨 Building nbbbenuts documentation site…\n")
    print("Home")
    build_home(date, version)
    print("\nReference index")
    build_reference_index(date, version)
    print("\nFunction pages")
    build_function_pages(date, version)
    print("\nArticles")
    build_articles(date, version)
    print("\nNews")
    build_news(date, version)
    print("\nSearch index")
    build_search_index()
    print(f"\n✅  Site généré dans : {OUTDIR}\n")


if __name__ == "__main__":
    build()

    if "--serve" in sys.argv:
        import http.server, socketserver, os
        os.chdir(OUTDIR)
        PORT = 8080
        print(f"🌐  Serveur local : http://localhost:{PORT}")
        print("    Ctrl+C pour arrêter.\n")
        with socketserver.TCPServer(("", PORT), http.server.SimpleHTTPRequestHandler) as httpd:
            httpd.serve_forever()
