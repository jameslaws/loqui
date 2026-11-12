import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { About } from "./About";
import { tokenCss } from "./tokens";
import "./styles.css";

const style = document.createElement("style");
style.textContent = tokenCss();
document.head.append(style);

const root = document.getElementById("root");
if (root) {
  createRoot(root).render(
    <StrictMode>
      <About />
    </StrictMode>,
  );
}
