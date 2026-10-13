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
