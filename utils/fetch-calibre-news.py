#!/usr/bin/env python3
"""Download one daily Calibre issue per source, then refresh live Elfeed."""

import argparse
from datetime import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LIBRARY = Path.home() / "Calibre Library"
STATE = ROOT / "savefile/news-daily"
SOURCES = (
    ("financial-times", "financial_times.recipe", "ft", "Financial Times"),
    ("the-atlantic", "atlantic_com.recipe", "TheAtlantic", "TheAtlantic.com"),
)


def log(message):
    print(f"{datetime.now().isoformat(timespec='seconds')} {message}", flush=True)


def existing_issue(library, title):
    """Only count a completed EPUB; never modify the Calibre database here."""
    with sqlite3.connect((library / "metadata.db").as_uri() + "?mode=ro", uri=True) as db:
        rows = db.execute(
            "SELECT b.path,d.name FROM books b JOIN data d ON d.book=b.id "
            "WHERE b.title=? AND d.format='EPUB'", (title,)
        ).fetchall()
    for directory, name in rows:
        epub = library / directory / (name + ".epub")
        if epub.is_file() and epub.stat().st_size:
            return epub
    return None


def import_issue(library, title, epub):
    """Run under calibre-debug: use its lock and native GUI import protocol."""
    from calibre.utils.lock import SingleInstance
    from calibre.gui2.main import singleinstance_name, send_message_in_process

    # Holding the GUI lock while calibredb runs prevents a GUI startup race.
    # When the GUI already owns it, use the same IPC message as `calibre file`.
    with SingleInstance(singleinstance_name) as no_gui:
        if no_gui:
            subprocess.run([
                "/usr/bin/calibredb", "add", "--with-library", str(library),
                "--title", title, "--tags", "News,Daily news", str(epub),
            ], check=True, timeout=180)
        else:
            switch = "calibre://switch-library-by-path/_hex_-" + str(library).encode().hex()
            message = b"launched:" + json.dumps(["calibre", switch, str(epub)]).encode()
            send_message_in_process(message, timeout=15)
            log("Asked running Calibre to import completed issue")
    # GUI import is asynchronous. Do not remove the staging EPUB until confirmed.
    for _ in range(180):
        if existing_issue(library, title):
            return
        time.sleep(1)
    raise RuntimeError("Calibre did not finish importing; staged EPUB retained for retry")


def validate_epub(epub):
    with zipfile.ZipFile(epub) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"Corrupt EPUB member: {bad}")
        articles = sum(bool(re.search(r"(?:^|/)feed_\d+/article_\d+/[^/]+\.x?html$", name))
                       for name in archive.namelist())
        if not articles:
            raise RuntimeError("No article pages downloaded; refusing to import empty issue")
        return articles


def fetch_source(source, day, directory):
    slug, recipe_name, recipe_class, publication = source
    title = f"{publication} [{day.strftime('%a, %d %b %Y')}]"
    if existing_issue(LIBRARY, title):
        log(f"Already in library: {title}")
        return
    recipe = directory / recipe_name
    epub = directory / f"{slug}.epub"
    logfile = directory / f"{slug}.log"
    # Refresh from the installed recipes on each download, keeping Calibre's
    # extraction logic. Limit the window and browser concurrency for daily use.
    with zipfile.ZipFile("/opt/calibre/resources/builtin_recipes.zip") as recipes:
        code = recipes.read(recipe_name).decode("utf-8")
    code += (f"\n{recipe_class}.oldest_article = 1.15\n"
             f"{recipe_class}.simultaneous_downloads = 1\n"
             f"{recipe_class}.ignore_duplicate_articles = {{'url'}}\n")
    recipe.write_text(code)
    if not epub.exists():
        partial = directory / f"{slug}.partial.epub"
        log(f"Downloading {title}; details: {logfile}")
        with logfile.open("a") as output:
            subprocess.run([
                "/usr/bin/ebook-convert", str(recipe), str(partial),
                "--dont-download-recipe", "--output-profile", "tablet",
                "--title", title, "--pubdate", day.isoformat(),
            ], stdout=output, stderr=subprocess.STDOUT, check=True, timeout=4800)
        articles = validate_epub(partial)
        partial.replace(epub)
        log(f"Downloaded {publication}: {articles} article pages")
    else:
        validate_epub(epub)
        log(f"Retrying import of staged issue: {title}")
    subprocess.run([
        "/usr/bin/calibre-debug", "-e", str(Path(__file__).resolve()), "--",
        "--import-issue", str(LIBRARY), title, str(epub),
    ], check=True, timeout=400)
    completed = existing_issue(LIBRARY, title)
    if not completed:
        raise RuntimeError("Import could not be confirmed")
    (directory / f"{slug}.json").write_text(json.dumps({
        "title": title, "file": str(completed), "completed": datetime.now().isoformat(),
    }, indent=2) + "\n")
    epub.unlink()  # The library owns the completed copy now.
    log(f"Ready in Calibre: {title}")


def refresh_elfeed():
    # Never launch Emacs or open a second copy of the Elfeed database.
    local_client = Path.home() / ".local/bin/emacsclient"
    client = str(local_client) if local_client.exists() else "emacsclient"
    expression = ("(when (fboundp 'nam/elfeed-calibre-import-issues) "
                  "(nam/elfeed-calibre-import-issues) "
                  "(when (fboundp 'elfeed-search-update) (elfeed-search-update :force)))")
    try:
        result = subprocess.run([
            client, "--alternate-editor=false", "--quiet", "--eval", expression,
        ], capture_output=True, text=True, timeout=20)
        if result.returncode:
            log("Emacs unavailable; Elfeed will import on its next refresh")
        else:
            log("Refreshed live Elfeed")
    except (OSError, subprocess.TimeoutExpired):
        log("Emacs unavailable; Elfeed will import on its next refresh")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-issue", nargs=3, metavar=("LIBRARY", "TITLE", "EPUB"))
    parser.add_argument("--check", action="store_true", help="Report today's issues without fetching")
    args = parser.parse_args()
    if args.import_issue:
        library, title, epub = args.import_issue
        import_issue(Path(library), title, Path(epub))
        return 0
    os.environ["LC_ALL"] = "C.UTF-8"
    day = datetime.now().date()
    if args.check:
        for _, _, _, publication in SOURCES:
            title = f"{publication} [{day.strftime('%a, %d %b %Y')}]"
            print(f"{title}: {existing_issue(LIBRARY, title) or 'not downloaded yet'}")
        return 0
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / "fetch.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("A daily news fetch is already running")
            return 0
        directory = STATE / day.isoformat()
        directory.mkdir(exist_ok=True)
        failed = False
        for source in SOURCES:
            try:
                fetch_source(source, day, directory)
                refresh_elfeed()
            except Exception as error:
                log(f"{source[3]} failed: {error}")
                failed = True
        return int(failed)


if __name__ == "__main__":
    sys.exit(main())
