import React, { useState } from "react";
import { createRoot } from "react-dom/client";
import { Button, MantineProvider, SegmentedControl, createTheme } from "@mantine/core";
import { IconArrowUp } from "@tabler/icons-react";
import { Agentation } from "agentation";
import "@mantine/core/styles.css";
import "./styles.css";

type State = "working" | "complete" | "starting";
function WorkingResponse() {
  const initial = new URLSearchParams(location.search).get("state");
  const [state, setState] = useState<State>(initial === "complete" || initial === "starting" ? initial : "working");
  return <div className="page">
    <header className="review"><strong>Response activity · mockup</strong><SegmentedControl aria-label="Response state" value={state} onChange={value => setState(value as State)} data={[{value:"starting",label:"Starting"},{value:"working",label:"Working"},{value:"complete",label:"Complete"}]} /></header>
    <div className="window"><aside><strong>Pi Studio</strong><small>PROJECTS</small><b>pi-studio</b><div className="selected">Response activity</div></aside>
    <main><div className="toolbar">pi-studio <span>/ main</span></div><div className="tab">Response activity</div>
      <div className="transcript"><h1>Response activity</h1>
        <section><div className="role">You</div><p>Can you check the implementation and update the tests?</p></section>
        <section><div className="role pi">π</div>
          {state !== "starting" && <><p>I’ll inspect the implementation and existing tests first.</p><p>I found the relevant code and am updating the tests.</p></>}
          {state !== "complete" ? <div className="working" role="status"><span className="spinner" aria-hidden="true" />Working…</div> : <p>Done. The implementation and tests are updated.</p>}
        </section>
        {state === "complete" && <section><div className="role">You</div><p>Thanks!</p><div className="role pi next">π</div><p>You’re welcome.</p></section>}
      </div>
      <div className="composer"><span>Message Pi…</span><Button size="compact-sm" color="dark" aria-label="Send (mockup only)"><IconArrowUp size={16}/></Button></div>
    </main></div><footer>Browser approximation of the native app · simulated content, no tool-call details</footer>
  </div>;
}
createRoot(document.getElementById("root")!).render(<MantineProvider theme={createTheme({fontFamily:'-apple-system, BlinkMacSystemFont, sans-serif'})}><WorkingResponse />{import.meta.env.DEV && <Agentation />}</MantineProvider>);
