import icon from "./assets/icon-256.png";

/** The About window: what this is and which build it is. */
export function About() {
  return (
    <main className="about">
      <img className="about-icon" src={icon} alt="" width={88} height={88} />
      <h1 className="about-name">loqui</h1>
      <p className="about-version">{`Version ${__APP_VERSION__} (test build)`}</p>
      <p className="about-tagline">Talk, and it’s text.</p>
      <p className="about-note">
        Dictation arrives in the next step. This build proves loqui installs, starts and sits in the tray.
      </p>
    </main>
  );
}
