import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { MantineProvider, createTheme, Button, TextInput } from "@mantine/core";
import { IconSearch, IconFolder, IconGitBranch, IconMessageCircle, IconCommand } from "@tabler/icons-react";
import { Agentation } from "agentation";
import "@mantine/core/styles.css";
import "./styles.css";

type Kind = "Folders" | "Worktrees" | "Sessions" | "Actions";
type Item = { kind: Kind; title: string; detail: string; status?: string };
const items: Item[] = [
  { kind: "Sessions", title: "Build the quick switcher", detail: "pi-studio · feat/quickswitcher · Just now", status: "running" },
  { kind: "Sessions", title: "Review workspace layout", detail: "pi-studio · main · 2 hours ago", status: "ready" },
  { kind: "Sessions", title: "Plan next steps", detail: "Quick Chats · Yesterday", status: "needs" },
  { kind: "Folders", title: "pi-studio", detail: "New session · ~/Projects/pi-studio" },
  { kind: "Folders", title: "Quick Chats", detail: "New session · ~/" },
  { kind: "Worktrees", title: "feat/quickswitcher", detail: "New session · pi-studio · ~/.worktrees/pi-studio/feat-quickswitcher" },
  { kind: "Worktrees", title: "feat/layout", detail: "New session · pi-studio · ~/.worktrees/pi-studio/feat-layout" },
];
const scopes = [{ label: "All", prefix: "" }, { label: "Folders", prefix: "#" }, { label: "Worktrees", prefix: "%" }, { label: "Sessions", prefix: "@" }, { label: "Actions", prefix: "/" }] as const;
function App() {
  const [open, setOpen] = useState(false);
  const [screen, setScreen] = useState<"Home" | "Session">("Home");
  const [query, setQuery] = useState("");
  const [active, setActive] = useState(0);
  const [notice, setNotice] = useState("");
  const input = useRef<HTMLInputElement>(null);
  const scope = scopes.find(s => s.prefix && query.startsWith(s.prefix)) ?? scopes[0];
  const term = (scope.prefix ? query.slice(1) : query).trim().toLowerCase();
  const results = items.filter(i => (scope.label === "All" ? term ? true : i.kind === "Sessions" : i.kind === scope.label) && (!term || (i.title + " " + i.detail).toLowerCase().includes(term)));
  const show = () => { setQuery(""); setActive(0); setOpen(true); };
  useEffect(() => {
    const key = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && ["k", "o"].includes(event.key.toLowerCase())) { event.preventDefault(); show(); }
      if (event.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, []);
  useEffect(() => { if (open) input.current?.focus(); }, [open]);
  const choose = (item: Item) => { setOpen(false); setNotice(item.kind === "Sessions" ? "Opened session: " + item.title : "Created a new session in " + item.title); setScreen("Session"); };
  const switcher = <section className={"dialog " + (screen === "Home" ? "inline-dialog" : "")} role={screen === "Home" ? "search" : "dialog"} aria-label="Quick switcher">
      <div className="search"><IconSearch size={21}/><TextInput ref={input} variant="unstyled" placeholder="Search folders, worktrees, sessions and actions…" value={query} onChange={e => { setQuery(e.currentTarget.value); setActive(0); }} onKeyDown={e => {
        if (e.key === "Tab") { e.preventDefault(); const index = scopes.indexOf(scope); const next = scopes[(index + (e.shiftKey ? -1 : 1) + scopes.length) % scopes.length]; setQuery(next.prefix + term); setActive(0); }
        if (e.key === "ArrowDown" || e.key === "ArrowUp") { e.preventDefault(); if (results.length) setActive((active + (e.key === "ArrowDown" ? 1 : -1) + results.length) % results.length); }
        if (e.key === "Enter" && results[Math.min(active, results.length - 1)]) choose(results[Math.min(active, results.length - 1)]);
      }}/><kbd>esc</kbd></div>
      <div className="filters">{scopes.map(s => <button key={s.label} className={s.label === scope.label ? "on" : ""} onClick={() => { setQuery(s.prefix); setActive(0); input.current?.focus(); }}>{s.prefix && <span>{s.prefix} </span>}{s.label}</button>)}</div>
      <div className="result-label">{scope.label === "All" && !term ? "RECENT SESSIONS" : scope.label.toUpperCase()}</div>
      <div className="results">{results.length ? results.map((item, i) => <button key={item.title} className={"result " + (i === Math.min(active, results.length - 1) ? "active" : "")} onMouseEnter={() => setActive(i)} onClick={() => choose(item)}><div className="icon">{item.kind === "Folders" ? <IconFolder size={19}/> : item.kind === "Worktrees" ? <IconGitBranch size={19}/> : <IconMessageCircle size={19}/>}</div><div className="copy"><strong>{item.title}</strong><small>{item.detail}</small></div>{item.status && <span className={"status " + item.status}/>}</button>) : <div className="empty">{scope.label === "Actions" && !term ? "No actions available yet." : "No matching results."}</div>}</div>
      <footer><span><kbd>Tab</kbd> filters</span><span><kbd>↑</kbd><kbd>↓</kbd> navigate</span><span><kbd>↵</kbd> open</span><span className="footer-end"><IconCommand size={13}/> K / O</span></footer>
    </section>;
  return <div className="app">
    <aside><div className="brand">π <span>Pi Studio</span></div><div className="nav selected">⌂ &nbsp; Home</div><div className="caption">WORKSPACE</div><div className="nav">◉ &nbsp; Quick Chats</div><div className="caption">PROJECTS</div><div className="nav">▾ &nbsp; pi-studio</div><div className="sub">feat/quickswitcher</div><div className="sub">Review workspace layout</div><div className="bottom">● &nbsp; Connected</div></aside>
    <main><header><span>{screen}</span><div><Button size="xs" variant="subtle" onClick={() => { setOpen(false); setScreen(screen === "Home" ? "Session" : "Home"); }}>Preview {screen === "Home" ? "session" : "home"}</Button><Button size="xs" variant="light" onClick={show}>Open switcher &nbsp; ⌘ K</Button></div></header>
      {screen === "Home" ? <div className="home"><h1>Let's cook</h1><div className="home-switcher">{open ? switcher : <button className="home-search" onClick={show}><IconSearch size={19}/> Search or start a conversation… <kbd>⌘ K</kbd></button>}</div></div> : <div className="conversation"><h2>Build the quick switcher</h2><p>Let's make switching between sessions and projects feel effortless.</p><div className="composer">Message Pi…</div></div>}
      {notice && <div className="notice" onClick={() => setNotice("")}>{notice} ×</div>}
    </main>
    {open && screen === "Session" && <div className="backdrop" onMouseDown={e => { if (e.target === e.currentTarget) setOpen(false); }}>{switcher}</div>}
  </div>;
}
createRoot(document.getElementById("root")!).render(<MantineProvider theme={createTheme({fontFamily:"-apple-system, BlinkMacSystemFont, sans-serif", primaryColor:"violet", defaultRadius:"md"})}><App/>{import.meta.env.DEV && <Agentation/>}</MantineProvider>);