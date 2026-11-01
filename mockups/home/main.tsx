import React from "react";
import { createRoot } from "react-dom/client";
import { MantineProvider, createTheme } from "@mantine/core";
import { Agentation } from "agentation";
import "@mantine/core/styles.css";
import "./styles.css";

const theme = createTheme({
  primaryColor: "dark",
  fontFamily: "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  defaultRadius: "md",
});

const recentChats = [
  { title: "Review the latest changes", project: "pi-studio", time: "12 min ago", color: "violet" },
  { title: "Fix navigation state restoration", project: "pi-chat", time: "Yesterday", color: "teal" },
  { title: "Prepare notes for the meeting", project: "Quick Chats", time: "Yesterday", color: "orange" },
];

function App() {
  const [layout, setLayout] = React.useState(new URLSearchParams(location.search).get("layout") ?? "desktop");
  const [notice, setNotice] = React.useState("");

  const action = (label: string) => setNotice(`${label} — this is a visual prototype.`);

  return (
    <div className={`shell ${layout === "phone" ? "phone" : "desktop"}`}>
      <aside className="sidebar">
        <div className="brand"><div className="brand-mark">π</div><span>Pi Studio</span><button className="sidebar-toggle" aria-label="Collapse sidebar">‹</button></div>
        <button className="nav-item active"><span>⌂</span> Home</button>
        <button className="nav-item" onClick={() => action("Projects opened")}><span>▦</span> Projects</button>
        <div className="sidebar-label">QUICK ACCESS</div>
        <button className="nav-item"><span className="quick-icon">◌</span> Quick Chats</button>
        <div className="sidebar-label project-label">PROJECTS <button aria-label="Add project" onClick={() => action("Add project")}>＋</button></div>
        <button className="project-item"><span className="project-dot violet"/> pi-studio <span className="project-chevron">⌄</span></button>
        <button className="project-item"><span className="project-dot blue"/> pi-chat</button>
        <div className="sidebar-bottom"><div className="connection-dot"/><span>Connected · control active</span><button aria-label="Settings" onClick={() => action("Settings opened")}>⚙</button></div>
      </aside>

      <main className="main">
        <header className="topbar"><button className="mobile-menu" aria-label="Open navigation">☰</button><div className="breadcrumb">Pi Studio <span>/</span> Home</div><div className="topbar-actions"><button className="avatar" aria-label="Account menu">M</button></div></header>
        <div className="home-content">
          <section className="welcome">
            <div className="welcome-copy"><div className="eyebrow">YOUR WORKSPACE</div><h1>Good afternoon, Manuel</h1><p>Pick up where you left off, or start something new.</p></div>
          </section>

          <section className="quick-switcher" aria-label="Quick switcher">
            <span className="switcher-search" aria-hidden="true">⌕</span>
            <input aria-label="Quick switcher" placeholder="Search or start a conversation…" onKeyDown={(event) => { if (event.key === "Enter") action("Quick switcher search"); }} />
            <kbd>⌘ K</kbd>
          </section>


        </div>
      </main>
      {notice && <div className="notice" role="status" onClick={() => setNotice("")}>{notice}<button aria-label="Dismiss">×</button></div>}
      <div className="layout-switch"><span>Preview</span><button className={layout !== "phone" ? "selected" : ""} onClick={() => { setLayout("desktop"); history.replaceState(null, "", "?layout=desktop"); }}>Desktop</button><button className={layout === "phone" ? "selected" : ""} onClick={() => { setLayout("phone"); history.replaceState(null, "", "?layout=phone"); }}>Phone</button></div>
    </div>
  );
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode><MantineProvider theme={theme}><App />{import.meta.env.DEV && <Agentation />}</MantineProvider></React.StrictMode>,
);
