#!/usr/bin/env python3
"""Small HTTP server with byte ranges and media-aware directory listings."""

import argparse
import collections
import datetime
import email.utils
import functools
import hashlib
import html
import io
import json
import os
import re
import secrets
import socket
import stat
import sys
import threading
import time
import urllib.parse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


_BYTE_RANGE = re.compile(
    r"^\s*bytes\s*=\s*(\d*)-(\d*)\s*$",
    re.IGNORECASE,
)
_COPY_BUFFER_SIZE = 64 * 1024
_DOWNLOAD_ATTEMPT_PARAMETER = "download_attempt"
_DOWNLOAD_SESSION_PARAMETER = "download_id"
_DOWNLOAD_TOKEN_BYTES = 24
_DOWNLOAD_TOKEN_LENGTH = 32
_DOWNLOAD_TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9_-]{32}$")
_DOWNLOAD_SESSION_TTL_SECONDS = 24 * 60 * 60
_DOWNLOAD_SESSION_LIMIT = 4096
_DOWNLOAD_ATTEMPT_LIMIT = 65536
_DOWNLOAD_START_GRACE_SECONDS = 2
_DOWNLOAD_START_TIMEOUT_SECONDS = 15
_MAX_RANGE_DIGITS = 20
_RESUME_RESTART_STATUS = 409
_RESUME_RESTART_REASON = "Resume restart required"
_TRANSFER_ID_LOCK = threading.Lock()
_DIAGNOSTIC_LOG_LOCK = threading.Lock()
_TRANSFER_SEQUENCE = 0
_MEDIA_MIME_TYPES = {
    ".3g2": "video/3gpp2",
    ".3gp": "video/3gpp",
    ".aac": "audio/aac",
    ".flac": "audio/flac",
    ".m4a": "audio/mp4",
    ".m4v": "video/x-m4v",
    ".mk3d": "video/x-matroska",
    ".mka": "audio/x-matroska",
    ".mkv": "video/x-matroska",
    ".mov": "video/quicktime",
    ".mp3": "audio/mpeg",
    ".mp4": "video/mp4",
    ".oga": "audio/ogg",
    ".ogg": "audio/ogg",
    ".ogv": "video/ogg",
    ".opus": "audio/ogg",
    ".wav": "audio/wav",
    ".weba": "audio/webm",
    ".webm": "video/webm",
}
_DIRECTORY_STYLE = """
:root {
  color-scheme: light;
  --page-top: #e9faf7;
  --page-bottom: #f7fbfc;
  --surface: #ffffff;
  --surface-soft: #f1faf9;
  --ink: #18343d;
  --muted: #506972;
  --border: #c7e2df;
  --border-strong: #9fcfca;
  --accent: #087783;
  --accent-strong: #075e6d;
  --accent-soft: #dcf5f1;
  --focus: #0875b5;
  --danger: #b4232d;
  --shadow: 0 .8rem 2.5rem rgba(32, 91, 94, .09);
  font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont,
    "Segoe UI", sans-serif;
}
* { box-sizing: border-box; }
body {
  min-height: 100vh;
  min-height: 100dvh;
  margin: 0;
  background:
    radial-gradient(circle at 12% -8%, rgba(116, 221, 203, .32), transparent 28rem),
    radial-gradient(circle at 96% 2%, rgba(112, 197, 233, .2), transparent 26rem),
    linear-gradient(180deg, var(--page-top), var(--page-bottom) 30rem);
  color: var(--ink);
}
main {
  width: 100%;
  min-height: 100vh;
  min-height: 100dvh;
  padding: clamp(1.25rem, 3vw, 2.75rem) clamp(.9rem, 3vw, 3.5rem) 4rem;
}
main > header {
  padding: 0 clamp(.1rem, .6vw, .5rem);
}
h1, h2 { overflow-wrap: anywhere; }
h1 {
  margin: 0 0 .55rem;
  color: #123b46;
  font-size: clamp(1.65rem, 3.5vw, 2.65rem);
  font-weight: 750;
  letter-spacing: -.025em;
  line-height: 1.12;
}
h2 { margin: 0; font-size: 1.1rem; }
.hint {
  max-width: 78rem;
  margin: 0 0 clamp(1.25rem, 2.5vw, 2rem);
  color: var(--muted);
  font-size: 1rem;
  line-height: 1.55;
}
.media-panel {
  scroll-margin-top: 1rem;
  margin: 0 0 clamp(1.25rem, 2vw, 1.75rem);
  padding: clamp(1rem, 2vw, 1.5rem);
  border: 1px solid var(--border);
  border-radius: 1rem;
  background: rgba(255, 255, 255, .94);
  box-shadow: var(--shadow);
}
.media-panel:focus-visible {
  outline: .2rem solid var(--focus);
  outline-offset: .15rem;
}
.media-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: .8rem;
}
.media-actions { display: flex; flex-wrap: wrap; gap: .8rem; }
.media-actions a, .media-actions button {
  display: inline-flex;
  align-items: center;
  min-height: 2.75rem;
  padding: 0 .35rem;
  font-size: .9rem;
}
.download-form { display: inline; margin: 0; }
.download-status {
  margin: 0 0 clamp(1.25rem, 2vw, 1.75rem);
  padding: 1rem 1.15rem;
  border: 1px solid var(--border-strong);
  border-left: .3rem solid var(--accent);
  border-radius: .85rem;
  background: linear-gradient(105deg, var(--surface-soft), var(--surface));
  box-shadow: 0 .45rem 1.5rem rgba(32, 91, 94, .07);
}
.download-status p { margin: 0; }
#download-status-progress:not(:empty) {
  margin-top: .35rem;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}
.download-status .download-form {
  display: block;
  margin-top: .75rem;
}
.download-again {
  min-height: 2.75rem;
  padding: .55rem .95rem;
  border: 1px solid var(--accent);
  border-radius: .6rem;
  background: var(--accent);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-weight: 600;
  box-shadow: 0 .25rem .75rem rgba(8, 119, 131, .16);
}
.download-again:hover {
  background: var(--accent-strong);
  border-color: var(--accent-strong);
}
video, audio {
  display: block;
  width: 100%;
  border-radius: .7rem;
}
video {
  max-height: 76vh;
  background: #000;
}
.media-error {
  margin: .8rem 0 0;
  color: var(--danger);
}
.file-table-wrap {
  width: 100%;
  overflow-x: auto;
  border: 1px solid var(--border);
  border-radius: 1rem;
  background: rgba(255, 255, 255, .96);
  box-shadow: var(--shadow);
}
.file-table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}
.file-table th,
.file-table td {
  padding: .7rem clamp(.7rem, 1.3vw, 1.15rem);
  border-bottom: 1px solid #dcecea;
  text-align: left;
  vertical-align: middle;
}
.file-table th {
  background: var(--surface-soft);
  color: var(--muted);
  font-size: .76rem;
  letter-spacing: .055em;
  text-transform: uppercase;
}
.file-table tbody tr:last-child td { border-bottom: 0; }
.file-table tbody tr:hover,
.file-table tbody tr:focus-within {
  background: #f5fcfb;
}
.name-column { width: auto; }
.size-column {
  width: 8rem;
  text-align: right !important;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
.type-column { width: clamp(12rem, 20vw, 22rem); }
.play-column {
  width: 5.25rem;
  text-align: center !important;
}
.file-link {
  display: inline-block;
  max-width: 100%;
  overflow-wrap: anywhere;
  font-weight: 600;
  white-space: pre-wrap;
}
button.file-link,
.media-download-button {
  appearance: none;
  border: 0;
  background: none;
  color: var(--accent-strong);
  cursor: pointer;
  font: inherit;
  text-align: left;
  text-decoration: underline;
  text-underline-offset: .16em;
}
button.file-link {
  min-height: 2.75rem;
  padding: 0;
}
.media-download-button { padding: 0 .35rem; }
button.file-link:hover,
.media-download-button:hover {
  text-decoration-thickness: .13em;
}
button:disabled {
  cursor: wait;
  opacity: .6;
}
.play-link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 2.75rem;
  min-height: 2.75rem;
  border: 1px solid var(--border-strong);
  border-radius: 999px;
  color: var(--accent-strong);
  background: #fff;
  text-decoration: none;
}
.play-link:hover {
  border-color: var(--accent);
  background: var(--accent-soft);
}
.play-icon {
  margin-left: .12rem;
  font-size: .9rem;
}
.play-unavailable, .size-unavailable { color: #758a91; }
.visually-hidden {
  position: absolute !important;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  clip-path: inset(50%);
  white-space: nowrap;
}
.file-kind {
  display: inline-block;
  max-width: 100%;
  overflow: hidden;
  padding: .2rem .55rem;
  border-radius: 999px;
  background: var(--accent-soft);
  color: var(--accent-strong);
  font: 500 .75rem/1.4 ui-monospace, SFMono-Regular, Consolas, monospace;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.empty { color: var(--muted); font-style: italic; }
[hidden] { display: none !important; }
a { color: var(--accent-strong); text-underline-offset: .16em; }
a:hover { text-decoration-thickness: .13em; }
a:focus-visible,
button:focus-visible {
  outline: .2rem solid var(--focus);
  outline-offset: .15rem;
  border-radius: .15rem;
}
@media (prefers-reduced-motion: no-preference) {
  .download-again, .play-link {
    transition: background-color .16s ease, border-color .16s ease,
      box-shadow .16s ease, transform .16s ease;
  }
  .download-again:hover, .play-link:hover { transform: translateY(-1px); }
}
@media (max-width: 36rem) {
  main { padding: 1.15rem .7rem 2.5rem; }
  main > header { padding-inline: .25rem; }
  .media-toolbar { align-items: flex-start; flex-direction: column; }
  .type-column { display: none; }
  .size-column { width: 6.25rem; font-size: .85rem; }
  .play-column { width: 4.25rem; }
  .file-table th, .file-table td { padding: .45rem .6rem; }
  .file-table-wrap, .media-panel { border-radius: .8rem; }
}
"""
_DIRECTORY_SCRIPT = """
(function () {
  "use strict";

  var panel = document.getElementById("media-panel");
  var title = document.getElementById("media-title");
  var openLink = document.getElementById("media-open");
  var mediaDownloadForm = document.getElementById("media-download-form");
  var errorMessage = document.getElementById("media-error");
  var statusPanel = document.getElementById("download-status");
  var statusMessage = document.getElementById("download-status-message");
  var statusAlert = document.getElementById("download-status-alert");
  var statusProgress = document.getElementById("download-status-progress");
  var retryForm = document.getElementById("download-retry");
  var retryButton = document.getElementById("download-retry-button");
  var activeDownload = null;
  var pollGeneration = 0;
  var pollTimer = null;
  var pollFailures = 0;
  var interruptedSince = 0;
  var players = {
    audio: document.getElementById("audio-player"),
    video: document.getElementById("video-player")
  };

  function fileSize(bytes) {
    var units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"];
    var value = Number(bytes);
    var unit = 0;
    if (!isFinite(value) || value < 0) {
      return "";
    }
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    return (
      (unit === 0 ? String(Math.round(value)) : value.toFixed(2)) +
      " " + units[unit]
    );
  }

  function progressText(payload) {
    if (!(payload.size > 0) || !(payload.frontier >= 0)) {
      return "";
    }
    var percent = Math.min(100, payload.frontier * 100 / payload.size);
    return (
      " (" + fileSize(payload.frontier) + " of " +
      fileSize(payload.size) + ", " + percent.toFixed(1) + "%)"
    );
  }

  function showStatus(message, allowRetry, urgent, progress) {
    statusPanel.classList.remove("visually-hidden");
    if (urgent) {
      statusMessage.textContent = "";
      statusAlert.hidden = false;
      if (statusAlert.textContent !== message) {
        statusAlert.textContent = message;
      }
    } else {
      statusAlert.textContent = "";
      statusAlert.hidden = true;
      if (statusMessage.textContent !== message) {
        statusMessage.textContent = message;
      }
    }
    statusProgress.textContent = progress || "";
    retryForm.hidden = !allowRetry;
    if (allowRetry && activeDownload) {
      retryForm.action = activeDownload.action;
      retryForm.dataset.downloadAttempt = activeDownload.attempt;
      retryForm.dataset.downloadName = activeDownload.name;
      retryForm.dataset.statusUrl = activeDownload.statusUrl;
      retryButton.setAttribute(
        "aria-label",
        "Download " + activeDownload.name + " again from the beginning"
      );
    }
  }

  function setAttemptControlsDisabled(attempt, disabled) {
    var forms = document.querySelectorAll(
      ".download-form[data-download-attempt]"
    );
    Array.prototype.forEach.call(forms, function (form) {
      if (form.dataset.downloadAttempt === attempt) {
        var button = form.querySelector('button[type="submit"]');
        if (button) {
          button.disabled = disabled;
        }
      }
    });
  }

  function enableActiveButton() {
    if (activeDownload) {
      activeDownload.controlsDisabled = false;
      setAttemptControlsDisabled(activeDownload.attempt, false);
    }
  }

  function schedulePoll(delay, generation) {
    window.clearTimeout(pollTimer);
    pollTimer = window.setTimeout(function () {
      pollStatus(generation);
    }, delay);
  }

  function renderDownloadStatus(payload, generation) {
    if (generation !== pollGeneration || !activeDownload) {
      return;
    }

    var name = activeDownload.name;
    var state = payload.state;
    if (state === "idle" || state === "starting") {
      interruptedSince = 0;
      showStatus("Starting " + name + "\u2026", false);
      schedulePoll(1500, generation);
    } else if (state === "sending") {
      interruptedSince = 0;
      showStatus(
        "The server is sending " + name + ".",
        false,
        false,
        progressText(payload)
      );
      schedulePoll(2000, generation);
    } else if (state === "interrupted") {
      if (!interruptedSince) {
        interruptedSince = Date.now();
      }
      var canRestart = Date.now() - interruptedSince >= 5000;
      showStatus(
        "Waiting for the browser to resume " +
        name + "." +
        (
          canRestart
            ? " You can instead download it again from the beginning."
            : ""
        ),
        canRestart,
        false,
        progressText(payload)
      );
      if (canRestart) {
        enableActiveButton();
      }
      schedulePoll(2000, generation);
    } else if (state === "complete") {
      interruptedSince = 0;
      showStatus(
        "The server finished sending " + name +
        (payload.size == null ? "" : " (" + fileSize(payload.size) + ")") +
        ".",
        false
      );
      enableActiveButton();
    } else if (
      state === "failed" &&
      (
        payload.reason === "representation-mismatch" ||
        payload.reason === "file-unavailable"
      )
    ) {
      interruptedSince = 0;
      showStatus(
        "The file changed or became unavailable after this page was loaded. " +
        "Refresh the directory " +
        "before downloading it again.",
        false,
        true
      );
      enableActiveButton();
    } else if (
      state === "failed" &&
      (
        payload.reason === "server-capacity" ||
        payload.reason === "session-evicted"
      )
    ) {
      interruptedSince = 0;
      showStatus(
        "The previous attempt is no longer available. Download " + name +
        " again from the beginning; no page refresh is needed.",
        true,
        true
      );
      enableActiveButton();
    } else if (state === "failed") {
      interruptedSince = 0;
      showStatus(
        "The download stopped because the browser could not resume it " +
        "safely. The partial file is incomplete. Download it again from " +
        "the beginning; no page refresh is needed.",
        true,
        true
      );
      enableActiveButton();
    } else if (state === "expired" || state === "unknown") {
      interruptedSince = 0;
      showStatus(
        "This page's download control expired. Refresh the directory before " +
        "downloading " + name + " again.",
        false,
        true
      );
      enableActiveButton();
    } else if (state === "unavailable") {
      interruptedSince = 0;
      showStatus(
        "The server cannot start a protected download right now.",
        false,
        true
      );
      enableActiveButton();
    } else {
      showStatus(
        "Download status is temporarily unavailable for " + name + ".",
        false
      );
      schedulePoll(3000, generation);
    }
  }

  function pollStatus(generation) {
    if (
      generation !== pollGeneration ||
      !activeDownload ||
      typeof window.fetch !== "function"
    ) {
      return;
    }
    if (document.visibilityState === "hidden") {
      schedulePoll(2000, generation);
      return;
    }

    window.fetch(activeDownload.statusUrl, {
      cache: "no-store",
      credentials: "same-origin",
      headers: { Accept: "application/json" }
    }).then(function (response) {
      if (!response.ok) {
        throw new Error("status request failed");
      }
      return response.json();
    }).then(function (payload) {
      pollFailures = 0;
      renderDownloadStatus(payload, generation);
    }).catch(function () {
      if (generation === pollGeneration) {
        pollFailures += 1;
        if (pollFailures >= 3) {
          showStatus(
            "Cannot contact the server; download status is temporarily " +
            "unavailable.",
            false
          );
        }
        schedulePoll(pollFailures >= 3 ? 5000 : 3000, generation);
      }
    });
  }

  function beginDownloadStatus(form) {
    var action = form.getAttribute("action");
    var statusUrl = form.dataset.statusUrl;
    var attempt = form.dataset.downloadAttempt;
    var name = form.dataset.downloadName || "the selected file";
    if (!action || !statusUrl || !attempt) {
      return false;
    }

    enableActiveButton();
    activeDownload = {
      action: action,
      statusUrl: statusUrl,
      attempt: attempt,
      name: name,
      button: form.querySelector('button[type="submit"]'),
      controlsDisabled: false
    };
    pollFailures = 0;
    interruptedSince = 0;
    pollGeneration += 1;
    showStatus("Starting " + name + "\u2026", false);
    schedulePoll(750, pollGeneration);
    var submittedDownload = activeDownload;
    window.setTimeout(function () {
      if (
        activeDownload === submittedDownload &&
        submittedDownload.button
      ) {
        submittedDownload.controlsDisabled = true;
        setAttemptControlsDisabled(submittedDownload.attempt, true);
      }
    }, 0);
    return true;
  }

  document.addEventListener("submit", function (event) {
    var form = event.target;
    if (
      !(form instanceof HTMLFormElement) ||
      !form.classList.contains("download-form")
    ) {
      return;
    }
    if (form._downloadSubmitting) {
      event.preventDefault();
      return;
    }
    if (!beginDownloadStatus(form)) {
      event.preventDefault();
      return;
    }
    form._downloadSubmitting = true;
    window.setTimeout(function () {
      form._downloadSubmitting = false;
    }, 1500);
  });

  document.addEventListener("visibilitychange", function () {
    if (
      document.visibilityState === "visible" &&
      activeDownload
    ) {
      schedulePoll(0, pollGeneration);
    }
  });

  window.addEventListener("pageshow", function () {
    if (activeDownload) {
      schedulePoll(0, pollGeneration);
    }
  });

  function resetPlayer(player) {
    player.pause();
    player.removeAttribute("src");
    player.removeAttribute("aria-label");
    player.load();
    player.hidden = true;
  }

  Object.keys(players).forEach(function (kind) {
    players[kind].addEventListener("error", function () {
      if (!players[kind].hidden && players[kind].currentSrc) {
        errorMessage.textContent =
          "This browser could not play '" + title.textContent +
          "'. Its container or codecs may be unsupported; " +
          "try Open directly or Download.";
        errorMessage.hidden = false;
      }
    });
  });

  document.addEventListener("click", function (event) {
    if (!(event.target instanceof Element)) {
      return;
    }

    var link = event.target.closest("a[data-media-kind]");
    if (
      !link ||
      event.defaultPrevented ||
      event.button !== 0 ||
      event.altKey ||
      event.ctrlKey ||
      event.metaKey ||
      event.shiftKey
    ) {
      return;
    }

    var player = players[link.dataset.mediaKind];
    if (!player) {
      return;
    }

    event.preventDefault();
    var row = link.closest("tr");
    var nameLink = row ? row.querySelector(".file-link") : null;
    Object.keys(players).forEach(function (kind) {
      resetPlayer(players[kind]);
    });

    title.textContent = nameLink ? nameLink.textContent : "Selected media";
    openLink.href = link.href;
    mediaDownloadForm.hidden = !link.dataset.downloadUrl;
    if (link.dataset.downloadUrl) {
      mediaDownloadForm.action = link.dataset.downloadUrl;
      mediaDownloadForm.dataset.downloadAttempt =
        link.dataset.downloadAttempt;
      mediaDownloadForm.dataset.downloadName =
        link.dataset.downloadName || title.textContent;
      mediaDownloadForm.dataset.statusUrl =
        link.dataset.downloadStatusUrl;
      mediaDownloadForm.querySelector('button[type="submit"]').disabled =
        Boolean(
          activeDownload &&
          activeDownload.controlsDisabled &&
          activeDownload.attempt === link.dataset.downloadAttempt
        );
    }
    errorMessage.hidden = true;
    player.src = link.href;
    player.setAttribute("aria-label", "Playing " + title.textContent);
    player.hidden = false;
    panel.hidden = false;
    panel.focus({ preventScroll: true });
    var reduceMotion =
      window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    panel.scrollIntoView({
      behavior: reduceMotion ? "auto" : "smooth",
      block: "start"
    });
    player.load();

    var playback = player.play();
    if (playback && typeof playback.catch === "function") {
      playback.catch(function () {
        // Native controls remain available when autoplay policy blocks play().
      });
    }
  });
}());
"""


class _RangeNotSatisfiable(Exception):
    pass


def _parse_range_integer(value):
    if not value or len(value) > _MAX_RANGE_DIGITS:
        return None
    try:
        return int(value)
    except ValueError:
        return None


def _format_file_size(file_size):
    """Format a byte count compactly while retaining unambiguous IEC units."""
    if file_size < 1024:
        return "{} B".format(file_size)

    value = float(file_size)
    units = ("KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB")
    for unit in units:
        value /= 1024
        if value < 1024 or unit == units[-1]:
            number = "{:.2f}".format(value).rstrip("0").rstrip(".")
            return "{} {}".format(number, unit)


def _next_transfer_id():
    global _TRANSFER_SEQUENCE

    with _TRANSFER_ID_LOCK:
        _TRANSFER_SEQUENCE += 1
        return "T{:08d}".format(_TRANSFER_SEQUENCE)


def _download_session_label(token):
    """Return a short correlation label without exposing the session token."""
    digest = hashlib.sha256(token.encode("ascii")).hexdigest()
    return "D{}".format(digest[:12])


class _DownloadSession:
    __slots__ = (
        "token",
        "label",
        "attempt_id",
        "canonical_path",
        "etag",
        "file_size",
        "frontier",
        "quarantined",
        "failure_action",
        "transport_abort",
        "generation",
        "active_generation",
        "created_at",
        "last_activity",
    )

    def __init__(
        self,
        token,
        canonical_path,
        etag,
        file_size,
        now,
        attempt_id=None,
        transport_abort=False,
    ):
        self.token = token
        self.label = _download_session_label(token)
        self.attempt_id = attempt_id
        self.canonical_path = canonical_path
        self.etag = etag
        self.file_size = file_size
        self.frontier = 0
        self.quarantined = False
        self.failure_action = None
        self.transport_abort = transport_abort
        self.generation = 0
        self.active_generation = None
        self.created_at = now
        self.last_activity = now


class _DownloadAttempt:
    __slots__ = (
        "attempt_id",
        "canonical_path",
        "etag",
        "file_size",
        "latest_token",
        "failure_action",
        "last_activity",
    )

    def __init__(
        self,
        attempt_id,
        canonical_path,
        etag,
        file_size,
        now,
    ):
        self.attempt_id = attempt_id
        self.canonical_path = canonical_path
        self.etag = etag
        self.file_size = file_size
        self.latest_token = None
        self.failure_action = None
        self.last_activity = now


class _DownloadLease:
    __slots__ = ("token", "session", "generation")

    def __init__(self, session):
        self.token = session.token
        self.session = session
        self.generation = session.generation


class _DownloadSessionRegistry:
    """Bounded, in-memory state for guarded directory download links."""

    def __init__(
        self,
        ttl_seconds=_DOWNLOAD_SESSION_TTL_SECONDS,
        maximum_sessions=_DOWNLOAD_SESSION_LIMIT,
        maximum_attempts=_DOWNLOAD_ATTEMPT_LIMIT,
        clock=time.monotonic,
    ):
        if ttl_seconds <= 0:
            raise ValueError("download session TTL must be positive")
        if maximum_sessions <= 0:
            raise ValueError("download session limit must be positive")
        if maximum_attempts <= 0:
            raise ValueError("download attempt limit must be positive")

        self.ttl_seconds = ttl_seconds
        self.maximum_sessions = maximum_sessions
        self.maximum_attempts = maximum_attempts
        self._clock = clock
        self._lock = threading.Lock()
        self._sessions = collections.OrderedDict()
        self._attempts = collections.OrderedDict()

    def issue_attempt(self, canonical_path, etag, file_size):
        """Create a reusable, representation-bound launch capability."""
        now = self._clock()
        with self._lock:
            self._purge_expired_locked(now)
            self._purge_expired_attempts_locked(now)
            while True:
                attempt_id = secrets.token_urlsafe(_DOWNLOAD_TOKEN_BYTES)
                if (
                    len(attempt_id) == _DOWNLOAD_TOKEN_LENGTH
                    and attempt_id not in self._attempts
                ):
                    break

            while len(self._attempts) >= self.maximum_attempts:
                self._attempts.popitem(last=False)

            self._attempts[attempt_id] = _DownloadAttempt(
                attempt_id=attempt_id,
                canonical_path=canonical_path,
                etag=etag,
                file_size=file_size,
                now=now,
            )
            return attempt_id

    def issue(
        self,
        canonical_path,
        etag,
        file_size,
        attempt_id=None,
        transport_abort=False,
    ):
        """Issue a guarded file token, or return None when at capacity."""
        now = self._clock()
        with self._lock:
            self._purge_expired_locked(now)
            return self._issue_session_locked(
                canonical_path=canonical_path,
                etag=etag,
                file_size=file_size,
                now=now,
                attempt_id=attempt_id,
                transport_abort=transport_abort,
            )

    def launch(
        self,
        attempt_id,
        canonical_path,
        etag,
        file_size,
        transport_abort=False,
    ):
        """Mint a fresh guarded token from a valid launch capability."""
        now = self._clock()
        with self._lock:
            self._purge_expired_locked(now)
            expired_attempts = self._purge_expired_attempts_locked(now)
            attempt = self._attempts.get(attempt_id)
            if attempt is None:
                return {
                    "allow": False,
                    "action": (
                        "expired-attempt"
                        if attempt_id in expired_attempts
                        else "unknown-attempt"
                    ),
                    "token": None,
                }

            if attempt.canonical_path != canonical_path:
                attempt.failure_action = "path-mismatch"
                self._touch_attempt_locked(attempt, now)
                return {
                    "allow": False,
                    "action": attempt.failure_action,
                    "token": None,
                }

            if attempt.etag != etag or attempt.file_size != file_size:
                attempt.failure_action = "representation-mismatch"
                self._touch_attempt_locked(attempt, now)
                return {
                    "allow": False,
                    "action": attempt.failure_action,
                    "token": None,
                }

            latest = self._sessions.get(attempt.latest_token)
            if (
                latest is not None
                and not latest.quarantined
                and latest.active_generation is not None
            ):
                self._touch_attempt_locked(attempt, now)
                return {
                    "allow": False,
                    "action": "already-active",
                    "token": None,
                }

            if latest is not None and not latest.quarantined:
                if (
                    latest.generation == 0
                    and now - latest.created_at
                    <= _DOWNLOAD_START_GRACE_SECONDS
                ):
                    self._touch_attempt_locked(attempt, now)
                    return {
                        "allow": False,
                        "action": "already-starting",
                        "token": None,
                    }
                if (
                    latest.generation == 0
                    or latest.frontier < latest.file_size
                ):
                    self._quarantine_locked(
                        latest,
                        now,
                        action="superseded-by-new-attempt",
                    )

            token = self._issue_session_locked(
                canonical_path=canonical_path,
                etag=etag,
                file_size=file_size,
                now=now,
                attempt_id=attempt_id,
                transport_abort=transport_abort,
            )
            if token is None:
                attempt.failure_action = "server-capacity"
                self._touch_attempt_locked(attempt, now)
                return {
                    "allow": False,
                    "action": attempt.failure_action,
                    "token": None,
                }

            attempt.latest_token = token
            attempt.failure_action = None
            self._touch_attempt_locked(attempt, now)
            return {
                "allow": True,
                "action": "issued",
                "token": token,
            }

    def record_attempt_failure(
        self,
        attempt_id,
        action,
        canonical_path=None,
    ):
        """Expose a launcher failure without creating a child session."""
        now = self._clock()
        with self._lock:
            self._purge_expired_attempts_locked(now)
            attempt = self._attempts.get(attempt_id)
            if attempt is None or (
                canonical_path is not None
                and attempt.canonical_path != canonical_path
            ):
                return False
            attempt.failure_action = action
            self._touch_attempt_locked(attempt, now)
            return True

    def status_for_attempt(self, attempt_id, canonical_path=None):
        """Return public progress for the latest child of one launcher."""
        now = self._clock()
        with self._lock:
            self._purge_expired_locked(now)
            expired_attempts = self._purge_expired_attempts_locked(now)
            attempt = self._attempts.get(attempt_id)
            if attempt is None:
                return {
                    "state": (
                        "expired"
                        if attempt_id in expired_attempts
                        else "unknown"
                    ),
                    "reason": None,
                    "frontier": 0,
                    "size": None,
                }

            if (
                canonical_path is not None
                and attempt.canonical_path != canonical_path
            ):
                return {
                    "state": "unknown",
                    "reason": None,
                    "frontier": 0,
                    "size": None,
                }

            base = {
                "reason": attempt.failure_action,
                "frontier": 0,
                "size": attempt.file_size,
            }
            if attempt.failure_action is not None:
                base["state"] = "failed"
                return base

            if attempt.latest_token is None:
                base["state"] = "idle"
                return base

            session = self._sessions.get(attempt.latest_token)
            if session is None:
                base["state"] = "failed"
                base["reason"] = "session-evicted"
                return base

            if (
                session.generation == 0
                and now - session.created_at
                > _DOWNLOAD_START_TIMEOUT_SECONDS
            ):
                self._quarantine_locked(
                    session,
                    now,
                    action="start-timeout",
                )

            base["frontier"] = session.frontier
            if session.quarantined:
                base["state"] = "failed"
                base["reason"] = session.failure_action or "quarantined"
            elif session.generation == 0:
                base["state"] = "starting"
            elif session.active_generation is not None:
                base["state"] = "sending"
            elif session.frontier >= session.file_size:
                base["state"] = "complete"
            else:
                base["state"] = "interrupted"
            return base

    def _issue_session_locked(
        self,
        canonical_path,
        etag,
        file_size,
        now,
        attempt_id=None,
        transport_abort=False,
    ):
        while True:
            token = secrets.token_urlsafe(_DOWNLOAD_TOKEN_BYTES)
            if (
                len(token) == _DOWNLOAD_TOKEN_LENGTH
                and token not in self._sessions
            ):
                break

        while len(self._sessions) >= self.maximum_sessions:
            inactive_token = next(
                (
                    candidate_token
                    for candidate_token, candidate in self._sessions.items()
                    if candidate.active_generation is None
                ),
                None,
            )
            if inactive_token is None:
                return None
            del self._sessions[inactive_token]

        session = _DownloadSession(
            token=token,
            canonical_path=canonical_path,
            etag=etag,
            file_size=file_size,
            now=now,
            attempt_id=attempt_id,
            transport_abort=transport_abort,
        )
        self._sessions[token] = session
        return token

    def begin_full(self, token, canonical_path, etag, file_size):
        """Admit the one full body that may begin a generated download."""
        now = self._clock()
        with self._lock:
            result = self._lookup_locked(
                token,
                canonical_path,
                etag,
                file_size,
                now,
            )
            session = result.get("session")
            if not result["allow"]:
                return result

            if session.generation != 0:
                safe_frontier = session.frontier
                self._quarantine_locked(
                    session,
                    now,
                    action="full-restart-required",
                )
                return self._result(
                    action="full-restart-required",
                    session=session,
                    frontier=safe_frontier,
                )

            if (
                now - session.created_at
                > _DOWNLOAD_START_TIMEOUT_SECONDS
            ):
                self._quarantine_locked(
                    session,
                    now,
                    action="start-timeout",
                )
                return self._result(
                    action="start-timeout",
                    session=session,
                    frontier=0,
                )

            session.generation += 1
            session.frontier = 0
            session.active_generation = session.generation
            self._touch_locked(session, now)
            return self._result(
                action="started-full",
                session=session,
                frontier=0,
                lease=_DownloadLease(session),
                allow=True,
            )

    def admit_range(
        self,
        token,
        canonical_path,
        etag,
        file_size,
        requested_start,
    ):
        """Admit only a range beginning within the confirmed contiguous prefix."""
        now = self._clock()
        with self._lock:
            result = self._lookup_locked(
                token,
                canonical_path,
                etag,
                file_size,
                now,
                requested_start=requested_start,
            )
            session = result.get("session")
            if not result["allow"]:
                return result

            safe_frontier = session.frontier
            if requested_start > safe_frontier:
                self._quarantine_locked(
                    session,
                    now,
                    action="blocked-jump",
                )
                return self._result(
                    action="blocked-jump",
                    session=session,
                    frontier=safe_frontier,
                    requested_start=requested_start,
                )

            # A resumed download has one authoritative body stream. Supersede
            # an older handler so bytes written to an abandoned connection
            # cannot authorize a later offset for the new client task.
            session.generation += 1
            session.active_generation = session.generation
            self._touch_locked(session, now)
            return self._result(
                action="accepted",
                session=session,
                frontier=safe_frontier,
                requested_start=requested_start,
                lease=_DownloadLease(session),
                allow=True,
            )

    def inspect(
        self,
        token,
        canonical_path,
        etag,
        file_size,
        action="inspected",
        requested_start=None,
    ):
        """Validate a token without resetting or advancing its frontier."""
        now = self._clock()
        with self._lock:
            result = self._lookup_locked(
                token,
                canonical_path,
                etag,
                file_size,
                now,
                requested_start=requested_start,
            )
            session = result.get("session")
            if not result["allow"]:
                return result

            self._touch_locked(session, now)
            return self._result(
                action=action,
                session=session,
                frontier=session.frontier,
                requested_start=requested_start,
                allow=True,
            )

    def quarantine(
        self,
        token,
        canonical_path,
        etag,
        file_size,
        action,
        requested_start=None,
    ):
        """Disable a known token after a request that cannot be guarded safely."""
        now = self._clock()
        with self._lock:
            result = self._lookup_locked(
                token,
                canonical_path,
                etag,
                file_size,
                now,
                requested_start=requested_start,
            )
            session = result.get("session")
            if not result["allow"]:
                return result

            safe_frontier = session.frontier
            self._quarantine_locked(session, now, action=action)
            return self._result(
                action=action,
                session=session,
                frontier=safe_frontier,
                requested_start=requested_start,
            )

    def lease_active(self, lease):
        now = self._clock()
        with self._lock:
            self._purge_expired_locked(now)
            session = self._sessions.get(lease.token)
            if (
                session is not lease.session
                or session.quarantined
                or session.generation != lease.generation
                or session.active_generation != lease.generation
            ):
                return False
            self._touch_locked(session, now)
            return True

    def advance(self, lease, block_start, block_end):
        """Advance by source coordinate after one whole socket write succeeds."""
        now = self._clock()
        with self._lock:
            self._purge_expired_locked(now)
            session = self._sessions.get(lease.token)
            if (
                session is not lease.session
                or session.quarantined
                or session.generation != lease.generation
                or session.active_generation != lease.generation
            ):
                return False

            if block_start > session.frontier:
                self._quarantine_locked(
                    session,
                    now,
                    action="noncontiguous-source",
                )
                return False

            session.frontier = min(
                session.file_size,
                max(session.frontier, block_end),
            )
            self._touch_locked(session, now)
            return True

    def release(self, lease):
        if lease is None:
            return
        now = self._clock()
        with self._lock:
            session = self._sessions.get(lease.token)
            if (
                session is lease.session
                and session.generation == lease.generation
                and session.active_generation == lease.generation
            ):
                session.active_generation = None
                self._touch_locked(session, now)

    def frontier_for_lease(self, lease):
        if lease is None:
            return None
        with self._lock:
            session = self._sessions.get(lease.token)
            if (
                session is not lease.session
                or session.generation != lease.generation
            ):
                return None
            return session.frontier

    def __len__(self):
        now = self._clock()
        with self._lock:
            self._purge_expired_locked(now)
            return len(self._sessions)

    def _lookup_locked(
        self,
        token,
        canonical_path,
        etag,
        file_size,
        now,
        requested_start=None,
    ):
        expired = self._purge_expired_locked(now)
        session = self._sessions.get(token)
        if session is None:
            return self._result(
                action="expired" if token in expired else "unknown-token",
                label=_download_session_label(token),
                requested_start=requested_start,
            )

        if session.canonical_path != canonical_path:
            safe_frontier = session.frontier
            self._quarantine_locked(
                session,
                now,
                action="path-mismatch",
            )
            return self._result(
                action="path-mismatch",
                session=session,
                frontier=safe_frontier,
                requested_start=requested_start,
            )

        if session.etag != etag or session.file_size != file_size:
            safe_frontier = session.frontier
            self._quarantine_locked(
                session,
                now,
                action="representation-mismatch",
            )
            return self._result(
                action="representation-mismatch",
                session=session,
                frontier=safe_frontier,
                requested_start=requested_start,
            )

        if session.quarantined:
            self._touch_locked(session, now)
            return self._result(
                action="quarantined",
                session=session,
                frontier=session.frontier,
                requested_start=requested_start,
            )

        return self._result(
            action="known",
            session=session,
            frontier=session.frontier,
            requested_start=requested_start,
            allow=True,
        )

    def _quarantine_locked(self, session, now, action):
        if not session.quarantined:
            session.quarantined = True
            session.failure_action = action
            session.generation += 1
        elif session.failure_action is None:
            session.failure_action = action
        session.active_generation = None
        self._touch_locked(session, now)

    def _touch_locked(self, session, now):
        session.last_activity = now
        if self._sessions.get(session.token) is session:
            self._sessions.move_to_end(session.token)

    def _touch_attempt_locked(self, attempt, now):
        attempt.last_activity = now
        if self._attempts.get(attempt.attempt_id) is attempt:
            self._attempts.move_to_end(attempt.attempt_id)

    def _purge_expired_locked(self, now):
        expired = set()
        while self._sessions:
            token, session = next(iter(self._sessions.items()))
            if now - session.last_activity <= self.ttl_seconds:
                break
            expired.add(token)
            del self._sessions[token]
        return expired

    def _purge_expired_attempts_locked(self, now):
        expired = set()
        while self._attempts:
            attempt_id, attempt = next(iter(self._attempts.items()))
            if now - attempt.last_activity <= self.ttl_seconds:
                break
            expired.add(attempt_id)
            del self._attempts[attempt_id]
        return expired

    @staticmethod
    def _result(
        action,
        session=None,
        label=None,
        frontier=None,
        requested_start=None,
        lease=None,
        allow=False,
    ):
        return {
            "action": action,
            "label": (
                session.label
                if session is not None
                else (label if label is not None else "-")
            ),
            "frontier": frontier,
            "requested_start": requested_start,
            "lease": lease,
            "allow": allow,
            "session": session,
            "transport_abort": (
                session.transport_abort
                if session is not None
                else False
            ),
        }


class GuardedThreadingHTTPServer(ThreadingHTTPServer):
    """Threading server with per-instance guarded download state."""

    def __init__(
        self,
        server_address,
        request_handler_class,
        bind_and_activate=True,
        download_sessions=None,
    ):
        self.download_sessions = (
            download_sessions
            if download_sessions is not None
            else _DownloadSessionRegistry()
        )
        super().__init__(
            server_address,
            request_handler_class,
            bind_and_activate=bind_and_activate,
        )


class RangeRequestHandler(SimpleHTTPRequestHandler):
    """Serve files with one byte range per GET and a media-aware directory index."""

    protocol_version = "HTTP/1.1"
    extensions_map = dict(SimpleHTTPRequestHandler.extensions_map)
    extensions_map.update(_MEDIA_MIME_TYPES)

    _copy_window = None
    _range_capable_response = False
    _range_advertisement = "bytes"
    _guarded_download_response = False
    _resume_guard = None
    _transfer_state = None

    def do_GET(self):
        control = self._download_control_request()
        if control["present"]:
            if control["error"] is not None:
                self._send_empty_control_response(400, "Invalid download control")
            elif control["mode"] == "status":
                self._send_download_status(control["attempt_id"])
            else:
                self._send_empty_control_response(
                    405,
                    "Download launch requires POST",
                    headers=(("Allow", "POST"),),
                )
            return
        super().do_GET()

    def do_HEAD(self):
        control = self._download_control_request()
        if control["present"]:
            self._send_empty_control_response(
                405,
                "Download control does not support HEAD",
                headers=(("Allow", "GET, POST"),),
            )
            return
        super().do_HEAD()

    def do_POST(self):
        control = self._download_control_request()
        if (
            not control["present"]
            or control["error"] is not None
            or control["mode"] != "start"
        ):
            self._send_empty_control_response(
                405,
                "Method Not Allowed",
                headers=(("Allow", "GET, HEAD"),),
            )
            return

        if not self._launcher_request_is_bodyless():
            self._send_empty_control_response(400, "Invalid launcher request")
            return

        forbidden_headers = (
            "Range",
            "If-Range",
            "If-Match",
            "If-None-Match",
            "If-Modified-Since",
            "If-Unmodified-Since",
        )
        if any(self.headers.get_all(name, []) for name in forbidden_headers):
            self._send_empty_control_response(400, "Invalid launcher request")
            return

        registry = getattr(self.server, "download_sessions", None)
        path = self.translate_path(self.path)
        canonical_path = os.path.normcase(os.path.realpath(path))
        if not os.path.isfile(path):
            if registry is not None:
                registry.record_attempt_failure(
                    control["attempt_id"],
                    "file-unavailable",
                    canonical_path=canonical_path,
                )
            self._send_launcher_no_content("file-unavailable")
            return

        try:
            with open(path, "rb") as source:
                file_status = os.fstat(source.fileno())
        except OSError:
            if registry is not None:
                registry.record_attempt_failure(
                    control["attempt_id"],
                    "file-unavailable",
                    canonical_path=canonical_path,
                )
            self._send_launcher_no_content("file-unavailable")
            return

        if not stat.S_ISREG(file_status.st_mode):
            if registry is not None:
                registry.record_attempt_failure(
                    control["attempt_id"],
                    "file-unavailable",
                    canonical_path=canonical_path,
                )
            self._send_launcher_no_content("file-unavailable")
            return

        if registry is None:
            self._send_launcher_no_content("guard-unavailable")
            return

        result = registry.launch(
            attempt_id=control["attempt_id"],
            canonical_path=canonical_path,
            etag=self._make_etag(file_status),
            file_size=file_status.st_size,
            transport_abort=self._is_ios_webkit_request(),
        )
        if not result["allow"]:
            self._send_launcher_no_content(result["action"])
            return

        request_path = urllib.parse.urlsplit(self.path).path
        if not request_path.startswith("/"):
            request_path = "/" + request_path
        location = urllib.parse.urlunsplit(
            (
                "",
                "",
                request_path,
                urllib.parse.urlencode(
                    (
                        ("download", "1"),
                        (_DOWNLOAD_SESSION_PARAMETER, result["token"]),
                    )
                ),
                "",
            )
        )
        self._send_empty_control_response(
            303,
            "See Other",
            headers=(
                ("Location", location),
                ("Referrer-Policy", "no-referrer"),
            ),
        )

    def _download_control_request(self):
        try:
            query = urllib.parse.parse_qs(
                urllib.parse.urlsplit(self.path).query,
                keep_blank_values=True,
            )
        except (UnicodeError, ValueError):
            return {
                "present": True,
                "mode": None,
                "attempt_id": None,
                "error": "invalid-query",
            }

        mode_values = query.get("download", [])
        attempt_present = _DOWNLOAD_ATTEMPT_PARAMETER in query
        control_present = (
            attempt_present
            or any(value in ("start", "status") for value in mode_values)
        )
        if not control_present:
            return {
                "present": False,
                "mode": None,
                "attempt_id": None,
                "error": None,
            }

        error = None
        mode = mode_values[0] if len(mode_values) == 1 else None
        attempt_values = query.get(_DOWNLOAD_ATTEMPT_PARAMETER, [])
        if (
            set(query) != {"download", _DOWNLOAD_ATTEMPT_PARAMETER}
            or mode not in ("start", "status")
            or len(attempt_values) != 1
            or _DOWNLOAD_TOKEN_PATTERN.fullmatch(attempt_values[0]) is None
        ):
            error = "invalid-query"

        return {
            "present": True,
            "mode": mode,
            "attempt_id": (
                attempt_values[0]
                if len(attempt_values) == 1
                else None
            ),
            "error": error,
        }

    def _launcher_request_is_bodyless(self):
        if self.headers.get_all("Transfer-Encoding", []):
            return False
        content_lengths = self.headers.get_all("Content-Length", [])
        if not content_lengths:
            return True
        if len(content_lengths) != 1:
            return False
        return content_lengths[0].strip() == "0"

    def _send_download_status(self, attempt_id):
        registry = getattr(self.server, "download_sessions", None)
        if registry is None:
            payload = {
                "state": "unavailable",
                "reason": "guard-unavailable",
                "frontier": 0,
                "size": None,
            }
        else:
            payload = registry.status_for_attempt(
                attempt_id,
                canonical_path=os.path.normcase(
                    os.path.realpath(self.translate_path(self.path))
                ),
            )

        encoded = json.dumps(
            payload,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
        self._range_capable_response = False
        self._range_advertisement = "bytes"
        self._guarded_download_response = False
        self.send_response_only(200)
        self.send_header("Server", self.version_string())
        self.send_header("Date", self.date_time_string())
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(encoded)

    def _send_launcher_no_content(self, action):
        """Keep a failed form navigation on the usable directory page."""
        self._range_capable_response = False
        self._range_advertisement = "bytes"
        self._guarded_download_response = False
        self.close_connection = True
        self.send_response(204, "No Content")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Download-Launch", action)
        self.send_header("Connection", "close")
        self.end_headers()

    def _send_empty_control_response(self, status, reason, headers=()):
        self._range_capable_response = False
        self._range_advertisement = "bytes"
        self._guarded_download_response = False
        self.close_connection = True
        self.send_response(status, reason)
        self.send_header("Content-Length", "0")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Connection", "close")
        for name, value in headers:
            self.send_header(name, value)
        self.end_headers()

    def send_head(self):
        self._copy_window = None
        self._range_capable_response = False
        self._range_advertisement = "bytes"
        self._guarded_download_response = False
        self._resume_guard = {
            "action": "direct",
            "label": "-",
            "frontier": None,
            "requested_start": None,
            "lease": None,
            "registry": None,
            "transport_abort": False,
        }
        self._transfer_state = None

        path = self.translate_path(self.path)
        if os.path.isdir(path) or not os.path.isfile(path):
            return super().send_head()

        self._range_capable_response = True
        try:
            source = open(path, "rb")
        except OSError:
            self._range_capable_response = False
            return super().send_head()

        try:
            file_status = os.fstat(source.fileno())
            if not stat.S_ISREG(file_status.st_mode):
                source.close()
                self._range_capable_response = False
                return super().send_head()

            file_size = file_status.st_size
            content_type = self.guess_type(path)
            last_modified_timestamp = min(file_status.st_mtime, time.time())
            last_modified = self.date_time_string(last_modified_timestamp)
            etag = self._make_etag(file_status)
            download_details = self._download_request_details()
            download_requested = (
                download_details["download_requested"]
                or download_details["token_present"]
            )
            if download_details["token_present"]:
                self._guarded_download_response = True
                self._range_advertisement = "none"
                self._resume_guard["action"] = "precondition"

            if self._preflight_download_guard(
                download_details=download_details,
                path=path,
                etag=etag,
                file_size=file_size,
            ):
                return self._reject_resume_request(
                    source=source,
                    etag=etag,
                    last_modified=last_modified,
                )

            range_values = self.headers.get_all("Range", [])
            if_match_values = self.headers.get_all("If-Match", [])
            if if_match_values:
                precondition_failed = not self._if_match_matches(
                    if_match_values,
                    etag,
                )
            else:
                precondition_failed = self._if_unmodified_since_fails(
                    self._get_single_header("If-Unmodified-Since"),
                    last_modified_timestamp,
                )

            if precondition_failed:
                if download_details["token_present"] and range_values:
                    self._quarantine_download_guard(
                        download_details=download_details,
                        path=path,
                        etag=etag,
                        file_size=file_size,
                        action="conditional-range",
                    )
                    return self._reject_resume_request(
                        source=source,
                        etag=etag,
                        last_modified=last_modified,
                    )
                source.close()
                self.send_response(412)
                self.send_header("Content-Length", "0")
                self.send_header("ETag", etag)
                self.send_header("Last-Modified", last_modified)
                self.end_headers()
                self._log_file_response(
                    status=412,
                    content_length=0,
                    etag=etag,
                )
                return None

            if_none_match_values = self.headers.get_all("If-None-Match", [])
            if if_none_match_values:
                not_modified = self._if_none_match_matches(
                    if_none_match_values,
                    etag,
                )
            else:
                not_modified = self._if_modified_since_matches(
                    self._get_single_header("If-Modified-Since"),
                    last_modified_timestamp,
                )

            if not_modified:
                if download_details["token_present"] and range_values:
                    self._quarantine_download_guard(
                        download_details=download_details,
                        path=path,
                        etag=etag,
                        file_size=file_size,
                        action="conditional-range",
                    )
                    return self._reject_resume_request(
                        source=source,
                        etag=etag,
                        last_modified=last_modified,
                    )
                source.close()
                self.send_response(304)
                self.send_header("ETag", etag)
                self.send_header("Last-Modified", last_modified)
                self.end_headers()
                self._log_file_response(
                    status=304,
                    content_length=None,
                    etag=etag,
                )
                return None

            guard_rejected = self._prepare_download_guard(
                download_details=download_details,
                path=path,
                etag=etag,
                file_size=file_size,
                last_modified=last_modified,
                range_values=range_values,
            )

            if guard_rejected:
                return self._reject_resume_request(
                    source=source,
                    etag=etag,
                    last_modified=last_modified,
                )

            selected_range = None
            if self.command == "GET" and len(range_values) == 1:
                if_range_values = self.headers.get_all("If-Range", [])
                if not if_range_values or (
                    len(if_range_values) == 1
                    and self._if_range_matches(
                        if_range_values[0],
                        etag,
                        last_modified,
                    )
                ):
                    try:
                        selected_range = self._parse_byte_range(
                            range_values[0],
                            file_size,
                        )
                    except _RangeNotSatisfiable:
                        source.close()
                        self._release_resume_guard_lease()
                        self.send_response(416)
                        self.send_header(
                            "Content-Range",
                            "bytes */{}".format(file_size),
                        )
                        self.send_header("Content-Length", "0")
                        self.send_header("ETag", etag)
                        self.send_header("Last-Modified", last_modified)
                        self.end_headers()
                        self._log_file_response(
                            status=416,
                            content_length=0,
                            etag=etag,
                            content_range="bytes */{}".format(file_size),
                        )
                        return None

            # Direct/un-tokenized malformed or multipart ranges retain the
            # standard full-response fallback. Guarded forms were rejected.
            if selected_range is None:
                self._copy_window = (0, file_size)
                self._send_file_headers(
                    status=200,
                    content_type=content_type,
                    content_length=file_size,
                    last_modified=last_modified,
                    etag=etag,
                    download_requested=download_requested,
                )
                self._log_file_response(
                    status=200,
                    content_length=file_size,
                    etag=etag,
                    start=0,
                    end=file_size - 1,
                )
                return source

            start, end = selected_range
            content_length = end - start + 1
            content_range = "bytes {}-{}/{}".format(
                start,
                end,
                file_size,
            )
            self._copy_window = (start, content_length)
            self._send_file_headers(
                status=206,
                content_type=content_type,
                content_length=content_length,
                last_modified=last_modified,
                etag=etag,
                download_requested=download_requested,
                content_range=content_range,
            )
            self._log_file_response(
                status=206,
                content_length=content_length,
                etag=etag,
                content_range=content_range,
                start=start,
                end=end,
            )
            return source
        except Exception:
            self._release_resume_guard_lease()
            source.close()
            raise

    def _reject_resume_request(self, source, etag, last_modified):
        source.close()
        self._release_resume_guard_lease()
        self._copy_window = None
        if (
            self.command == "GET"
            and self._guarded_download_response
            and (
                self._resume_guard.get("transport_abort", False)
                or self._is_ios_webkit_request()
            )
        ):
            self._log_resume_transport_abort(etag)
            self.close_connection = True
            try:
                self.connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            return None

        self._send_resume_restart_required(
            etag=etag,
            last_modified=last_modified,
        )
        self._log_file_response(
            status=_RESUME_RESTART_STATUS,
            content_length=0,
            etag=etag,
        )
        return None

    def _send_resume_restart_required(self, etag, last_modified):
        """Fail a rejected download without sending misplaceable file bytes."""
        self.close_connection = True
        self.send_response(
            _RESUME_RESTART_STATUS,
            _RESUME_RESTART_REASON,
        )
        self.send_header("Content-Length", "0")
        self.send_header("ETag", etag)
        self.send_header("Last-Modified", last_modified)
        self.send_header("Connection", "close")
        self.send_header("X-Resume-Guard", "restart-required")
        self.end_headers()

    def _send_file_headers(
        self,
        status,
        content_type,
        content_length,
        last_modified,
        etag,
        download_requested,
        content_range=None,
    ):
        if (
            status == 206
            and self._resume_guard
            and self._resume_guard.get("action") == "accepted"
            and (self._resume_guard.get("frontier") or 0) > 0
            and (
                self._resume_guard.get("transport_abort", False)
                or self._is_ios_webkit_request()
            )
        ):
            # Safari has already completed one valid resume. Advise it not to
            # construct another Range request; the guard still protects the
            # representation if the advisory is ignored.
            self._range_advertisement = "none"

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        if content_range is not None:
            self.send_header("Content-Range", content_range)
        self.send_header("Content-Length", str(content_length))
        self.send_header("Last-Modified", last_modified)
        self.send_header("ETag", etag)
        if download_requested and status in (200, 206):
            self.send_header("Content-Disposition", "attachment")
            self.send_header("Connection", "close")
            self.close_connection = True
        self.end_headers()

    def _is_ios_webkit_request(self):
        user_agent = self.headers.get("User-Agent", "")
        if "AppleWebKit/" not in user_agent:
            return (
                "CFNetwork/" in user_agent
                and "Darwin/" in user_agent
            )
        return (
            any(
                marker in user_agent
                for marker in ("iPhone", "iPad", "iPod")
            )
            or (
                "Macintosh" in user_agent
                and "Mobile/" in user_agent
            )
        )

    def _log_resume_transport_abort(self, etag):
        guard = self._resume_guard or {}
        self._safe_diagnostic_log(
            "file response aborted: ID=%s Client=%s Method=%s Target=%s "
            "Session=%s Resume-Guard=%s Transport-Abort=%s "
            "Requested-Start=%s "
            "Safe-Frontier=%s Range=%s If-Range=%s -> "
            "connection-close-before-headers ETag=%s",
            _next_transfer_id(),
            self._format_client_address(self.client_address),
            self.command,
            self._format_log_values(
                [self.path.partition("?")[0]],
                limit=240,
            ),
            guard.get("label", "-"),
            guard.get("action", "rejected"),
            "yes" if guard.get("transport_abort", False) else "request-ua",
            (
                "-"
                if guard.get("requested_start") is None
                else guard["requested_start"]
            ),
            (
                "-"
                if guard.get("frontier") is None
                else guard["frontier"]
            ),
            self._format_log_values(self.headers.get_all("Range", [])),
            self._format_log_values(self.headers.get_all("If-Range", [])),
            etag,
        )

    def end_headers(self):
        if self._range_capable_response:
            self.send_header("Accept-Ranges", self._range_advertisement)
        if self._guarded_download_response:
            self.send_header("Cache-Control", "no-store")
        self._range_capable_response = False
        self._range_advertisement = "bytes"
        self._guarded_download_response = False
        super().end_headers()

    def send_error(self, *args, **kwargs):
        self._release_resume_guard_lease()
        self._copy_window = None
        self._range_capable_response = False
        self._range_advertisement = "bytes"
        self._guarded_download_response = False
        self._resume_guard = None
        self._transfer_state = None
        return super().send_error(*args, **kwargs)

    def copyfile(self, source, outputfile):
        if self._copy_window is None:
            return super().copyfile(source, outputfile)

        start, remaining = self._copy_window
        bytes_written = 0
        outcome = "incomplete"
        transfer_error = None
        phase = "source-seek"
        transfer = self._transfer_state or {}
        guard_registry = transfer.get("guard_registry")
        guard_lease = transfer.get("guard_lease")

        if self._transfer_state is not None:
            self._transfer_state["started_at"] = time.monotonic()

        try:
            source.seek(start)

            while remaining > 0:
                if (
                    guard_lease is not None
                    and not guard_registry.lease_active(guard_lease)
                ):
                    outcome = "resume-guard-superseded"
                    self.close_connection = True
                    break

                phase = "source-read"
                block = source.read(min(_COPY_BUFFER_SIZE, remaining))
                if not block:
                    outcome = "source-ended-early"
                    self.close_connection = True
                    break

                if (
                    guard_lease is not None
                    and not guard_registry.lease_active(guard_lease)
                ):
                    outcome = "resume-guard-superseded"
                    self.close_connection = True
                    break

                block_start = start + bytes_written
                phase = "socket-write"
                try:
                    write_result = outputfile.write(block)
                except (
                    BrokenPipeError,
                    ConnectionResetError,
                    ConnectionAbortedError,
                ) as caught:
                    outcome = "client-disconnected"
                    transfer_error = caught
                    self.close_connection = True
                    break

                if write_result is not None and write_result != len(block):
                    if (
                        isinstance(write_result, int)
                        and 0 < write_result < len(block)
                    ):
                        bytes_written += write_result
                        remaining -= write_result
                    raise OSError("short socket write")

                # A successful unbuffered socket write accounts for this whole
                # block. A failed send can put an unknowable prefix on the wire,
                # so disconnect counts intentionally remain a lower bound.
                bytes_written += len(block)
                remaining -= len(block)

                if (
                    guard_lease is not None
                    and not guard_registry.advance(
                        guard_lease,
                        block_start,
                        block_start + len(block),
                    )
                ):
                    outcome = "resume-guard-superseded"
                    self.close_connection = True
                    break

            if remaining == 0 and outcome == "incomplete":
                outcome = "complete"
        except Exception as caught:
            transfer_error = caught
            if phase in ("source-seek", "source-read"):
                outcome = "source-read-failed"
            else:
                outcome = "write-failed"
            self.close_connection = True
            raise
        finally:
            self._copy_window = None
            if guard_registry is not None and guard_lease is not None:
                guard_registry.release(guard_lease)
            self._finish_file_transfer(
                outcome=outcome,
                bytes_written=bytes_written,
                remaining=remaining,
                error=transfer_error,
            )

    @staticmethod
    def _make_etag(file_status):
        mtime_ns = getattr(
            file_status,
            "st_mtime_ns",
            int(file_status.st_mtime * 1_000_000_000),
        )
        ctime_ns = getattr(
            file_status,
            "st_ctime_ns",
            int(file_status.st_ctime * 1_000_000_000),
        )
        return '"{:x}-{:x}-{:x}-{:x}-{:x}"'.format(
            file_status.st_dev,
            file_status.st_ino,
            file_status.st_size,
            mtime_ns,
            ctime_ns,
        )

    def _download_request_details(self):
        query = urllib.parse.parse_qs(
            urllib.parse.urlsplit(self.path).query,
            keep_blank_values=True,
        )
        download_requested = query.get("download") == ["1"]
        token_present = _DOWNLOAD_SESSION_PARAMETER in query
        token = None
        error = None

        if token_present:
            token_values = query.get(_DOWNLOAD_SESSION_PARAMETER, [])
            if (
                len(token_values) != 1
                or _DOWNLOAD_TOKEN_PATTERN.fullmatch(token_values[0]) is None
            ):
                error = "invalid-token"
            else:
                token = token_values[0]

            if not download_requested:
                error = "invalid-download-query"

        return {
            "download_requested": download_requested,
            "token_present": token_present,
            "token": token,
            "error": error,
        }

    def _quarantine_download_guard(
        self,
        download_details,
        path,
        etag,
        file_size,
        action,
    ):
        registry = getattr(self.server, "download_sessions", None)
        token = download_details["token"]
        if registry is not None and token is not None:
            decision = registry.quarantine(
                token,
                os.path.normcase(os.path.realpath(path)),
                etag,
                file_size,
                action=action,
            )
        else:
            decision = self._local_guard_decision(
                action=action,
                token=token,
            )
        self._set_resume_guard(decision, registry)

    def _preflight_download_guard(
        self,
        download_details,
        path,
        etag,
        file_size,
    ):
        """Reject an invalid token before HTTP conditions can mask it."""
        if not download_details["token_present"]:
            return False

        registry = getattr(self.server, "download_sessions", None)
        token = download_details["token"]
        canonical_path = os.path.normcase(os.path.realpath(path))
        error = download_details["error"]

        if error is not None:
            if registry is not None and token is not None:
                decision = registry.quarantine(
                    token,
                    canonical_path,
                    etag,
                    file_size,
                    action=error,
                )
            else:
                decision = self._local_guard_decision(
                    action=error,
                    token=token,
                )
        elif registry is None:
            decision = self._local_guard_decision(
                action="guard-unavailable",
                token=token,
            )
        else:
            decision = registry.inspect(
                token,
                canonical_path,
                etag,
                file_size,
                action="precondition",
            )

        self._set_resume_guard(decision, registry)
        return not decision["allow"]

    def _prepare_download_guard(
        self,
        download_details,
        path,
        etag,
        file_size,
        last_modified,
        range_values,
    ):
        """Select guarded range behavior before ordinary range parsing."""
        if not download_details["token_present"]:
            return False

        registry = getattr(self.server, "download_sessions", None)
        token = download_details["token"]
        canonical_path = os.path.normcase(os.path.realpath(path))
        error = download_details["error"]

        if error is not None:
            if registry is not None and token is not None:
                decision = registry.quarantine(
                    token,
                    canonical_path,
                    etag,
                    file_size,
                    action=error,
                )
            else:
                decision = self._local_guard_decision(
                    action=error,
                    token=token,
                )
            self._set_resume_guard(decision, registry)
            return True

        if registry is None:
            decision = self._local_guard_decision(
                action="guard-unavailable",
                token=token,
            )
            self._set_resume_guard(decision, registry)
            return True

        if self.command != "GET":
            decision = registry.inspect(
                token,
                canonical_path,
                etag,
                file_size,
                action="head",
            )
            self._set_resume_guard(decision, registry)
            return not decision["allow"]

        if not range_values:
            decision = registry.begin_full(
                token,
                canonical_path,
                etag,
                file_size,
            )
            self._set_resume_guard(decision, registry)
            return not decision["allow"]

        if len(range_values) != 1:
            decision = registry.quarantine(
                token,
                canonical_path,
                etag,
                file_size,
                action="invalid-range",
            )
            self._set_resume_guard(decision, registry)
            return True

        if_range_values = self.headers.get_all("If-Range", [])
        if if_range_values and not (
            len(if_range_values) == 1
            and self._if_range_matches(
                if_range_values[0],
                etag,
                last_modified,
            )
        ):
            decision = registry.quarantine(
                token,
                canonical_path,
                etag,
                file_size,
                action="if-range-mismatch",
            )
            self._set_resume_guard(decision, registry)
            return True

        range_match = _BYTE_RANGE.fullmatch(range_values[0])
        if range_match is None:
            decision = registry.quarantine(
                token,
                canonical_path,
                etag,
                file_size,
                action="invalid-range",
            )
            self._set_resume_guard(decision, registry)
            return True

        first, last = range_match.groups()
        requested_start = None
        invalid_action = None
        if first:
            requested_start = _parse_range_integer(first)
            requested_end = (
                _parse_range_integer(last)
                if last
                else None
            )
            if requested_start is None or (
                last and requested_end is None
            ):
                invalid_action = "invalid-range"
            elif (
                requested_end is not None
                and requested_end < requested_start
            ):
                invalid_action = "invalid-range"
            elif requested_start >= file_size:
                invalid_action = "unsatisfiable-range"
        elif last:
            suffix_length = _parse_range_integer(last)
            if suffix_length is None or suffix_length == 0:
                invalid_action = "invalid-range"
            elif file_size == 0:
                invalid_action = "unsatisfiable-range"
            else:
                requested_start = max(file_size - suffix_length, 0)
        else:
            invalid_action = "invalid-range"

        if invalid_action is not None:
            decision = registry.quarantine(
                token,
                canonical_path,
                etag,
                file_size,
                action=invalid_action,
                requested_start=requested_start,
            )
        else:
            decision = registry.admit_range(
                token,
                canonical_path,
                etag,
                file_size,
                requested_start=requested_start,
            )

        self._set_resume_guard(decision, registry)
        return not decision["allow"]

    def _set_resume_guard(self, decision, registry):
        self._resume_guard = {
            "action": decision["action"],
            "label": decision["label"],
            "frontier": decision["frontier"],
            "requested_start": decision["requested_start"],
            "lease": decision["lease"],
            "registry": registry,
            "transport_abort": decision.get("transport_abort", False),
        }
        if decision["allow"]:
            self._range_advertisement = "bytes"
        else:
            self._range_advertisement = "none"

    def _release_resume_guard_lease(self):
        guard = self._resume_guard
        if not guard:
            return
        registry = guard.get("registry")
        lease = guard.get("lease")
        if registry is not None and lease is not None:
            registry.release(lease)

    @staticmethod
    def _local_guard_decision(action, token=None):
        return {
            "action": action,
            "label": (
                _download_session_label(token)
                if token is not None
                else "-"
            ),
            "frontier": None,
            "requested_start": None,
            "lease": None,
            "allow": False,
            "transport_abort": False,
        }

    def _get_single_header(self, name):
        values = self.headers.get_all(name, [])
        return values[0] if len(values) == 1 else None

    @classmethod
    def _if_match_matches(cls, values, etag):
        for value in values:
            if value.strip() == "*":
                return True
            for candidate in cls._iter_entity_tags(value):
                if not candidate.startswith("W/") and candidate == etag:
                    return True
        return False

    @classmethod
    def _if_none_match_matches(cls, values, etag):
        current_opaque_tag = etag
        for value in values:
            if value.strip() == "*":
                return True
            for candidate in cls._iter_entity_tags(value):
                if candidate.startswith("W/"):
                    candidate = candidate[2:]
                if candidate == current_opaque_tag:
                    return True
        return False

    @staticmethod
    def _iter_entity_tags(value):
        position = 0
        value_length = len(value)

        while position < value_length:
            while position < value_length and value[position] in " \t":
                position += 1

            tag_start = position
            if value.startswith("W/", position):
                position += 2
            if position >= value_length or value[position] != '"':
                return

            position += 1
            tag_end = value.find('"', position)
            if tag_end < 0:
                return
            position = tag_end + 1
            yield value[tag_start:position]

            while position < value_length and value[position] in " \t":
                position += 1
            if position == value_length:
                return
            if value[position] != ",":
                return
            position += 1

    @staticmethod
    def _if_modified_since_matches(value, last_modified_timestamp):
        if value is None:
            return False
        try:
            modified_since = email.utils.parsedate_to_datetime(value)
        except (TypeError, ValueError, IndexError, OverflowError):
            return False
        if modified_since.tzinfo is None:
            return False

        last_modified = datetime.datetime.fromtimestamp(
            last_modified_timestamp,
            datetime.timezone.utc,
        ).replace(microsecond=0)
        return last_modified <= modified_since.astimezone(datetime.timezone.utc)

    @staticmethod
    def _if_unmodified_since_fails(value, last_modified_timestamp):
        if value is None:
            return False
        try:
            unmodified_since = email.utils.parsedate_to_datetime(value)
        except (TypeError, ValueError, IndexError, OverflowError):
            return False
        if unmodified_since.tzinfo is None:
            return False

        last_modified = datetime.datetime.fromtimestamp(
            last_modified_timestamp,
            datetime.timezone.utc,
        ).replace(microsecond=0)
        return last_modified > unmodified_since.astimezone(datetime.timezone.utc)

    @staticmethod
    def _if_range_matches(value, etag, last_modified):
        validator = value.strip()
        if validator.startswith('"'):
            return validator == etag
        return validator == last_modified

    @staticmethod
    def _format_log_values(values, limit=160):
        if not values:
            return "-"
        rendered = ", ".join(ascii(value) for value in values)
        if len(rendered) > limit:
            return rendered[: limit - 3] + "..."
        return rendered

    def _log_file_response(
        self,
        status,
        content_length,
        etag,
        content_range=None,
        start=None,
        end=None,
    ):
        transfer_id = _next_transfer_id()
        client = self._format_client_address(self.client_address)
        guard = self._resume_guard or {
            "action": "direct",
            "label": "-",
            "frontier": None,
            "requested_start": None,
            "lease": None,
            "registry": None,
            "transport_abort": False,
        }
        target = self._format_log_values(
            [self.path.partition("?")[0]],
            limit=240,
        )
        range_values = self.headers.get_all("Range", [])
        if_range_values = self.headers.get_all("If-Range", [])
        expected_body = (
            content_length
            if (
                self.command == "GET"
                and status in (200, 206)
                and content_length is not None
            )
            else 0
        )
        planned_range = self._format_planned_range(
            status=status,
            content_length=content_length,
            content_range=content_range,
            start=start,
            end=end,
        )

        if self.command == "GET" and status in (200, 206):
            self._transfer_state = {
                "id": transfer_id,
                "client": client,
                "method": self.command,
                "target": target,
                "status": status,
                "planned_range": planned_range,
                "expected_body": expected_body,
                "started_at": None,
                "resume_guard": guard["action"],
                "session": guard["label"],
                "safe_frontier": guard["frontier"],
                "guard_lease": guard["lease"],
                "guard_registry": guard["registry"],
            }
        else:
            self._transfer_state = None

        self._safe_diagnostic_log(
            "file response: ID=%s Client=%s Method=%s Target=%s "
            "Session=%s Resume-Guard=%s Transport-Abort=%s "
            "Requested-Start=%s "
            "Safe-Frontier=%s Range=%s If-Range=%s -> %d Planned=%s "
            "Content-Range=%s Content-Length=%s Expected-Body=%d ETag=%s",
            transfer_id,
            client,
            self.command,
            target,
            guard["label"],
            guard["action"],
            "yes" if guard.get("transport_abort", False) else "no",
            (
                "-"
                if guard["requested_start"] is None
                else guard["requested_start"]
            ),
            "-" if guard["frontier"] is None else guard["frontier"],
            self._format_log_values(range_values),
            self._format_log_values(if_range_values),
            status,
            planned_range,
            content_range or "-",
            "-" if content_length is None else content_length,
            expected_body,
            etag,
        )

    @staticmethod
    def _format_client_address(address):
        try:
            host = str(address[0])
            port = address[1]
        except (IndexError, TypeError):
            return "-"
        if ":" in host:
            return "[{}]:{}".format(host, port)
        return "{}:{}".format(host, port)

    @staticmethod
    def _format_planned_range(
        status,
        content_length,
        content_range,
        start,
        end,
    ):
        if content_range is not None:
            return content_range
        if status != 200 or start is None or end is None:
            return "-"
        if content_length == 0:
            return "empty/0"
        return "bytes {}-{}/{}".format(start, end, content_length)

    def _finish_file_transfer(
        self,
        outcome,
        bytes_written,
        remaining,
        error=None,
    ):
        transfer = self._transfer_state
        if transfer is None:
            return

        self._transfer_state = None
        started_at = transfer["started_at"]
        elapsed = (
            max(0.0, time.monotonic() - started_at)
            if started_at is not None
            else 0.0
        )
        error_name = "-" if error is None else type(error).__name__
        registry = transfer["guard_registry"]
        lease = transfer["guard_lease"]
        final_frontier = (
            registry.frontier_for_lease(lease)
            if registry is not None and lease is not None
            else None
        )
        self._safe_diagnostic_log(
            "file transfer: ID=%s Client=%s Method=%s Target=%s Status=%d "
            "Session=%s Resume-Guard=%s Safe-Frontier=%s "
            "Final-Frontier=%s Planned=%s Bytes-Written=%d Expected-Body=%d "
            "Remaining=%d Body-Elapsed=%.3fs Outcome=%s Error=%s",
            transfer["id"],
            transfer["client"],
            transfer["method"],
            transfer["target"],
            transfer["status"],
            transfer["session"],
            transfer["resume_guard"],
            (
                "-"
                if transfer["safe_frontier"] is None
                else transfer["safe_frontier"]
            ),
            "-" if final_frontier is None else final_frontier,
            transfer["planned_range"],
            bytes_written,
            transfer["expected_body"],
            remaining,
            elapsed,
            outcome,
            error_name,
        )

    def log_request(self, code="-", size="-"):
        """Write the normal access line without exposing download tokens."""
        command = getattr(self, "command", None)
        target = getattr(self, "path", None)
        request_version = getattr(self, "request_version", None)
        if command and target is not None and request_version:
            request_line = "{} {} {}".format(
                command,
                self._redact_request_target(target),
                request_version,
            )
        else:
            request_line = "-"

        code_value = getattr(code, "value", code)
        self.log_message(
            '"%s" %s %s',
            request_line,
            str(code_value),
            str(size),
        )

    @staticmethod
    def _redact_request_target(target):
        try:
            parts = urllib.parse.urlsplit(target)
            query_items = urllib.parse.parse_qsl(
                parts.query,
                keep_blank_values=True,
            )
            redacted_query = urllib.parse.urlencode(
                [
                    (
                        key,
                        (
                            "<redacted>"
                            if key.lower()
                            in (
                                _DOWNLOAD_SESSION_PARAMETER.lower(),
                                _DOWNLOAD_ATTEMPT_PARAMETER.lower(),
                            )
                            else value
                        ),
                    )
                    for key, value in query_items
                ],
                doseq=True,
            )
            return urllib.parse.urlunsplit(
                (
                    parts.scheme,
                    parts.netloc,
                    parts.path,
                    redacted_query,
                    parts.fragment,
                )
            )
        except (TypeError, ValueError, UnicodeError):
            return target.partition("?")[0]

    def _safe_diagnostic_log(self, message, *args):
        try:
            with _DIAGNOSTIC_LOG_LOCK:
                self.log_message(message, *args)
        except Exception:
            # Diagnostics must never interrupt an otherwise valid response.
            pass

    def list_directory(self, path):
        """Render a safe directory index with one on-demand media player."""
        try:
            names = os.listdir(path)
        except OSError:
            self.send_error(404, "No permission to list directory")
            return None

        names.sort(key=lambda name: name.lower())
        request_path = urllib.parse.urlsplit(self.path).path
        download_registry = getattr(self.server, "download_sessions", None)
        try:
            display_path = urllib.parse.unquote(
                request_path,
                errors="surrogatepass",
            )
        except UnicodeDecodeError:
            display_path = urllib.parse.unquote(request_path)

        encoding = sys.getfilesystemencoding()
        title = "Directory listing for {}".format(display_path)
        escaped_title = html.escape(title, quote=False)
        escaped_encoding = html.escape(encoding, quote=True)
        page = [
            "<!DOCTYPE html>",
            '<html lang="en">',
            "<head>",
            '<meta charset="{}">'.format(escaped_encoding),
            '<meta name="viewport" content="width=device-width, initial-scale=1">',
            "<title>{}</title>".format(escaped_title),
            "<style>{}</style>".format(_DIRECTORY_STYLE),
            "</head>",
            "<body>",
            "<main>",
            "<header>",
            "<h1>{}</h1>".format(escaped_title),
            (
                '<p class="hint">Select a filename to download it, or use Play '
                "for recognized audio and video files. If a browser cannot "
                "resume safely, this page offers a clean restart.</p>"
            ),
            "</header>",
            (
                '<section id="download-status" '
                'class="download-status visually-hidden">'
            ),
            (
                '<p id="download-status-message" role="status" '
                'aria-live="polite" aria-atomic="true"></p>'
            ),
            '<p id="download-status-alert" role="alert" hidden></p>',
            '<p id="download-status-progress" aria-live="off"></p>',
            (
                '<form id="download-retry" class="download-form" '
                'method="post" hidden>'
            ),
            (
                '<button id="download-retry-button" class="download-again" '
                'type="submit">Download again from the beginning</button>'
            ),
            "</form>",
            "</section>",
            (
                '<section id="media-panel" class="media-panel" '
                'aria-labelledby="media-title" tabindex="-1" hidden>'
            ),
            '<div class="media-toolbar">',
            '<h2 id="media-title">Media player</h2>',
            '<nav class="media-actions" aria-label="Selected media actions">',
            '<a id="media-open" href="">Open directly</a>',
            (
                '<form id="media-download-form" class="download-form" '
                'method="post">'
            ),
            (
                '<button id="media-download" class="media-download-button" '
                'type="submit">Download</button>'
            ),
            "</form>",
            "</nav>",
            "</div>",
            (
                '<video id="video-player" controls playsinline '
                'preload="metadata" hidden></video>'
            ),
            '<audio id="audio-player" controls preload="metadata" hidden></audio>',
            '<p id="media-error" class="media-error" role="alert" hidden></p>',
            "</section>",
            '<div class="file-table-wrap">',
            '<table class="file-table">',
            '<caption class="visually-hidden">Directory entries</caption>',
            "<thead>",
            "<tr>",
            '<th class="name-column" scope="col">Name</th>',
            '<th class="size-column" scope="col">Size</th>',
            '<th class="type-column" scope="col">Type</th>',
            '<th class="play-column" scope="col">Play</th>',
            "</tr>",
            "</thead>",
            "<tbody>",
        ]

        if request_path.rstrip("/"):
            page.append(
                (
                    '<tr><td colspan="4"><a class="file-link" href="../">'
                    "../ Parent directory</a></td></tr>"
                )
            )

        for name in names:
            full_name = os.path.join(path, name)
            display_name = link_name = name
            is_directory = os.path.isdir(full_name)
            is_regular_file = not is_directory and os.path.isfile(full_name)
            listed_status = None

            if is_regular_file:
                try:
                    with open(full_name, "rb") as listed_source:
                        candidate_status = os.fstat(listed_source.fileno())
                    if stat.S_ISREG(candidate_status.st_mode):
                        listed_status = candidate_status
                except OSError:
                    pass

            if is_directory:
                display_name = name + "/"
                link_name = name + "/"
            if os.path.islink(full_name):
                display_name = display_name + "@"

            quoted_url = urllib.parse.quote(
                link_name,
                errors="surrogatepass",
            )
            escaped_url = html.escape(quoted_url, quote=True)
            escaped_name = html.escape(display_name, quote=False)
            escaped_name_attribute = html.escape(display_name, quote=True)

            if is_directory:
                entry_type = "Directory"
            elif is_regular_file:
                entry_type = self.guess_type(full_name)
            else:
                entry_type = "Other"

            media_kind = None
            if is_regular_file:
                candidate_kind = entry_type.partition("/")[0]
                if candidate_kind in ("audio", "video"):
                    media_kind = candidate_kind

            escaped_type_text = html.escape(entry_type, quote=False)
            escaped_type_attribute = html.escape(entry_type, quote=True)
            if listed_status is not None:
                file_size = listed_status.st_size
                exact_size = "{:,} {}".format(
                    file_size,
                    "byte" if file_size == 1 else "bytes",
                )
                size_cell = (
                    '<td class="size-column" title="{exact}">'
                    '<span aria-hidden="true">{display}</span>'
                    '<span class="visually-hidden">{exact}</span>'
                    "</td>"
                ).format(
                    exact=exact_size,
                    display=_format_file_size(file_size),
                )
            else:
                unavailable_label = (
                    "Size unavailable"
                    if is_regular_file
                    else "Not applicable"
                )
                size_cell = (
                    '<td class="size-column size-unavailable">'
                    '<span aria-hidden="true">&mdash;</span>'
                    '<span class="visually-hidden">{}</span>'
                    "</td>"
                ).format(unavailable_label)

            escaped_download_url = None
            escaped_status_url = None
            escaped_download_attempt = None
            if (
                is_regular_file
                and listed_status is not None
                and download_registry is not None
            ):
                download_attempt = download_registry.issue_attempt(
                    canonical_path=os.path.normcase(
                        os.path.realpath(full_name)
                    ),
                    etag=self._make_etag(listed_status),
                    file_size=listed_status.st_size,
                )
                escaped_download_attempt = html.escape(
                    download_attempt,
                    quote=True,
                )
                download_url = "{}?{}".format(
                    quoted_url,
                    urllib.parse.urlencode(
                        (
                            ("download", "start"),
                            (
                                _DOWNLOAD_ATTEMPT_PARAMETER,
                                download_attempt,
                            ),
                        )
                    ),
                )
                status_url = "{}?{}".format(
                    quoted_url,
                    urllib.parse.urlencode(
                        (
                            ("download", "status"),
                            (
                                _DOWNLOAD_ATTEMPT_PARAMETER,
                                download_attempt,
                            ),
                        )
                    ),
                )
                escaped_download_url = html.escape(
                    download_url,
                    quote=True,
                )
                escaped_status_url = html.escape(
                    status_url,
                    quote=True,
                )
                name_cell = (
                    '<form class="download-form" method="post" '
                    'action="{url}" data-download-attempt="{attempt}" '
                    'data-download-name="{name_attribute}" '
                    'data-status-url="{status_url}">'
                    '<button class="file-link" type="submit">{name}</button>'
                    "</form>"
                ).format(
                    url=escaped_download_url,
                    attempt=escaped_download_attempt,
                    name_attribute=escaped_name_attribute,
                    status_url=escaped_status_url,
                    name=escaped_name,
                )
            elif is_regular_file:
                direct_download_url = "{}?download=1".format(quoted_url)
                name_cell = (
                    '<a class="file-link" href="{url}" download>{name}</a>'
                ).format(
                    url=html.escape(direct_download_url, quote=True),
                    name=escaped_name,
                )
            else:
                name_cell = '<a class="file-link" href="{url}">{name}</a>'.format(
                    url=escaped_url,
                    name=escaped_name,
                )

            if media_kind:
                if escaped_download_url is not None:
                    download_data = (
                        ' data-download-url="{download_url}"'
                        ' data-download-status-url="{status_url}"'
                        ' data-download-attempt="{attempt}"'
                        ' data-download-name="{name_attribute}"'
                    ).format(
                        download_url=escaped_download_url,
                        status_url=escaped_status_url,
                        attempt=escaped_download_attempt,
                        name_attribute=escaped_name_attribute,
                    )
                else:
                    download_data = ""
                play_cell = (
                    '<a class="play-link" href="{url}" '
                    'data-media-kind="{kind}" data-media-type="{type}"'
                    "{download_data}>"
                    '<span class="play-icon" aria-hidden="true">&#9654;</span>'
                    '<span class="visually-hidden">Play {name} inline</span>'
                    "</a>"
                ).format(
                    url=escaped_url,
                    kind=media_kind,
                    type=escaped_type_attribute,
                    download_data=download_data,
                    name=escaped_name,
                )
            else:
                play_cell = (
                    '<span class="play-unavailable" '
                    'aria-hidden="true">&mdash;</span>'
                )

            page.append(
                (
                    "<tr>"
                    '<td class="name-column">{name_cell}</td>'
                    "{size_cell}"
                    '<td class="type-column">'
                    '<span class="file-kind">{type}</span></td>'
                    '<td class="play-column">{play_cell}</td>'
                    "</tr>"
                ).format(
                    name_cell=name_cell,
                    size_cell=size_cell,
                    type=escaped_type_text,
                    play_cell=play_cell,
                )
            )

        if not names:
            page.append(
                (
                    '<tr><td class="empty" colspan="4">'
                    "This directory is empty.</td></tr>"
                )
            )

        page.extend(
            [
                "</tbody>",
                "</table>",
                "</div>",
                "</main>",
                "<script>{}</script>".format(_DIRECTORY_SCRIPT),
                "</body>",
                "</html>",
            ]
        )
        encoded = "\n".join(page).encode(encoding, "surrogateescape")
        response = io.BytesIO(encoded)
        self.send_response(200)
        self.send_header(
            "Content-Type",
            "text/html; charset={}".format(encoding),
        )
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header(
            "Content-Security-Policy",
            "default-src 'none'; media-src 'self'; style-src 'unsafe-inline'; "
            "script-src 'unsafe-inline'; connect-src 'self'; "
            "form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
        )
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        return response

    @staticmethod
    def _parse_byte_range(value, file_size):
        match = _BYTE_RANGE.fullmatch(value)
        if match is None:
            return None

        first, last = match.groups()
        if not first and not last:
            return None
        if file_size == 0:
            raise _RangeNotSatisfiable

        if first:
            start = _parse_range_integer(first)
            end = (
                _parse_range_integer(last)
                if last
                else file_size - 1
            )
            if start is None or end is None:
                return None
            if start >= file_size or end < start:
                raise _RangeNotSatisfiable
            return start, min(end, file_size - 1)

        suffix_length = _parse_range_integer(last)
        if suffix_length is None:
            return None
        if suffix_length == 0:
            raise _RangeNotSatisfiable
        return max(file_size - suffix_length, 0), file_size - 1


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Serve files with single byte-range support and media-aware "
            "directory listings."
        ),
    )
    parser.add_argument(
        "-b",
        "--bind",
        metavar="ADDRESS",
        help="bind to this address (default: all interfaces)",
    )
    parser.add_argument(
        "-d",
        "--directory",
        default=os.getcwd(),
        help="serve this directory (default: current directory)",
    )
    parser.add_argument("port", default=8000, type=int, nargs="?")
    args = parser.parse_args()

    handler = functools.partial(
        RangeRequestHandler,
        directory=args.directory,
    )
    address = args.bind or ""

    with GuardedThreadingHTTPServer((address, args.port), handler) as server:
        display_address = args.bind or "0.0.0.0"
        print(
            "Serving media-aware HTTP with byte-range support on {} port {} "
            "(http://{}:{}/) ...".format(
                display_address,
                args.port,
                display_address,
                args.port,
            )
        )
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
