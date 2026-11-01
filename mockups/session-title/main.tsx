import React, { useState } from "react";
import { Agentation } from "agentation";
import { createRoot } from "react-dom/client";
import { MantineProvider, createTheme, ActionIcon, Button } from "@mantine/core";
import { IconClockPause, IconSettings, IconChevronDown, IconChevronRight, IconCircleCheck, IconPlayerPlay, IconSparkles, IconArchive, IconX, IconPlus } from "@tabler/icons-react";
import "@mantine/core/styles.css";
import "./styles.css";

type Session = { id: string; title: string; project: string; worktree?: string; status: "blocked" | "idle" | "running"; detail: string };
const initial: Session[] = [
  { id: "approval", title: "Review the API migration", project: "pi-studio", worktree: "feat/session-inbox", status: "blocked", detail: "Permission needed" },
  { id: "notes", title: "Summarize the research notes", project: "Quick Chats", status: "idle", detail: "Yesterday" },
  { id: "website", title: "Improve project landing page", project: "manuel-portfolio", status: "running", detail: "Working now" },
  { id: "tests", title: "Investigate flaky UI tests", project: "pi-studio", worktree: "feat/layout", status: "running", detail: "Working now" },
  { id: "layout", title: "Refine sidebar layout", project: "pi-studio", worktree: "feat/layout", status: "running", detail: "Working now" },
];
function App() {
  const [sessions, setSessions] = useState(initial);
  const [later, setLater] = useState<Session[]>([{ id: "draft", title: "Compare storage options", project: "Quick Chats", status: "idle", detail: "Moved to Later" }]);
  const [selected, setSelected] = useState("approval");
  const [runningOpen, setRunningOpen] = useState(true);
  const [laterOpen, setLaterOpen] = useState(false);
  const current = sessions.find(s => s.id === selected) ?? later.find(s => s.id === selected);
  const moveLater = (id: string) => {
    const item = sessions.find(s => s.id === id);
    if (!item || item.status !== "idle") return;
    setSessions(value => value.filter(s => s.id !== id)); setLater(value => [item, ...value]);
  };
  const resume = (item: Session) => { setLater(value => value.filter(s => s.id !== item.id)); setSessions(value => [...value, item]); setSelected(item.id); };
  const row = (item: Session, parked = false) => {
    const sameWorktree = item.worktree && [...sessions, ...later].filter(s => s.project === item.project && s.worktree === item.worktree).length > 1;
    return <div className={`session-row ${selected === item.id ? "selected" : ""}`} key={item.id}>
    <button className="session-open" onClick={() => parked ? resume(item) : setSelected(item.id)}>
      <span className="row-copy"><span className="project-line"><span className={`dot ${item.status}`} /><span className="row-title">{item.project}</span></span><span className="row-meta">{item.worktree ?? item.title}</span>{sameWorktree && <span className="row-meta">{item.title}</span>}</span>
    </button>
    {!parked && item.status === "idle" && <ActionIcon className="later-action" variant="subtle" size="sm" aria-label={`Move ${item.title} to Later`} title="Move to Later" onClick={() => moveLater(item.id)}><IconClockPause size={16}/></ActionIcon>}
    {parked && <Button className="resume-action" size="compact-xs" variant="subtle" onClick={() => resume(item)}>Resume</Button>}
  </div>;
  };
  const section = (title: string, entries: Session[]) => entries.length ? <section className="group" key={title}><h2>{title}<span>{entries.length}</span></h2>{entries.map(item => row(item))}</section> : null;
  return <main className="shell">
    <aside className="sidebar">
      <div className="session-list">
        {section("Needs you", sessions.filter(s => s.status === "blocked"))}
        {section("Ready", sessions.filter(s => s.status === "idle"))}
        {sessions.some(s => s.status === "running") && <section className="group"><button className="collapsible" onClick={() => setRunningOpen(v => !v)}>{runningOpen ? <IconChevronDown size={14}/> : <IconChevronRight size={14}/>}<span>Running</span><span className="count">{sessions.filter(s => s.status === "running").length}</span></button>{runningOpen && sessions.filter(s => s.status === "running").map(item => row(item))}</section>}
        {later.length > 0 && <section className="later-group"><button className="collapsible" onClick={() => setLaterOpen(v => !v)}>{laterOpen ? <IconChevronDown size={14}/> : <IconChevronRight size={14}/>}<span>Later</span><span className="count">{later.length}</span></button>{laterOpen && later.map(item => row(item, true))}</section>}
      </div>
      <div className="sidebar-footer"><button aria-label="Settings" title="Settings"><IconSettings size={17}/></button></div>
    </aside>
    <section className="conversation">
      <header className="conversation-header"><h2 className="session-title"><span className="title-project">{current?.project ?? "Choose a session"}</span>{current && <><IconChevronRight size={15} className="title-separator" aria-label="then"/><span className="title-session">{current.title}</span></>}</h2><div className="header-actions"><ActionIcon variant="subtle" color="gray" aria-label="Move to Later" title="Move to Later" onClick={() => { if (!current) return; setSessions(value => value.filter(s => s.id !== current.id)); setLater(value => [current, ...value.filter(s => s.id !== current.id)]); setSelected(""); }}><IconClockPause size={17}/></ActionIcon><ActionIcon variant="subtle" color="gray" aria-label="Archive session" title="Archive session" onClick={() => { if (!current) return; setSessions(value => value.filter(s => s.id !== current.id)); setLater(value => value.filter(s => s.id !== current.id)); setSelected(""); }}><IconArchive size={17}/></ActionIcon><ActionIcon variant="subtle" color="gray" aria-label="Close session" title="Close session (keeps running in background)" onClick={() => setSelected("")}><IconX size={17}/></ActionIcon><ActionIcon variant="subtle" color="gray" aria-label="New session" title="New session" onClick={() => { const item: Session = { id: `new-${Date.now()}`, title: "New session", project: current?.project ?? "pi-studio", status: "idle", detail: "Just now" }; setSessions(value => [...value, item]); setSelected(item.id); }}><IconPlus size={18}/></ActionIcon>{current && <span className="header-status" title={current.status} aria-label={`Status: ${current.status}`}><span className={`dot ${current.status}`}/></span>}</div></header>
      <div className="transcript">
        {current ? <><div className="message user-message"><span className="avatar">M</span><p>Can you continue where we left off and help with this?</p></div><div className="message assistant-message"><span className="avatar pi-avatar"><IconSparkles size={15}/></span><div><p>{current.status === "blocked" ? "I’m ready to continue, but I need your input before I can proceed." : current.status === "running" ? "I’m working through the requested changes now." : "Here’s the summary, with the key findings and next steps."}</p>{current.status === "blocked" && <div className="prompt-card"><strong>Allow this command?</strong><p>Run the requested check in the project directory.</p><div><Button size="xs" color="dark">Allow once</Button><Button size="xs" variant="default">Reject</Button></div></div>}</div></div></> : <div className="empty"><IconCircleCheck size={30}/><h3>Pick up any conversation</h3><p>Choose a session from the sidebar or start a new one.</p></div>}
      </div>
      <div className="composer"><div className="composer-inner"><span>Message Pi…</span><ActionIcon size="lg" color="dark" radius="xl" aria-label="Send"><IconPlayerPlay size={14}/></ActionIcon></div></div>
    </section>
  </main>;
}

createRoot(document.getElementById("root")!).render(<MantineProvider theme={createTheme({ primaryColor: "gray", fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif', defaultRadius: "md" })} defaultColorScheme="light"><App/>{import.meta.env.DEV && <Agentation />}</MantineProvider>);
