const field = document.querySelector('#message');
const send = document.querySelector('#send');
const platform = document.querySelector('#platform');
const state = document.querySelector('#state');
const params = new URLSearchParams(location.search);
platform.value = params.get('platform') === 'ios' ? 'ios' : 'mac';
if (['ready', 'pending', 'error'].includes(params.get('state'))) state.value = params.get('state');
function update() {
  field.disabled = state.value === 'pending';
  send.disabled = field.disabled || !field.value.trim();
  field.style.height = 'auto';
  field.style.height = Math.min(134, Math.max(68, field.scrollHeight + 2)) + 'px';
  document.querySelector('#keyboard-hint').textContent = platform.value === 'mac'
    ? 'Enter to send · Shift+Enter for a new line'
    : 'Enter for a new line · Tap Send to submit';
  document.querySelector('#status').textContent = state.value === 'pending' ? 'Generating…' : 'Ready';
  document.querySelector('#hint').textContent = state.value === 'pending'
    ? 'Partial text stays visible.' : state.value === 'error' ? 'Send rejected. Draft retained.' : 'One message at a time.';
}
field.addEventListener('input', update);
platform.addEventListener('change', update);
state.addEventListener('change', update);
document.querySelector('#composer').addEventListener('submit', event => {
  event.preventDefault();
  if (send.disabled) return;
  if (state.value === 'error') return;
  const turn = document.createElement('div');
  turn.className = 'turn';
  const label = document.createElement('strong'); label.textContent = 'You';
  const body = document.createElement('p'); body.textContent = field.value;
  turn.append(label, body);
  document.querySelector('.empty')?.remove();
  document.querySelector('#transcript').append(turn);
  field.value = '';
  update(); field.focus();
});
field.addEventListener('keydown', event => {
  if (platform.value === 'mac' && event.key === 'Enter' && !event.shiftKey
      && !event.altKey && !event.ctrlKey && !event.metaKey && !event.isComposing) {
    event.preventDefault();
    if (!event.repeat && !send.disabled) document.querySelector('#composer').requestSubmit();
  }
});
update();
