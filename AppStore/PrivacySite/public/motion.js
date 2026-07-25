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
  const glassSelectors = [
    ".site-header",
    ".hero-visual figcaption",
    ".trust-row",
    ".feature-card",
    ".gallery-card",
    ".release-copy",
    ".check-list li",
    ".mini-points span",
  ];

  root.classList.add("motion-capable");
  root.classList.toggle("motion-reduced", reduceMotionQuery.matches);

  const header = document.querySelector(".site-header, .site-nav");
  const desktopNav = document.querySelector(".desktop-nav");
  const hero = document.querySelector(".landing-hero");
  const heroCopy = document.querySelector(".hero-copy");
  const heroVisual = document.querySelector(".hero-visual");
  const revealElements = [...document.querySelectorAll(revealSelectors.join(","))];
  const mediaFrames = [...document.querySelectorAll(mediaSelectors.join(","))];
  const glassElements = [...document.querySelectorAll(glassSelectors.join(","))];
  const storySections = [
    ...document.querySelectorAll(
      ".intelligence-story, .ecosystem-section, .privacy-section, .release-section",
    ),
  ];
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

    if (reduceMotionQuery.matches) {
      root.style.setProperty("--ambient-scroll-y", "0px");
      return;
    }

    root.style.setProperty(
      "--ambient-scroll-y",
      `${Math.round(scrollY * -0.025)}px`,
    );

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

    storySections.forEach((section) => {
      const rect = section.getBoundingClientRect();
      if (rect.bottom < -160 || rect.top > viewportHeight + 160) return;

      const sectionProgress = clamp(
        (viewportHeight - rect.top) / (viewportHeight + rect.height),
        0,
        1,
      );
      const glassX = 18 + sectionProgress * 64;
      const glassY = 10 + Math.sin(sectionProgress * Math.PI) * 24;

      section.style.setProperty("--glass-x", `${glassX.toFixed(1)}%`);
      section.style.setProperty("--glass-y", `${glassY.toFixed(1)}%`);
      section.style.setProperty(
        "--section-progress",
        sectionProgress.toFixed(3),
      );
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

  const resetGlassPoint = (element) => {
    element.style.setProperty("--glass-x", "50%");
    element.style.setProperty("--glass-y", "16%");
    element.classList.remove("is-glass-pressed");
  };

  glassElements.forEach((element) => {
    resetGlassPoint(element);

    element.addEventListener("pointermove", (event) => {
      if (reduceMotionQuery.matches || !finePointerQuery.matches) return;

      const rect = element.getBoundingClientRect();
      const x = clamp((event.clientX - rect.left) / rect.width, 0, 1);
      const y = clamp((event.clientY - rect.top) / rect.height, 0, 1);

      element.style.setProperty("--glass-x", `${(x * 100).toFixed(1)}%`);
      element.style.setProperty("--glass-y", `${(y * 100).toFixed(1)}%`);
    });

    element.addEventListener("pointerdown", () => {
      if (!reduceMotionQuery.matches) {
        element.classList.add("is-glass-pressed");
      }
    });
    element.addEventListener("pointerup", () =>
      element.classList.remove("is-glass-pressed"),
    );
    element.addEventListener("pointercancel", () =>
      element.classList.remove("is-glass-pressed"),
    );
    element.addEventListener("pointerleave", () => resetGlassPoint(element));
  });

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

  if (desktopNav) {
    const navIndicator = document.createElement("span");
    const navLinks = [...desktopNav.querySelectorAll("a")];
    navIndicator.className = "nav-glass-indicator";
    navIndicator.setAttribute("aria-hidden", "true");
    desktopNav.append(navIndicator);

    const moveNavIndicator = (link) => {
      const navRect = desktopNav.getBoundingClientRect();
      const linkRect = link.getBoundingClientRect();
      desktopNav.style.setProperty(
        "--nav-glass-left",
        `${(linkRect.left - navRect.left).toFixed(1)}px`,
      );
      desktopNav.style.setProperty(
        "--nav-glass-width",
        `${linkRect.width.toFixed(1)}px`,
      );
      desktopNav.classList.add("is-glass-active");
    };

    navLinks.forEach((link) => {
      link.addEventListener("pointerenter", () => moveNavIndicator(link));
      link.addEventListener("focus", () => moveNavIndicator(link));
    });

    desktopNav.addEventListener("pointerleave", () =>
      desktopNav.classList.remove("is-glass-active"),
    );
    desktopNav.addEventListener("focusout", () => {
      window.requestAnimationFrame(() => {
        if (!desktopNav.contains(document.activeElement)) {
          desktopNav.classList.remove("is-glass-active");
        }
      });
    });
  }

  let pointerFrameRequested = false;
  let pointerX = window.innerWidth / 2;
  let pointerY = window.innerHeight / 3;

  const updateAmbientPointer = () => {
    pointerFrameRequested = false;
    if (reduceMotionQuery.matches || !finePointerQuery.matches) return;

    const normalizedX = pointerX / Math.max(window.innerWidth, 1) - 0.5;
    const normalizedY = pointerY / Math.max(window.innerHeight, 1) - 0.5;

    root.style.setProperty("--cursor-shift-x", `${(normalizedX * 34).toFixed(2)}px`);
    root.style.setProperty("--cursor-shift-y", `${(normalizedY * 28).toFixed(2)}px`);
    root.style.setProperty(
      "--ambient-blue-x",
      `${(normalizedX * -12).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-blue-y",
      `${(normalizedY * -9).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-mint-x",
      `${(normalizedX * 10).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-mint-y",
      `${(normalizedY * -7).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-violet-x",
      `${(normalizedX * -7).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-violet-y",
      `${(normalizedY * 8).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-arc-x",
      `${(normalizedX * 5).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-arc-y",
      `${(normalizedY * 4).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-arc-two-x",
      `${(normalizedX * -4).toFixed(2)}px`,
    );
    root.style.setProperty(
      "--ambient-arc-two-y",
      `${(normalizedY * 3).toFixed(2)}px`,
    );
  };

  window.addEventListener(
    "pointermove",
    (event) => {
      pointerX = event.clientX;
      pointerY = event.clientY;
      if (pointerFrameRequested) return;
      pointerFrameRequested = true;
      window.requestAnimationFrame(updateAmbientPointer);
    },
    { passive: true },
  );

  reduceMotionQuery.addEventListener("change", (event) => {
    root.classList.toggle("motion-reduced", event.matches);
    if (event.matches) {
      showEverything();
      tiltElements.forEach((element) => {
        element.classList.remove("motion-tilt");
        resetTilt(element);
      });
      glassElements.forEach(resetGlassPoint);
      [
        "--cursor-shift-x",
        "--cursor-shift-y",
        "--ambient-blue-x",
        "--ambient-blue-y",
        "--ambient-mint-x",
        "--ambient-mint-y",
        "--ambient-violet-x",
        "--ambient-violet-y",
        "--ambient-arc-x",
        "--ambient-arc-y",
        "--ambient-arc-two-x",
        "--ambient-arc-two-y",
      ].forEach((property) => root.style.removeProperty(property));
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
