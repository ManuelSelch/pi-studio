import { useEffect, useRef, useState } from "react";
import { ActionIcon, Badge, Button, Group, SegmentedControl, Textarea, Tooltip } from "@mantine/core";
import { IconArrowDown, IconArrowUp, IconCheck, IconChevronDown, IconChevronLeft, IconChevronRight, IconCopy, IconDeviceDesktop, IconDeviceMobile, IconInfoCircle, IconMoon, IconPlayerPlay, IconPlayerStop, IconSettings, IconSun, IconX } from "@tabler/icons-react";

type Phase = "thinking" | "streaming" | "complete" | "interrupted";
const phaseLabels: Record<Phase, string> = { thinking: "Thinking", streaming: "Streaming", complete: "Complete", interrupted: "Interrupted" };
const params = new URLSearchParams(location.search);
const initialPhase = Object.hasOwn(phaseLabels, params.get("state") ?? "") ? params.get("state") as Phase : "complete";

function ThinkingBlock({ active }: { active: boolean }) {
  const [expanded, setExpanded] = useState(active);
  useEffect(() => { if (active) setExpanded(true); }, [active]);
  return <section className="thinking">
    <button className="thinking-toggle" aria-expanded={expanded} onClick={() => setExpanded(!expanded)}>
      {expanded ? <IconChevronDown size={14} /> : <IconChevronRight size={14} />}
      <span>{active ? "Thinking…" : "Thinking"}</span>
      <span className="thinking-context">{active ? "Comparing reconnect strategies" : "Connection lifecycle and draft safety"}</span>
    </button>
    {expanded && <div className="thinking-body">
      <p>The connection belongs to the foreground lifecycle, but the server run does not. I need to separate reconnecting the transport from creating or sending anything.</p>
      <p>I’ll keep the selected session identity and draft, then request an authoritative snapshot. A failed reattach must leave the user in browsing, not create another session.{active && <span className="caret" />}</p>
    </div>}
  </section>;
}

function CodeBlock() {
  const [copied, setCopied] = useState(false);
  const code = "func resumeSession() async throws {\n    let snapshot = try await client.attach(sessionID)\n    selectedSession = snapshot.session\n    // Draft stays local. Never resend on reconnect.\n}";
  async function copy() {
    try { await navigator.clipboard.writeText(code); setCopied(true); }
    catch { setCopied(false); }
  }
  return <figure className="code-block">
    <figcaption><span>Swift</span><Tooltip label={copied ? "Copied" : "Copy code"}><ActionIcon variant="subtle" color="gray" aria-label={copied ? "Code copied" : "Copy code"} onClick={copy}>{copied ? <IconCheck size={15} /> : <IconCopy size={15} />}</ActionIcon></Tooltip></figcaption>
    <pre><code><span className="kw">func</span>{" resumeSession() "}<span className="kw">async throws</span>{" {\n    "}<span className="kw">let</span>{" snapshot = "}<span className="kw">try await</span>{" client.attach(sessionID)\n    selectedSession = snapshot.session\n    "}<span className="comment">{"// Draft stays local. Never resend on reconnect."}</span>{"\n}"}</code></pre>
  </figure>;
}

function MarkdownAnswer({ partial }: { partial: boolean }) {
  return <div className="markdown">
    <h2>Reconnect without repeating work</h2>
    <p>Keep the <strong>conversation</strong> and the <strong>connection</strong> separate. Reconnecting should restore what the server knows—not submit the user’s last message again.</p>
    <h3>What changes</h3>
    <ol>
      <li><strong>Remember the selected session.</strong> Store its server identity, not a local tab index.</li>
      <li><strong>Reattach explicitly.</strong> Request a fresh snapshot before enabling Send.</li>
      <li><strong>Preserve the draft.</strong> Clear it only after confirmed admission.</li>
    </ol>
    <CodeBlock />
    {partial ? <p>When the transport comes back, reconcile the snapshot with the selected session<span className="caret" /></p> : <>
      <h3>Expected behavior</h3>
      <div className="table-scroll"><table><thead><tr><th>Situation</th><th>Result</th></tr></thead><tbody>
        <tr><td>Session still exists</td><td>Restore its transcript</td></tr>
        <tr><td>Session was closed</td><td>Return to project browsing</td></tr>
        <tr><td>Send outcome is unknown</td><td>Keep the draft; never retry automatically</td></tr>
      </tbody></table></div>
      <blockquote>Disconnecting ends local observation. It does not stop the agent or close its session.</blockquote>
      <h3>Bounded retry</h3>
      <p>A capped exponential delay avoids aggressive reconnect loops:</p>
      <div className="math" aria-label="d sub n equals minimum of 30 and 2 to the power n">
        <span>d<sub>n</sub> = min(30, 2<sup>n</sup>)</span>
      </div>
      <p>Use <code>sessionID</code> as the reattachment target. See the <a href="https://example.com" onClick={event => event.preventDefault()}>connection lifecycle documentation</a> for the full contract.</p>
      <ul className="task-list"><li><span aria-label="Complete">☑</span> Preserve draft and reading position</li><li><span aria-label="Incomplete">☐</span> Verify foreground recovery on a physical phone</li></ul>
    </>}
  </div>;
}

function CustomNotice() {
  return <aside className="custom-notice"><IconInfoCircle size={17} /><div><strong>Workspace context updated</strong><p>The agent is working in the <code>pi-studio</code> project. This extension message stays in conversation order.</p></div></aside>;
}

export function TranscriptMockup() {
  const [phase, setPhase] = useState<Phase>(initialPhase);
  const [phone, setPhone] = useState(params.get("device") === "phone");
  const [dark, setDark] = useState(params.get("theme") === "dark");
  const [draft, setDraft] = useState("");
  const [following, setFollowing] = useState(true);
  const [replaying, setReplaying] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const running = phase === "thinking" || phase === "streaming";

  useEffect(() => {
    if (!replaying) return;
    setPhase("thinking");
    const text = setTimeout(() => setPhase("streaming"), 2200);
    const end = setTimeout(() => { setPhase("complete"); setReplaying(false); }, 5200);
    return () => { clearTimeout(text); clearTimeout(end); };
  }, [replaying]);

  useEffect(() => {
    if (following) scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "instant" });
  }, [phase, following]);

  return <div className={dark ? "review-root dark" : "review-root"}>
    <header className="review-bar">
      <div><strong>Rich transcript</strong><span className="review-subtitle"> S9 · revision 1</span></div>
      <SegmentedControl aria-label="Preview platform" size="xs" value={phone ? "phone" : "mac"} onChange={value => setPhone(value === "phone")} data={[{value:"mac", label:<Group gap={5}><IconDeviceDesktop size={14} />Mac</Group>},{value:"phone", label:<Group gap={5}><IconDeviceMobile size={14} />Phone</Group>}]} />
      <div className="review-controls">
        <select aria-label="Transcript state" value={phase} onChange={event => { setReplaying(false); setPhase(event.target.value as Phase); }}>
          {Object.entries(phaseLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
        </select>
        <Button size="xs" variant="default" leftSection={<IconPlayerPlay size={13} />} disabled={replaying} onClick={() => setReplaying(true)}>Replay</Button>
        <ActionIcon variant="default" aria-label={dark ? "Light appearance" : "Dark appearance"} onClick={() => setDark(!dark)}>{dark ? <IconSun size={16} /> : <IconMoon size={16} />}</ActionIcon>
      </div>
    </header>

    <div className={phone ? "app-window phone" : "app-window"}>
      {!phone && <div className="sidebar">
        <div className="sidebar-title">Pi Studio</div>
        <div className="sidebar-section">PROJECTS</div>
        <div className="project-name">pi-studio</div>
        <div className="sidebar-session">Foreground recovery</div>
        <div className="connection"><span className="status-dot" />Connected</div>
      </div>}
      <main className="conversation">
        <header className="workspace-toolbar">
          {phone && <ActionIcon variant="subtle" color="gray" aria-label="Projects (mockup only)"><IconChevronLeft size={20} /></ActionIcon>}
          <span className="project-context">pi-studio <span className="branch">/ main</span></span>
          <ActionIcon variant="subtle" color="gray" aria-label="Settings (mockup only)"><IconSettings size={18} /></ActionIcon>
        </header>
        {!phone && <div className="tabs"><div className="selected-tab"><span className={"status-dot " + (running ? "busy" : "")} />Foreground recovery<IconX size={12} /></div></div>}
        <div className="transcript-scroll" ref={scrollRef} onScroll={event => { const el = event.currentTarget; setFollowing(el.scrollHeight - el.scrollTop - el.clientHeight < 48); }}>
          <div className="transcript-content">
            <h1>Foreground recovery</h1>
            <section className="user-message"><div className="role-label">You</div><p>How should we reconnect a session after the app returns to the foreground? Show the Swift flow and the important edge cases.</p></section>
            <section className="assistant-message">
              <div className="role-label">Pi</div>
              <ThinkingBlock active={phase === "thinking"} />
              <CustomNotice />
              {phase !== "thinking" && <MarkdownAnswer partial={phase === "streaming"} />}
              {phase === "interrupted" && <div className="interruption" role="status"><IconInfoCircle size={16} /><span>Connection lost. Showing the last received content.</span></div>}
              {phase === "complete" && <div className="response-end"><IconCheck size={13} />Complete</div>}
            </section>
          </div>
        </div>
        {!following && <div className="jump-latest"><Button size="xs" variant="default" radius="xl" leftSection={<IconArrowDown size={14} />} onClick={() => {setFollowing(true);scrollRef.current?.scrollTo({top:scrollRef.current.scrollHeight});}}>Latest</Button></div>}
        <footer className="composer-area">
          <div className="session-status" aria-live="polite">{running ? <><span className="status-dot busy" />{phase === "thinking" ? "Thinking…" : "Generating…"}</> : phase === "interrupted" ? "Disconnected" : "Ready"}</div>
          <div className="composer">
            <Textarea variant="unstyled" autosize minRows={2} maxRows={5} placeholder="Message Pi…" aria-label="Message Pi (mockup only)" value={draft} disabled={running || phase === "interrupted"} onChange={event => setDraft(event.currentTarget.value)} />
            <ActionIcon color="dark" variant="filled" radius="xl" aria-label={running ? "Stop simulated response" : "Send (mockup only)"} disabled={!running} onClick={() => { setReplaying(false); setPhase("interrupted"); }}>{running ? <IconPlayerStop size={16} /> : <IconArrowUp size={18} />}</ActionIcon>
          </div>
        </footer>
      </main>
    </div>
    <footer className="review-footer"><Badge variant="light" color="gray" size="xs">Browser approximation</Badge> Native SwiftUI planned · fake content and timed stream · no tool cards in S9</footer>
  </div>;
}
