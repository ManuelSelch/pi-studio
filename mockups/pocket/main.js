const $ = (id) => document.getElementById(id);
const previewState = new URLSearchParams(location.search).get("state") || "populated";
let connected = previewState !== "disconnected";
let selected = null;
const expanded = new Set(["quick", "studio"]);
const drafts = new Map();
let counter = 0;
const projects = [
  { id: "quick", name: "Quick Chats", quick: true, sessions: [
    { id: "q1", title: "Plan the weekend", detail: "Yesterday", messages: [["You", "Help me plan a quiet weekend."], ["Pi", "We could start with a walk on Saturday morning and keep Sunday free. What would you like to make time for?"]] }
  ] },
  { id: "studio", name: "pi-studio", sessions: [
    { id: "s1", title: "Pocket project navigation", detail: "⑂ feat/pocket", running: true, messages: [["You", "Implement the project and session browser."], ["Pi", "I’m checking the existing SDK catalogue and session-opening behavior."]] },
    { id: "s2", title: "Shared session UI", detail: "⑂ main · Yesterday", messages: [["You", "What is already shared between Mac and iPhone?"], ["Pi", "The session UI, Flux state and SDK-facing controller are shared. The platform shells own lifecycle."]] }
  ] },
  { id: "lab", name: "homelab-pulse", sessions: [
    { id: "l1", title: "Review dependency report", detail: "2 days ago", messages: [["You", "Summarize the latest dependency report."], ["Pi", "There are two updates to review. No new critical vulnerabilities were found."]] }
  ] }
];
if (previewState === "empty") projects.splice(1), projects[0].sessions = [];
const icons = {
  quick: '<svg class="project-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="M20 11a8 8 0 0 1-8 8H5l-4 3 2-7a8 8 0 1 1 17-4Z"/></svg>',
  folder: '<svg class="project-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="M3 6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1Z"/></svg>'
};
function text(tag, className, content) {
  const el = document.createElement(tag); el.className = className; el.textContent = content; return el;
}
function showError(message = "") { $("error").hidden = !message; $("error").textContent = message; }
function emptyState(title, description, action, callback) {
  const el = document.createElement("div"); el.className = "empty";
  el.append(text("h2", "", title), text("p", "", description));
  if (action) { const b = text("button", "primary", action); b.onclick = callback; el.append(b); }
  return el;
}
function renderCatalogue() {
  $("catalogue").replaceChildren();
  if (!connected) {
    $("catalogue").append(emptyState("Your agents, on your server", "Connect to browse projects and pick up a conversation.", "Connect", connect)); return;
  }
  if (previewState === "loading") {
    $("catalogue").append(emptyState("Loading projects…", "Waiting for the server’s catalogue.")); return;
  }
  if (previewState === "error") {
    $("catalogue").append(emptyState("Projects couldn’t be loaded", "Your server connection is still open. Try loading the catalogue again.", "Retry", () => { location.search = ""; })); return;
  }
  for (const project of projects) {
    const group = document.createElement("section");
    group.className = "group" + (project.quick ? " quick" : "");
    const row = document.createElement("div"); row.className = "project-row";
    const toggle = document.createElement("button"); toggle.className = "project-toggle";
    toggle.setAttribute("aria-expanded", expanded.has(project.id));
    toggle.innerHTML = icons[project.quick ? "quick" : "folder"];
    toggle.append(text("span", "project-name", project.name), text("span", "chevron", "›"));
    toggle.onclick = () => { expanded.has(project.id) ? expanded.delete(project.id) : expanded.add(project.id); renderCatalogue(); };
    const add = text("button", "new-session", "+");
    add.setAttribute("aria-label", project.quick ? "New chat" : "New session in " + project.name);
    add.onclick = () => {
      const session = { id: "new-" + ++counter, title: project.quick ? "New chat" : "New session", detail: "Just now", messages: [] };
      project.sessions.unshift(session); expanded.add(project.id); openSession(project, session);
    };
    row.append(toggle, add); group.append(row);
    if (expanded.has(project.id)) {
      for (const session of project.sessions) {
        const b = document.createElement("button"); b.className = "session-row";
        const copy = document.createElement("span"); copy.className = "session-copy";
        copy.append(text("span", "session-title", session.title), text("span", "session-detail", session.detail));
        b.append(copy);
        if (session.running) {
          b.append(text("span", "activity", ""), text("span", "running-label", "Running"));
        }
        b.onclick = () => {
          if (previewState === "open-error") { showError("Couldn’t open this session. No new session was created. Please try again."); return; }
          openSession(project, session);
        };
        group.append(b);
      }
      if (!project.sessions.length) group.append(text("p", "group-empty", "No chats yet. Tap + to start one."));
    }
    $("catalogue").append(group);
  }
}
function updateHeader() {
  $("title").textContent = selected ? selected.session.title : "";
  $("title").hidden = !selected;
  $("connection-status").textContent = selected ? selected.project.name + " · " + (selected.session.running ? "Running" : "Idle") : (connected ? "Connected" : "Disconnected");
  $("connection").textContent = connected ? "Disconnect" : "Connect";
  $("back").hidden = !selected;
  $("catalogue").hidden = !!selected;
  $("conversation").hidden = !selected;
}
function renderConversation() {
  $("transcript").replaceChildren();
  const s = selected.session;
  if (!s.messages.length) $("transcript").append(emptyState("Start a conversation", "This session uses the server’s " + (selected.project.quick ? "home folder." : "project folder.")));
  for (const [role, content] of s.messages) {
    const turn = document.createElement("div"); turn.className = "turn";
    turn.append(text("strong", "", role), text("p", "", content)); $("transcript").append(turn);
  }
  $("message").value = drafts.get(s.id) || "";
  $("message").disabled = !!s.running;
  $("message").placeholder = s.running ? "Agent is running…" : "Message Pi…";
  $("send").disabled = !!s.running || !$("message").value.trim();
  $("stop").hidden = !s.running;
  $("run-state").textContent = s.running ? "Agent running" : "Idle";
}
function openSession(project, session) {
  showError(); selected = {project, session}; updateHeader(); renderConversation();
}
function connect() {
  if (!confirm("Connect and take control here? Another client may be disconnected.")) return;
  connected = true; showError(); updateHeader(); renderCatalogue();
}
$("connection").onclick = () => {
  if (!connected) return connect();
  if (projects.some(p => p.sessions.some(s => s.running)) && !confirm("Disconnect? Agents continue running on the server.")) return;
  connected = false; selected = null; showError(); updateHeader(); renderCatalogue();
};
$("back").onclick = () => { selected = null; showError(); updateHeader(); renderCatalogue(); };
$("message").oninput = () => { drafts.set(selected.session.id, $("message").value); $("send").disabled = !$("message").value.trim(); };
$("composer").onsubmit = (event) => {
  event.preventDefault(); const value = $("message").value.trim(); if (!value || selected.session.running) return;
  selected.session.messages.push(["You", value], ["Pi", "This is a simulated reply. Production will stream the real server response."]);
  drafts.delete(selected.session.id); renderConversation();
};
$("stop").onclick = () => { selected.session.running = false; updateHeader(); renderConversation(); };
updateHeader(); renderCatalogue();
