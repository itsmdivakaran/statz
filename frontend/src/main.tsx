import React from "react";
import ReactDOM from "react-dom/client";
import { App } from "./app/App";
import { useStore } from "./state/store";
import "./index.css";

// Dev builds only: lets the e2e sweep drive the store directly.
if (import.meta.env.DEV) (window as unknown as { __sn: typeof useStore }).__sn = useStore;

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
