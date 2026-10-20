const $ = (id) => document.getElementById(id);
const labels = { disconnected: 'Disconnected', connecting: 'Connecting…', ready: 'Ready', generating: 'Generating…', stopping: 'Stopping…', error: 'Connection failed', unknown: 'Outcome unknown' };
let state = new URLSearchParams(location.search).get('state') || 'disconnected';
if (!(state in labels)) state = 'disconnected';
let messages = [];
let draft = '';
let timers = [];
function clearTimers() { timers.forEach(clearTimeout); timers = []; }
function later(fn, ms) { timers.push(setTimeout(fn, ms)); }
function add(role, text) { messages.push({ role, text }); }
function render() {
  const active = ['generating', 'stopping'].includes(state);
  $('status').textContent = labels[state];
  $('connection').textContent = ['ready', 'generating', 'stopping', 'connecting'].includes(state) ? 'Disconnect' : 'Connect';
  $('message').disabled = state !== 'ready';
  $('message').value = draft;
  $('send').disabled = state !== 'ready' || !draft.trim();
  $('stop').disabled = state !== 'generating';
  $('hint').textContent = active ? 'Partial text stays visible.' : state === 'ready' ? 'One message at a time.' : state === 'connecting' ? 'Initializing and creating the demo…' : 'Connect to start a fresh demo.';
  $('error').hidden = !['error', 'unknown'].includes(state);
  $('error').textContent = state === 'unknown' ? 'The send outcome is unknown. Server work may continue. Your draft is retained; it will not be resent automatically.' : 'Could not connect to Pi Server. Check that the local server is running.';
  const transcript = $('transcript');
  transcript.replaceChildren();
  if (!messages.length) {
    const empty = document.createElement('p'); empty.className = 'empty';
    empty.textContent = state === 'ready' ? 'Demo ready. Send a message to begin.' : 'Your demo conversation will appear here.';
    transcript.append(empty);
  }
  for (const message of messages) {
    const article = document.createElement('article'); article.className = 'turn';
    const role = document.createElement('strong'); role.textContent = message.role;
    const text = document.createElement('p'); text.textContent = message.text;
    article.append(role, text); transcript.append(article);
  }
  transcript.scrollTop = transcript.scrollHeight;
  $('review-state').value = state;
}
function preview(next) {
  clearTimers(); state = next; messages = []; draft = '';
  if (['generating', 'stopping'].includes(state)) { add('You', 'Say hello'); add('Assistant', 'Hello! This text is arriving a little at a time…'); }
  if (state === 'unknown') { add('You', 'Say hello'); add('Assistant', 'Hello!'); draft = 'Tell me more'; }
  render();
}
$('message').addEventListener('input', (event) => { draft = event.target.value; $('send').disabled = state !== 'ready' || !draft.trim(); });
$('connection').addEventListener('click', () => {
  if (['ready', 'generating', 'stopping', 'connecting'].includes(state)) {
    if (['generating', 'stopping'].includes(state) && !confirm('Disconnect? Server work may continue. This does not stop or close the session.')) return;
    clearTimers(); state = 'disconnected'; render(); return;
  }
  if (!confirm('Connect and take control? This replaces any current server controller and creates a fresh demo session.')) return;
  preview('connecting'); later(() => { state = 'ready'; render(); }, 900);
});
$('composer').addEventListener('submit', (event) => {
  event.preventDefault(); if (state !== 'ready' || !draft.trim()) return;
  add('You', draft.trim()); draft = ''; add('Assistant', ''); state = 'generating'; render();
  const answer = 'Hello! This is a simple streaming reply from the demo session. You can send another message after this finishes, or press Stop to keep the partial answer.';
  const words = answer.split(' ');
  words.forEach((word, index) => later(() => { messages.at(-1).text += (index ? ' ' : '') + word; render(); }, (index + 1) * 130));
  later(() => { state = 'ready'; render(); }, (words.length + 1) * 130);
});
$('stop').addEventListener('click', () => {
  if (state !== 'generating') return;
  clearTimers(); state = 'stopping'; render(); later(() => { state = 'ready'; render(); }, 700);
});
$('review-state').addEventListener('change', (event) => {
  const url = new URL(location.href); url.searchParams.set('state', event.target.value); history.replaceState(null, '', url);
  preview(event.target.value);
});
preview(state);
