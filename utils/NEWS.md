# Daily news for Elfeed

`calibre-news-daily.timer` runs at 07:00 local time every day. A missed run
is caught up when the user timer starts (normally at login). The computer
must be awake and online to download; network failures retry after 30 minutes.
Calibre and Emacs do not have to be open for downloads to complete.

`fetch-calibre-news.py` uses the installed Calibre Financial Times and Atlantic
website recipes, with a 1.15-day article window and one browser download at a
time. The systemd service allows up to two CPU cores and runs at low priority.
An issue may omit articles that Calibre cannot retrieve.

Completed EPUBs are added to `~/Calibre Library`; existing issues for today's
date are skipped. When Calibre is open, its native import message is used.
When it is closed, `calibredb` adds the issue without starting the GUI. Staging
files remain after a failed import so retries do not download them again.

Live Emacs imports each finished issue into Elfeed. Otherwise open Elfeed and
press `G` to import it, then `RET` to read the EPUB. Logs and completion records
are under `~/.emacs.d/savefile/news-daily/YYYY-MM-DD/`.

Useful commands:

```sh
systemctl --user list-timers calibre-news-daily.timer
systemctl --user status calibre-news-daily.service
journalctl --user -u calibre-news-daily.service -n 30
systemctl --user start --no-block calibre-news-daily.service
python3 ~/.emacs.d/utils/fetch-calibre-news.py --check
systemctl --user disable --now calibre-news-daily.timer
```

The unit files are installed in `~/.config/systemd/user/`. After changing a
unit, copy the updated file there and run `systemctl --user daemon-reload`.
