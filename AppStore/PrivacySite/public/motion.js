(() => {
  "use strict";

  const root = document.documentElement;
  const reduceMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  const finePointerQuery = window.matchMedia("(hover: hover) and (pointer: fine)");
  const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
  const revealSelectors = [
    ".feature-overview .section-intro",
    ".feature-card",
    ".story-copy",
    ".story-image",
    ".showcase-section .section-intro",
    ".gallery-card",
    ".ecosystem-image",
    ".ecosystem-copy",
    ".privacy-copy",
    ".privacy-image",
    ".release-visual",
    ".release-copy",
    ".summary-card",
    ".policy",
  ];
  const mediaSelectors = [
    ".story-image",
    ".gallery-image",
    ".ecosystem-image",
    ".privacy-image",
    ".release-visual",
  ];

  root.classList.add("motion-capable");

  const header = document.querySelector(".site-header, .site-nav");
  const hero = document.querySelector(".landing-hero");
  const heroCopy = document.querySelector(".hero-copy");
  const heroVisual = document.querySelector(".hero-visual");
  const revealElements = [...document.querySelectorAll(revealSelectors.join(","))];
  const mediaFrames = [...document.querySelectorAll(mediaSelectors.join(","))];
  const progress = document.createElement("div");

  progress.className = "scroll-progress";
  progress.setAttribute("aria-hidden", "true");
  document.body.append(progress);

  revealElements.forEach((element, index) => {
    element.classList.add("motion-reveal");

    const group = element.parentElement;
    const groupItems = group
      ? [...group.children].filter((child) => revealElements.includes(child))
      : [];
    const groupIndex = Math.max(0, groupItems.indexOf(element));
    const delay = Math.min(groupIndex * 90, 270);

    element.style.setProperty("--reveal-delay", `${delay}ms`);
    element.style.setProperty("--reveal-order", String(index));
  });

  const showEverything = () => {
    revealElements.forEach((element) => element.classList.add("is-visible"));
  };

  if (reduceMotionQuery.matches || !("IntersectionObserver" in window)) {
    showEverything();
  } else {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        });
      },
      {
        rootMargin: "0px 0px -12% 0px",
        threshold: 0.12,
      },
    );

    revealElements.forEach((element) => observer.observe(element));
  }

  let frameRequested = false;

  const updateScrollMotion = () => {
    frameRequested = false;

    const scrollY = window.scrollY;
    const viewportHeight = window.innerHeight;
    const scrollRange = Math.max(
      1,
      document.documentElement.scrollHeight - viewportHeight,
    );
    const scrollProgress = clamp(scrollY / scrollRange, 0, 1);

    progress.style.transform = `scaleX(${scrollProgress})`;
    header?.classList.toggle("is-condensed", scrollY > 28);

    if (reduceMotionQuery.matches) return;

    if (hero && heroCopy && heroVisual) {
      const heroProgress = clamp(scrollY / Math.max(viewportHeight, 720), 0, 1);

      heroCopy.style.setProperty(
        "--hero-copy-shift",
        `${Math.round(heroProgress * 54)}px`,
      );
      heroCopy.style.setProperty(
        "--hero-copy-opacity",
        String(1 - heroProgress * 0.42),
      );
      heroVisual.style.setProperty(
        "--hero-stage-shift",
        `${Math.round(heroProgress * -20)}px`,
      );
      heroVisual.style.setProperty(
        "--hero-stage-scale",
        String(1 - heroProgress * 0.018),
      );
    }

    mediaFrames.forEach((frame) => {
      const rect = frame.getBoundingClientRect();
      if (rect.bottom < -120 || rect.top > viewportHeight + 120) return;

      const centerOffset =
        (rect.top + rect.height / 2 - viewportHeight / 2) / viewportHeight;
      const shift = clamp(centerOffset * -18, -14, 14);
      frame.style.setProperty("--media-shift", `${shift.toFixed(2)}px`);
    });
  };

  const requestScrollMotion = () => {
    if (frameRequested) return;
    frameRequested = true;
    window.requestAnimationFrame(updateScrollMotion);
  };

  window.addEventListener("scroll", requestScrollMotion, { passive: true });
  window.addEventListener("resize", requestScrollMotion, { passive: true });
  requestScrollMotion();

  const tiltElements = [
    ...document.querySelectorAll(".feature-card, .gallery-card"),
  ];

  const resetTilt = (element) => {
    element.style.setProperty("--tilt-x", "0deg");
    element.style.setProperty("--tilt-y", "0deg");
    element.style.setProperty("--pointer-x", "50%");
    element.style.setProperty("--pointer-y", "50%");
  };

  const enableTilt = () => {
    if (reduceMotionQuery.matches || !finePointerQuery.matches) return;

    tiltElements.forEach((element) => {
      element.classList.add("motion-tilt");
      resetTilt(element);

      element.addEventListener("pointermove", (event) => {
        const rect = element.getBoundingClientRect();
        const x = clamp((event.clientX - rect.left) / rect.width, 0, 1);
        const y = clamp((event.clientY - rect.top) / rect.height, 0, 1);

        element.style.setProperty("--tilt-x", `${((0.5 - y) * 2.2).toFixed(2)}deg`);
        element.style.setProperty("--tilt-y", `${((x - 0.5) * 2.8).toFixed(2)}deg`);
        element.style.setProperty("--pointer-x", `${(x * 100).toFixed(1)}%`);
        element.style.setProperty("--pointer-y", `${(y * 100).toFixed(1)}%`);
      });

      element.addEventListener("pointerleave", () => resetTilt(element));
    });
  };

  enableTilt();

  reduceMotionQuery.addEventListener("change", (event) => {
    root.classList.toggle("motion-reduced", event.matches);
    if (event.matches) {
      showEverything();
      tiltElements.forEach((element) => {
        element.classList.remove("motion-tilt");
        resetTilt(element);
      });
    }
    requestScrollMotion();
  });

  window.addEventListener(
    "pageshow",
    () => {
      root.classList.add("motion-mounted");
      requestScrollMotion();
    },
    { once: true },
  );

  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => root.classList.add("motion-mounted"));
  });
})();
