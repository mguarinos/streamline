/**
 * player.js — Streamline frontend (ES module)
 *
 * DVR behaviour:
 *   IVS generates HLS manifests with a DVR window when the channel
 *   has DVR enabled. The Video.js VHS engine reads this window from
 *   the manifest and automatically makes the full timeline seekable.
 *   The viewer can drag the progress bar left to rewind up to 4 hours.
 *   Clicking the live button snaps back to the live edge. No special
 *   URL parameters or player config required beyond liveui: true.
 */

const POLL_INTERVAL_MS = 15_000;

const badgeEl          = document.getElementById('status-badge');
const playerContainer  = document.getElementById('player-container');
const dvrHintEl        = document.getElementById('dvr-hint');
const offlineEl        = document.getElementById('offline-message');

/** @type {import('video.js').VideoJsPlayer | null} */
let player = null;
let pollInterval = null;

// ── Badge helpers ─────────────────────────────────────────────

function setBadge(state) {
  badgeEl.className = `badge badge--${state}`;
  badgeEl.textContent = state.toUpperCase();
}

// ── Player lifecycle ──────────────────────────────────────────

function initPlayer(playbackUrl) {
  player = videojs('player', {
    sources: [{ src: playbackUrl, type: 'application/x-mpegURL' }],
    autoplay: true,
    muted: true,
    controls: true,
    liveui: true,
    liveTracker: {
      trackingThreshold: 0,
      liveTolerance: 15,
    },
    html5: {
      vhs: {
        overrideNative: true,
        enableLowInitialPlaylist: true,
        handleManifestRedirects: true,
        // DVR: VHS automatically reads the seekable window from
        // the IVS-generated HLS manifest. No extra config needed.
      },
    },
    fluid: false,
    responsive: false,
  });
}

function disposePlayer() {
  if (!player) return;
  player.dispose();
  player = null;

  // dispose() removes the <video> element from the DOM; recreate it
  // so a subsequent initPlayer() has a target element to attach to.
  const video = document.createElement('video');
  video.id = 'player';
  video.className = 'video-js';
  playerContainer.appendChild(video);
}

// ── Poll logic ────────────────────────────────────────────────

async function fetchAndUpdate() {
  let data;

  try {
    const res = await fetch('/api/stream');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data = await res.json();
  } catch {
    // Transient network error — keep a running player alive, just
    // show CONNECTING so the viewer knows the status is uncertain.
    setBadge('connecting');
    return;
  }

  const { playbackUrl, status, dvr } = data;

  if (status === 'live') {
    if (!player) {
      // First transition to live — initialise the player.
      initPlayer(playbackUrl);
    }
    // Update badge and DVR hint on every successful live poll, not just
    // on init. This handles recovery from a transient CONNECTING state
    // where the player kept running but the badge was set to CONNECTING.
    playerContainer.classList.remove('hidden');
    setBadge('live');
    if (dvr?.enabled) {
      dvrHintEl.classList.add('visible');
    }
    offlineEl.classList.remove('visible');
    return;
  }

  // status === 'idle'
  disposePlayer();
  playerContainer.classList.add('hidden');
  dvrHintEl.classList.remove('visible');
  setBadge('offline');
  offlineEl.classList.add('visible');
}

// ── Boot ──────────────────────────────────────────────────────

setBadge('connecting');
fetchAndUpdate();
pollInterval = setInterval(fetchAndUpdate, POLL_INTERVAL_MS);
