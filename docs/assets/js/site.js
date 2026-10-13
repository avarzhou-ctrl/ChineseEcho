const revealItems = document.querySelectorAll("[data-reveal]");

if (revealItems.length > 0) {
  document.documentElement.classList.add("motion-ready");

  if ("IntersectionObserver" in window) {
    const revealObserver = new IntersectionObserver((entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -10% 0px", threshold: 0.08 });

    revealItems.forEach((item) => revealObserver.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add("is-visible"));
  }
}

const copyButton = document.querySelector("[data-copy-button]");

if (copyButton) {
  const source = document.querySelector("[data-copy-source]");
  const label = copyButton.querySelector("span");
  const status = document.querySelector(".copy-status");
  let resetTimer;

  const copyWithFallback = (text) => {
    const temporaryInput = document.createElement("textarea");
    temporaryInput.value = text;
    temporaryInput.setAttribute("readonly", "");
    temporaryInput.style.position = "fixed";
    temporaryInput.style.opacity = "0";
    document.body.appendChild(temporaryInput);
    temporaryInput.select();
    const copied = document.execCommand("copy");
    temporaryInput.remove();
    return copied;
  };

  copyButton.addEventListener("click", async () => {
    const command = source.textContent.trim();
    let copied = false;

    try {
      await navigator.clipboard.writeText(command);
      copied = true;
    } catch {
      copied = copyWithFallback(command);
    }

    window.clearTimeout(resetTimer);
    copyButton.classList.toggle("is-copied", copied);
    label.textContent = copied ? "Copied" : "Try again";
    status.textContent = copied ? "Command copied to the clipboard." : "Copy failed. Select the command manually.";

    resetTimer = window.setTimeout(() => {
      copyButton.classList.remove("is-copied");
      label.textContent = "Copy";
      status.textContent = "";
    }, 1800);
  });
}

const themeToggle = document.querySelector("[data-theme-toggle]");

if (themeToggle) {
  const root = document.documentElement;
  const systemDark = window.matchMedia("(prefers-color-scheme: dark)");
  const themeColors = { light: "#edf5ec", dark: "#101712" };

  // Resolve the visible theme from an explicit choice, falling back to the system setting.
  const currentTheme = () => root.dataset.theme || (systemDark.matches ? "dark" : "light");

  const syncToggle = () => {
    const theme = currentTheme();
    const next = theme === "dark" ? "light" : "dark";
    themeToggle.dataset.current = theme;
    themeToggle.setAttribute("aria-label", `Switch to ${next} mode`);
    themeToggle.title = `Switch to ${next} mode`;
    // Keep the browser chrome in step with a forced theme.
    if (root.dataset.theme) {
      document.querySelectorAll('meta[name="theme-color"]').forEach((meta) => meta.setAttribute("content", themeColors[theme]));
    }
  };

  themeToggle.addEventListener("click", () => {
    const next = currentTheme() === "dark" ? "light" : "dark";
    root.dataset.theme = next;
    try { localStorage.setItem("chineseecho-theme", next); } catch {}
    syncToggle();
  });

  systemDark.addEventListener("change", syncToggle);
  syncToggle();

  // On phones the fixed toggle would sit over body text, so tuck it away while reading downward.
  const narrowScreen = window.matchMedia("(max-width: 560px)");
  let lastScrollY = window.scrollY;
  window.addEventListener("scroll", () => {
    const y = window.scrollY;
    const nearEnd = window.innerHeight + y >= document.documentElement.scrollHeight - 80;
    themeToggle.classList.toggle("is-tucked", narrowScreen.matches && y > lastScrollY && y > 120 && !nearEnd);
    lastScrollY = y;
  }, { passive: true });
}

// Open an FAQ answer when a link targets it directly.
const openTargetedAnswer = () => {
  const target = location.hash && document.getElementById(location.hash.slice(1));
  if (!(target instanceof HTMLDetailsElement)) return;
  target.open = true;
  // Opening changes the layout after the browser's own jump, so align to the answer again.
  requestAnimationFrame(() => target.scrollIntoView({ block: "start" }));
};
openTargetedAnswer();
window.addEventListener("hashchange", openTargetedAnswer);
