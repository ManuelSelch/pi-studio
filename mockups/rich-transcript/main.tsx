import React from "react";
import { createRoot } from "react-dom/client";
import { MantineProvider, createTheme } from "@mantine/core";
import "@mantine/core/styles.css";
import "./styles.css";
import { TranscriptMockup } from "./transcript";

if (import.meta.env.DEV) await import("react-grab");

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <MantineProvider theme={createTheme({ primaryColor: "gray", fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif', defaultRadius: "md" })}>
      <TranscriptMockup />
    </MantineProvider>
  </React.StrictMode>,
);
