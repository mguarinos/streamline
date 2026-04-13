const POLL_INTERVAL_MS = 15000;

const badgeEl = document.getElementById('status-badge');
const badgeLabel = badgeEl.querySelector('.badge__label');
const playerWrap = document.getElementById('player-wrap');
const playerContainer = document.getElementById('player-container');
const dvrHintEl = document.getElementById('dvr-hint');
const offlineEl = document.getElementById('offline-message');
const autoplayBlockEl = document.getElementById('autoplay-blocked');
const unmuteBtn = document.getElementById('unmute-btn');

let player = null;

function setBadge(state) {
  badgeEl.className = `badge badge--${state}`;
  badgeLabel.textContent = state.toUpperCase();
}

function initPlayer(playbackUrl) {
  player = videojs('player', {
    sources: [{ src: playbackUrl, type: 'application/x-mpegURL' }],
    autoplay: true,
    muted: true,
    controls: true,
    liveui: true,
    liveTracker: { trackingThreshold: 0, liveTolerance: 15 },
    html5: { vhs: { overrideNative: true } }
  });

  player.qualityLevels();
  player.hlsQualitySelector({ displayCurrentQuality: true });

  player.on('autoplay-failure', () => autoplayBlockEl.classList.remove('hidden'));

  unmuteBtn.onclick = () => {
    player.muted(false);
    player.play();
    autoplayBlockEl.classList.add('hidden');
  };
}

function disposePlayer() {
  if (!player) return;
  player.dispose();
  player = null;
  autoplayBlockEl.classList.add('hidden');

  const video = document.createElement('video');
  video.id = 'player';
  video.className = 'video-js vjs-big-play-centered';
  playerContainer.prepend(video);
}

async function fetchAndUpdate() {
  try {
    const res = await fetch('/api/stream');
    if (!res.ok) throw new Error();
    const data = await res.json();

    if (data.status === 'live') {
      if (!player) initPlayer(data.playbackUrl);
      playerWrap.classList.remove('hidden');
      offlineEl.classList.add('hidden');
      setBadge('live');
      if (data.dvr?.enabled) dvrHintEl.classList.add('visible');
      return;
    }
  } catch (e) {
    setBadge('connecting');
    return;
  }

  disposePlayer();
  playerWrap.classList.add('hidden');
  setBadge('offline');
  offlineEl.classList.remove('hidden');
}

setBadge('connecting');
fetchAndUpdate();
setInterval(fetchAndUpdate, POLL_INTERVAL_MS);