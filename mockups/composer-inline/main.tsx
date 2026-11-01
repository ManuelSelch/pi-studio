import React, { useState } from "react";
import { createRoot } from "react-dom/client";
import { MantineProvider, createTheme, ActionIcon } from "@mantine/core";
import { IconArrowUp } from "@tabler/icons-react";
import { Agentation } from "agentation";
import "@mantine/core/styles.css";
import "./styles.css";

function Composer() {
  const [message, setMessage] = useState("");
  const [sent, setSent] = useState<string[]>([]);
  function send() { if (!message.trim()) return; setSent([...sent, message]); setMessage(""); }
  return <div className="composer"><div className="box"><textarea autoFocus aria-label="Message" placeholder="Message" value={message} onChange={e => setMessage(e.target.value)} onKeyDown={e => { if(e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } }} /><ActionIcon aria-label="Send" size="lg" disabled={!message.trim()} onClick={send}><IconArrowUp size={19}/></ActionIcon></div></div>;
}
function App() {
  return <div className="window"><aside><strong>Pi Studio</strong><p>INBOX</p><div className="selected">● &nbsp; Improving the session view</div><div>○ &nbsp; Project notes</div></aside><main><header>Improving the session view</header><section><article className="user">Could you take a look at the session layout?</article><article><b>π</b><span>Of course. I’ll review the current layout and suggest a few improvements.</span></article></section><Composer /></main></div>;
}
createRoot(document.getElementById("root")!).render(<MantineProvider theme={createTheme({primaryColor:"blue",defaultRadius:"md",fontFamily:"-apple-system, BlinkMacSystemFont, sans-serif"})}><App />{import.meta.env.DEV && <Agentation />}</MantineProvider>);
