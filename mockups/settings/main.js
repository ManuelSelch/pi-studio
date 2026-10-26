const $ = (id) => document.getElementById(id);
const dialog = document.querySelector("dialog");
let saved = "ws://127.0.0.1:8787/ws";
let active = null;
function render() {
  $("status").textContent = active ? "Ready" : "Disconnected";
  $("connect").textContent = active ? "Disconnect" : "Connect";
  $("endpoint").textContent = active && active !== saved ? active + " · Next connection: " + saved : active ?? saved;
}
function open() {
  $("url").value = saved;
  $("error").hidden = true;
  dialog.showModal();
}
$("open").onclick = open;
$("cancel").onclick = () => dialog.close();
$("connect").onclick = () => { active = active ? null : saved; render(); };
$("form").onsubmit = (event) => {
  event.preventDefault();
  const value = $("url").value.trim();
  try {
    const url = new URL(value);
    if (!["ws:", "wss:"].includes(url.protocol) || !url.hostname || url.username || url.password || url.hash) throw Error();
    saved = value;
    dialog.close();
    render();
  } catch {
    $("error").textContent = "Enter a valid ws:// or wss:// URL with a host, without credentials or a fragment.";
    $("error").hidden = false;
  }
};
render();
open();
