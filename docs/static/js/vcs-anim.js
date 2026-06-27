// =============================================================================
// vcs-anim.js — interactive canvas animations for the VCS book
// =============================================================================
//
// A tiny, dependency-free framework for the temporal concepts in this book —
// the ones a static diagram can only approximate: the beam racing across the
// screen, the CPU racing the beam, mid-line register rewrites, sprite strobing.
//
// How it works
// ------------
// Markdown embeds a placeholder div via the `vcsanim` shortcode:
//
//     <div class="vcs-anim" data-scene="beam"></div>
//
// On load this file finds every such div, looks up the named *scene*, builds a
// <canvas> + a standard control strip (play/pause, speed, scrub), and runs a
// requestAnimationFrame loop that calls the scene's draw(t) with a normalized
// time t in [0, 1) that advances once per "duration" seconds (scaled by speed).
//
// Adding a scene is one VCSAnim.register(...) call — no framework changes:
//
//     VCSAnim.register('beam', (api) => ({
//       duration: 6,                 // seconds for one full t:0->1 cycle at 1x
//       controls: [                  // optional extra sliders, beyond speed/scrub
//         { id: 'foo', label: 'Foo', min: 0, max: 7, step: 1, value: 0 },
//       ],
//       draw(ctx, t, p) { /* p.foo, p.speed, ... ; api.colors.* for theming */ },
//     }));
//
// Scenes implemented:  crt-scan (how a CRT paints; roll/tear via Hold knobs),
//                      beam (Racing the Beam), cycle-budget (76-cycle budget),
//                      asymmetric-pf (mid-line PF rewrites),
//                      scoreboard (two scores via PF1 rewrites + score-mode color),
//                      resp0-hmove (coarse strobe + fine HMOVE)
//
// Conventions honored: zero dependencies, no build step; all colors are read
// from the book's CSS custom properties so light/dark themes Just Work.
// =============================================================================

(function () {
  "use strict";

  // Singleton so the once-per-page script include is idempotent.
  if (window.VCSAnim && window.VCSAnim.__ready) return;

  var scenes = {};

  // ---------------------------------------------------------------------------
  // Theme colors — pulled live from _custom.scss CSS variables so the canvas
  // matches the page in both light and dark mode (never hard-code colors).
  // ---------------------------------------------------------------------------
  function readColors() {
    var cs = getComputedStyle(document.documentElement);
    function v(name, fallback) {
      var got = cs.getPropertyValue(name);
      return (got && got.trim()) || fallback;
    }
    var dark = window.matchMedia &&
      window.matchMedia("(prefers-color-scheme: dark)").matches;
    return {
      accent: v("--accent-color", dark ? "#ff6b4a" : "#c8102e"),
      accentDark: v("--accent-dark", dark ? "#ffa07a" : "#8f0a1f"),
      card: v("--bg-card", dark ? "#211e19" : "#ffffff"),
      subtle: v("--bg-subtle", dark ? "#1a1814" : "#faf7f2"),
      border: v("--border-color", dark ? "#3a352d" : "#e6e1d8"),
      muted: v("--text-muted", dark ? "#a89e8d" : "#6b6256"),
      // The book's phosphor-green code theme — handy for the "lit" picture area.
      phosphor: dark ? "#33ff66" : "#1f8a3b",
      dark: dark,
    };
  }

  var reduceMotion = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ---------------------------------------------------------------------------
  // Instance: wires one placeholder div into a running animation.
  // ---------------------------------------------------------------------------
  function mount(host) {
    if (host.__vcsMounted) return; // idempotent guard
    host.__vcsMounted = true;

    var name = host.getAttribute("data-scene");
    var factory = scenes[name];
    if (!factory) {
      host.textContent = "[vcs-anim: unknown scene \"" + name + "\"]";
      host.style.color = "var(--text-muted)";
      return;
    }

    var colors = readColors();
    var api = { colors: colors };
    var scene = factory(api);

    var heightAttr = parseInt(host.getAttribute("data-height"), 10);
    var cssHeight = heightAttr > 0 ? heightAttr : (scene.height || 360);

    // --- Canvas (devicePixelRatio-scaled for crisp lines) --------------------
    var canvas = document.createElement("canvas");
    canvas.className = "vcs-anim-canvas";
    host.appendChild(canvas);
    var ctx = canvas.getContext("2d");

    var W = 0, H = 0;
    function resize() {
      var dpr = window.devicePixelRatio || 1;
      var cssWidth = host.clientWidth || 640;
      W = cssWidth;
      H = cssHeight;
      canvas.style.width = cssWidth + "px";
      canvas.style.height = cssHeight + "px";
      canvas.width = Math.round(cssWidth * dpr);
      canvas.height = Math.round(cssHeight * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      api.width = W;
      api.height = H;
    }

    // --- Controls ------------------------------------------------------------
    var controls = document.createElement("div");
    controls.className = "vcs-anim-controls";
    host.appendChild(controls);

    var playing = !reduceMotion;

    var playBtn = document.createElement("button");
    playBtn.type = "button";
    playBtn.className = "vcs-anim-play";
    controls.appendChild(playBtn);

    function makeSlider(id, label, min, max, step, value) {
      var wrap = document.createElement("label");
      wrap.className = "vcs-anim-slider";
      var span = document.createElement("span");
      span.textContent = label;
      var input = document.createElement("input");
      input.type = "range";
      input.min = min; input.max = max; input.step = step; input.value = value;
      input.dataset.id = id;
      wrap.appendChild(span);
      wrap.appendChild(input);
      controls.appendChild(wrap);
      return input;
    }

    var speedInput = makeSlider("speed", "Speed", 0.1, 4, 0.1, 1);
    var scrubInput = makeSlider("scrub", "Frame", 0, 1, 0.001, 0);

    // Scene-declared extra sliders.
    var extraInputs = [];
    (scene.controls || []).forEach(function (c) {
      extraInputs.push(
        makeSlider(c.id, c.label, c.min, c.max, c.step, c.value)
      );
    });

    function setPlaying(on) {
      playing = on;
      playBtn.textContent = on ? "⏸ Pause" : "▶ Play";
      playBtn.setAttribute("aria-pressed", on ? "true" : "false");
    }
    playBtn.addEventListener("click", function () { setPlaying(!playing); });

    // Scrubbing pauses so the reader can park on an exact moment.
    scrubInput.addEventListener("input", function () {
      setPlaying(false);
      t = parseFloat(scrubInput.value);
      render();
    });

    function params() {
      var p = { speed: parseFloat(speedInput.value) };
      extraInputs.forEach(function (inp) {
        p[inp.dataset.id] = parseFloat(inp.value);
      });
      return p;
    }

    // --- Animation loop ------------------------------------------------------
    var t = 0;               // normalized time in [0, 1)
    var last = null;
    var duration = scene.duration || 6;

    function render() {
      ctx.clearRect(0, 0, W, H);
      scene.draw(ctx, t, params());
    }

    function frame(now) {
      if (last === null) last = now;
      var dt = (now - last) / 1000;
      last = now;
      if (playing) {
        var speed = parseFloat(speedInput.value);
        t = (t + (dt * speed) / duration) % 1;
        scrubInput.value = t;
        render();
      }
      requestAnimationFrame(frame);
    }

    // --- Wire up -------------------------------------------------------------
    resize();
    setPlaying(playing);
    render();
    requestAnimationFrame(frame);

    // Re-render on extra-slider changes even while paused.
    extraInputs.forEach(function (inp) {
      inp.addEventListener("input", render);
    });

    // Responsive: re-fit on container width changes.
    if (window.ResizeObserver) {
      new ResizeObserver(function () { resize(); render(); }).observe(host);
    } else {
      window.addEventListener("resize", function () { resize(); render(); });
    }

    // Live recolor when the OS theme flips.
    if (window.matchMedia) {
      var mq = window.matchMedia("(prefers-color-scheme: dark)");
      var onTheme = function () { api.colors = readColors(); render(); };
      if (mq.addEventListener) mq.addEventListener("change", onTheme);
      else if (mq.addListener) mq.addListener(onTheme);
    }
  }

  // ---------------------------------------------------------------------------
  // Public API + auto-init
  // ---------------------------------------------------------------------------
  var VCSAnim = window.VCSAnim || {};
  VCSAnim.scenes = scenes;
  VCSAnim.register = function (name, factory) { scenes[name] = factory; };
  VCSAnim.mountAll = function () {
    var hosts = document.querySelectorAll("div.vcs-anim[data-scene]");
    Array.prototype.forEach.call(hosts, mount);
  };
  VCSAnim.__ready = true;
  window.VCSAnim = VCSAnim;

  // ===========================================================================
  // SCENE: "beam" — Racing the Beam
  // ===========================================================================
  //
  // One NTSC frame is 262 scanlines, conventionally divided into VSYNC (3),
  // VBLANK (37), Visible (192) and Overscan (30). The beam paints left->right
  // within a line, then snaps to the start of the next line (that snap is what
  // WSYNC waits for), marching top->bottom. Only the visible band carries
  // picture; the rest is blanking.
  //
  // We compress the 262 lines into a manageable number of drawn rows but keep
  // the *proportions* exact, and we map normalized time t -> (row, x-within-row)
  // so the dot sweeps and snaps just like the real beam.
  // ===========================================================================
  VCSAnim.register("beam", function (api) {
    var REGIONS = [
      { name: "VSYNC",    lines: 3,   note: "“new frame starts here”" },
      { name: "VBLANK",   lines: 37,  note: "top blanking — do game logic" },
      { name: "Visible",  lines: 192, note: "the kernel — the picture" },
      { name: "Overscan", lines: 30,  note: "bottom blanking — read input" },
    ];
    var TOTAL = 262;            // 3 + 37 + 192 + 30
    var DRAWN_ROWS = 52;        // visual rows; proportional, not 1:1 with lines
    var HBLANK_FRAC = 0.18;     // left margin: horizontal retrace (beam off)

    // Precompute, for each region, its [startLine, endLine).
    var bounds = [];
    var acc = 0;
    REGIONS.forEach(function (r) {
      bounds.push({ r: r, start: acc, end: acc + r.lines });
      acc += r.lines;
    });
    function regionAtLine(line) {
      for (var i = 0; i < bounds.length; i++) {
        if (line < bounds[i].end) return bounds[i];
      }
      return bounds[bounds.length - 1];
    }

    return {
      duration: 7,
      height: 380,
      draw: function (ctx, t, p) {
        var c = api.colors;
        var W = api.width, H = api.height;

        // Layout: screen panel on the left, region legend on the right.
        var pad = 14;
        var legendW = Math.min(190, W * 0.34);
        var screenX = pad;
        var screenY = pad;
        var screenW = W - legendW - pad * 2;
        var screenH = H - pad * 2;

        // Backdrop.
        ctx.fillStyle = c.subtle;
        ctx.fillRect(0, 0, W, H);

        var rowH = screenH / DRAWN_ROWS;
        var hblankW = screenW * HBLANK_FRAC;
        var liveX = screenX + hblankW;
        var liveW = screenW - hblankW;

        // --- Region bands --------------------------------------------------
        function regionColor(name, lit) {
          if (name === "Visible") return lit ? c.card : c.subtle;
          if (name === "VSYNC") return c.accent;
          return c.border; // VBLANK / Overscan blanking
        }
        for (var row = 0; row < DRAWN_ROWS; row++) {
          var line = Math.floor((row / DRAWN_ROWS) * TOTAL);
          var b = regionAtLine(line);
          var y = screenY + row * rowH;
          // HBLANK margin (beam off during horizontal retrace).
          ctx.fillStyle = c.dark ? "#000" : "#15120e";
          ctx.globalAlpha = 0.85;
          ctx.fillRect(screenX, y, hblankW, rowH + 0.5);
          ctx.globalAlpha = 1;
          // Live picture area for this line.
          ctx.fillStyle = regionColor(b.r.name, b.r.name === "Visible");
          ctx.fillRect(liveX, y, liveW, rowH + 0.5);
        }

        // Visible-band "lit" tint to read as actual picture.
        var visB = bounds[2];
        var visY0 = screenY + (visB.start / TOTAL) * screenH;
        var visY1 = screenY + (visB.end / TOTAL) * screenH;
        ctx.strokeStyle = c.phosphor;
        ctx.globalAlpha = 0.5;
        ctx.lineWidth = 1;
        ctx.strokeRect(liveX + 0.5, visY0 + 0.5, liveW - 1, visY1 - visY0 - 1);
        ctx.globalAlpha = 1;

        // Screen frame.
        ctx.strokeStyle = c.muted;
        ctx.lineWidth = 1;
        ctx.strokeRect(screenX + 0.5, screenY + 0.5, screenW - 1, screenH - 1);

        // --- The beam ------------------------------------------------------
        // Map t -> current line and x-fraction within the line.
        var fline = t * TOTAL;          // 0 .. 262
        var curLine = Math.floor(fline);
        var xFrac = fline - curLine;     // 0..1 across one scanline
        var beamRow = (curLine / TOTAL) * DRAWN_ROWS;
        var beamY = screenY + beamRow * rowH + rowH / 2;
        var beamX = liveX + xFrac * liveW;
        var curB = regionAtLine(Math.min(curLine, TOTAL - 1));
        var beamLit = curB.r.name === "Visible";

        // Trail: the part of the current line already painted.
        ctx.strokeStyle = beamLit ? c.phosphor : c.muted;
        ctx.globalAlpha = 0.55;
        ctx.lineWidth = Math.max(2, rowH * 0.7);
        ctx.beginPath();
        ctx.moveTo(liveX, beamY);
        ctx.lineTo(beamX, beamY);
        ctx.stroke();
        ctx.globalAlpha = 1;

        // Beam dot.
        ctx.fillStyle = c.accent;
        ctx.beginPath();
        ctx.arc(beamX, beamY, Math.max(3, rowH * 0.6), 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = c.dark ? "#fff" : "#fff";
        ctx.globalAlpha = 0.9;
        ctx.beginPath();
        ctx.arc(beamX, beamY, Math.max(1, rowH * 0.22), 0, Math.PI * 2);
        ctx.fill();
        ctx.globalAlpha = 1;

        // WSYNC flash near the right edge of a line (about to snap to next).
        if (xFrac > 0.9) {
          ctx.fillStyle = c.accent;
          ctx.font = "bold 11px system-ui, sans-serif";
          ctx.textAlign = "right";
          ctx.fillText("WSYNC → next line", liveX + liveW, beamY - rowH);
          ctx.textAlign = "left";
        }

        // --- Legend --------------------------------------------------------
        var lx = screenX + screenW + pad;
        var ly = screenY + 2;
        ctx.textAlign = "left";
        ctx.textBaseline = "top";
        for (var i = 0; i < REGIONS.length; i++) {
          var r = REGIONS[i];
          var active = curB.r.name === r.name;
          var swatch = regionColor(r.name, r.name === "Visible");
          // swatch box
          ctx.fillStyle = swatch;
          ctx.fillRect(lx, ly, 14, 14);
          ctx.strokeStyle = c.muted;
          ctx.strokeRect(lx + 0.5, ly + 0.5, 13, 13);
          // labels
          ctx.fillStyle = active ? c.accent : c.muted;
          ctx.font = (active ? "bold " : "") + "12px system-ui, sans-serif";
          ctx.fillText(r.name + "  (" + r.lines + ")", lx + 20, ly + 1);
          ctx.fillStyle = c.muted;
          ctx.font = "10px system-ui, sans-serif";
          wrapText(ctx, r.note, lx + 20, ly + 16, legendW - 26, 12);
          ly += 46;
        }

        // Current-region callout.
        ctx.fillStyle = c.accent;
        ctx.font = "bold 12px system-ui, sans-serif";
        ctx.fillText("Beam in: " + curB.r.name, lx, ly + 6);
      },
    };

    // Minimal word-wrap helper for legend notes.
    function wrapText(ctx, text, x, y, maxW, lineH) {
      var words = text.split(" ");
      var line = "";
      for (var n = 0; n < words.length; n++) {
        var test = line + words[n] + " ";
        if (ctx.measureText(test).width > maxW && n > 0) {
          ctx.fillText(line, x, y);
          line = words[n] + " ";
          y += lineH;
        } else {
          line = test;
        }
      }
      ctx.fillText(line, x, y);
    }
  });

  // ===========================================================================
  // SCENE: "cycle-budget" — the 76-cycle line budget
  // ===========================================================================
  //
  // A visible scanline is 76 CPU cycles. The cycles that count are the ones of
  // *work* before `STA WSYNC`; WSYNC then pads out to the line boundary. Fit
  // under 76 and the line is clean with cycles to spare; need 77 and you've
  // already spilled into the next line before WSYNC — the picture tears.
  //
  // The bar fills instruction-by-instruction (each op takes time proportional
  // to its cost), green -> amber -> red as it approaches and crosses 76. The
  // "Extra work" slider pads the kernel until it tips over, and the mini screen
  // on the right shows the consequence: stable lines vs. a torn picture.
  //
  // Base kernel is the example from counting-cycles.md.
  // ===========================================================================
  VCSAnim.register("cycle-budget", function (api) {
    var BASE = [
      { text: "lda (SpritePtr),y", cyc: 5, note: "fetch sprite row" },
      { text: "sta GRP0",          cyc: 3, note: "draw it" },
      { text: "lda BgColor,y",     cyc: 4, note: "fetch bg color" },
      { text: "sta COLUBK",        cyc: 3, note: "set it" },
      { text: "dey",               cyc: 2, note: "next row" },
    ];
    var WSYNC = { text: "sta WSYNC", cyc: 3, note: "end the line", wsync: true };
    var LIMIT = 76;        // cycles of work per visible line
    var SCALE_MAX = 96;    // bar runs past the deadline so overrun is visible

    return {
      duration: 6,
      height: 340,
      controls: [
        { id: "extra", label: "Extra work (cyc)", min: 0, max: 64, step: 1, value: 0 },
      ],
      draw: function (ctx, t, p) {
        var c = api.colors;
        var W = api.width, H = api.height;
        var ok   = c.dark ? "#33ff66" : "#1f8a3b"; // status colors, dark-aware
        var warn = c.dark ? "#ffcf4a" : "#c98a00";
        var bad  = c.dark ? "#ff5a5a" : "#c8102e";

        // --- Build this pass's instruction sequence ------------------------
        var extra = Math.round(p.extra || 0);
        var seq = BASE.slice();
        if (extra > 0) {
          seq.push({ text: "… extra work …", cyc: extra, note: "added instructions", pad: true });
        }
        var workTotal = 0;
        seq.forEach(function (i) { workTotal += i.cyc; });
        seq.push(WSYNC); // WSYNC's own cycles don't count toward the 76 of work

        var passCyc = 0;
        seq.forEach(function (i) { passCyc += i.cyc; });

        // --- Walk the cursor by time t, accumulating cycles ----------------
        var elapsed = t * passCyc;
        var accBefore = 0, curIdx = 0;
        for (var i = 0; i < seq.length; i++) {
          curIdx = i;
          if (elapsed <= accBefore + seq[i].cyc) break;
          accBefore += seq[i].cyc;
        }
        var partial = Math.min(seq[curIdx].cyc, Math.max(0, elapsed - accBefore));
        var atWsync = !!seq[curIdx].wsync;
        var shownWork = atWsync ? workTotal : Math.min(accBefore + partial, workTotal);
        var overran = workTotal > LIMIT;

        // --- Backdrop ------------------------------------------------------
        ctx.fillStyle = c.subtle;
        ctx.fillRect(0, 0, W, H);
        var pad = 16;

        // --- Budget bar (the hero) -----------------------------------------
        ctx.fillStyle = c.muted;
        ctx.font = "12px system-ui, sans-serif";
        ctx.textAlign = "left";
        ctx.textBaseline = "alphabetic";
        ctx.fillText("Cycle budget — one visible line is 76 cycles", pad, 26);

        var barX = pad, barY = 40, barW = W - pad * 2, barH = 30;
        // track
        ctx.fillStyle = c.card;
        ctx.fillRect(barX, barY, barW, barH);
        ctx.strokeStyle = c.border;
        ctx.strokeRect(barX + 0.5, barY + 0.5, barW - 1, barH - 1);
        // fill
        var ratio = shownWork / LIMIT;
        var fillColor = ratio >= 1 ? bad : (ratio >= 0.8 ? warn : ok);
        var fillW = Math.min(shownWork / SCALE_MAX, 1) * barW;
        ctx.fillStyle = fillColor;
        ctx.globalAlpha = 0.85;
        ctx.fillRect(barX, barY, fillW, barH);
        ctx.globalAlpha = 1;
        // 76-cycle deadline marker
        var deadX = barX + (LIMIT / SCALE_MAX) * barW;
        ctx.strokeStyle = bad;
        ctx.setLineDash([4, 3]);
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(deadX, barY - 4);
        ctx.lineTo(deadX, barY + barH + 4);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.lineWidth = 1;
        ctx.fillStyle = bad;
        ctx.font = "bold 11px system-ui, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("76", deadX, barY + barH + 16);
        // live count
        ctx.fillStyle = fillColor;
        ctx.font = "bold 13px system-ui, sans-serif";
        ctx.textAlign = "left";
        ctx.fillText(Math.round(shownWork) + " cyc", barX + 4, barY - 6);

        // --- Verdict (shown once the cursor reaches WSYNC) -----------------
        if (atWsync) {
          ctx.textAlign = "right";
          ctx.font = "bold 13px system-ui, sans-serif";
          if (overran) {
            ctx.fillStyle = bad;
            ctx.fillText("OVERRUN by " + (workTotal - LIMIT) + " — line tears", barX + barW, barY - 6);
          } else {
            ctx.fillStyle = ok;
            ctx.fillText((LIMIT - workTotal) + " cycles to spare", barX + barW, barY - 6);
          }
        }

        // --- Lower split: instruction list (left) + mini screen (right) ----
        var listX = pad, listY = barY + barH + 36;
        var rightW = Math.min(150, W * 0.32);
        var rightX = W - pad - rightW;
        var listW = rightX - pad - listX;

        ctx.textAlign = "left";
        ctx.font = "12px ui-monospace, Menlo, monospace";
        var rowH = 22, running = 0;
        for (var k = 0; k < seq.length; k++) {
          var ins = seq[k];
          var y = listY + k * rowH;
          var isCur = k === curIdx;
          if (isCur) {
            ctx.fillStyle = c.accent;
            ctx.globalAlpha = 0.16;
            ctx.fillRect(listX - 4, y - 14, listW + 8, rowH - 2);
            ctx.globalAlpha = 1;
          }
          ctx.fillStyle = isCur ? c.accent : (ins.wsync ? c.muted : (c.dark ? "#d8d2c6" : "#2a261f"));
          ctx.fillText(ins.text, listX, y);
          // cycle cost, right-aligned within the list column
          ctx.fillStyle = ins.wsync ? c.muted : c.muted;
          ctx.textAlign = "right";
          ctx.fillText("; " + ins.cyc, listX + listW, y);
          ctx.textAlign = "left";
          if (!ins.wsync) running += ins.cyc;
        }

        // mini "screen": stable lines vs. a torn picture
        var scrX = rightX, scrY = listY - 14;
        var scrW = rightW, scrH = seq.length * rowH - 8;
        ctx.fillStyle = c.dark ? "#000" : "#0a0f0a";
        ctx.fillRect(scrX, scrY, scrW, scrH);
        ctx.strokeStyle = c.muted;
        ctx.strokeRect(scrX + 0.5, scrY + 0.5, scrW - 1, scrH - 1);
        var lines = 7, lh = scrH / (lines + 1);
        for (var L = 1; L <= lines; L++) {
          var ly = scrY + L * lh;
          var off = 0;
          if (overran) {
            // progressively larger horizontal shift = tear/roll
            off = ((L * (workTotal - LIMIT)) % (scrW * 0.5));
          }
          ctx.strokeStyle = overran ? bad : ok;
          ctx.globalAlpha = overran ? 0.9 : 0.8;
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.moveTo(scrX + 6 + off, ly);
          ctx.lineTo(scrX + scrW - 6, ly);
          if (overran) { // wrap the torn remainder to the left edge
            ctx.moveTo(scrX + 6, ly);
            ctx.lineTo(scrX + 6 + off, ly);
          }
          ctx.stroke();
          ctx.globalAlpha = 1;
        }
        ctx.lineWidth = 1;
        ctx.fillStyle = c.muted;
        ctx.font = "10px system-ui, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(overran ? "picture tears" : "stable picture", scrX + scrW / 2, scrY + scrH + 14);
        ctx.textAlign = "left";
      },
    };
  });

  // ===========================================================================
  // SCENE: "asymmetric-pf" — rewriting PF0/PF1/PF2 mid-line (the gentle intro)
  // ===========================================================================
  //
  // Symmetry is the default; to make the two halves DIFFER you rewrite
  // PF0/PF1/PF2 partway across the line. Same phase discipline as the
  // scoreboard, the simplest possible picture: the CPU runs AHEAD of the beam so
  // each `sta PFx` lands before the beam paints the half it controls — the left
  // values in HBLANK, the right values in the gap before the seam. (Exact
  // deadlines, and the tear when you miss one, are in the timing table above.)
  // ===========================================================================
  VCSAnim.register("asymmetric-pf", function (api) {
    var PF = { PF0: "#f6c6cc", PF1: "#cfe0f5", PF2: "#d2efd2" }; // diagram colors
    var ROWS = 6;
    // Six writes a line: the three registers, once for each half.
    var ASM_L = ["lda LeftPF0,y", "sta PF0", "lda LeftPF1,y", "sta PF1", "lda LeftPF2,y", "sta PF2"];
    var ASM_R = ["lda RightPF0,y", "sta PF0", "lda RightPF1,y", "sta PF1", "lda RightPF2,y", "sta PF2"];
    var CMT_L = ["fetch", "→ PF0", "fetch", "→ PF1", "fetch", "→ PF2"];
    var CMT_R = ["fetch", "→ PF0", "fetch", "→ PF1", "fetch", "→ PF2"];
    var CYC = [4, 3, 4, 3, 4, 3];        // 21 per half, 42 across the line
    var LINE_BUDGET = 76;
    var CELLS = 20;                      // playfield columns per half

    function regOf(col) { return col < 4 ? "PF0" : (col < 12 ? "PF1" : "PF2"); }
    // distinct left/right patterns so the halves clearly differ
    function leftLit(row, col) { return ((col + row) % 4) < 2; }   // diagonal
    function rightLit(row, col) { return (col % 4) < 2; }          // vertical bars
    function clampIdx(x) { return Math.max(0, Math.min(ASM_L.length - 1, x)); }

    return {
      duration: 14,   // slow by default — watch the CPU stay ahead of the beam
      height: 430,
      draw: function (ctx, t, p) {
        var c = api.colors;
        var W = api.width, H = api.height;
        var ok = c.dark ? "#33ff66" : "#1f8a3b";
        var bad = c.dark ? "#ff5a5a" : "#c8102e";
        var ink = c.dark ? "#d8d2c6" : "#2a261f";
        var pad = 16;

        ctx.fillStyle = c.subtle; ctx.fillRect(0, 0, W, H);
        ctx.textBaseline = "alphabetic";

        ctx.fillStyle = c.muted; ctx.font = "12px system-ui, sans-serif"; ctx.textAlign = "left";
        ctx.fillText("Rewrite PF0/PF1/PF2 mid-line so the two halves differ", pad, 22);

        // --- screen ------------------------------------------------------
        var scrX = pad, scrY = 36, scrW = W - pad * 2, scrH = 150;
        ctx.fillStyle = c.dark ? "#000" : "#0a0f0a";
        ctx.fillRect(scrX, scrY, scrW, scrH);
        ctx.strokeStyle = c.muted; ctx.strokeRect(scrX + 0.5, scrY + 0.5, scrW - 1, scrH - 1);
        var midX = scrX + scrW / 2;

        // --- phase machinery (same as scoreboard) -----------------------
        var phase = t * ROWS;
        var curRow = Math.min(ROWS - 1, Math.floor(phase));
        var r = phase - Math.floor(phase);
        var A = 0.28, B = 0.64;          // HBLANK ≈ 0.29, equal visible halves
        var beamX, codeBlock, codeIdx, paint;
        if (r < A) {
          beamX = scrX; codeBlock = 0;
          codeIdx = clampIdx(Math.floor((r / A) * ASM_L.length)); paint = "load";
        } else if (r < B) {
          beamX = scrX + ((r - A) / (B - A)) * (midX - scrX); codeBlock = 1;
          codeIdx = clampIdx(Math.floor(((r - A) / (B - A)) * ASM_L.length)); paint = "left";
        } else {
          beamX = midX + ((r - B) / (1 - B)) * (scrX + scrW - midX); codeBlock = -1;
          codeIdx = ASM_L.length - 1; paint = "right";
        }

        // --- the playfield band -----------------------------------------
        var cellW = (scrW / 2) / CELLS, cellH = scrH / ROWS;
        for (var row = 0; row < ROWS; row++) {
          for (var half = 0; half < 2; half++) {
            var hx = half === 0 ? scrX : midX;
            for (var col = 0; col < CELLS; col++) {
              var cellX = hx + col * cellW;
              var shown;
              if (row < curRow) shown = true;          // rows already drawn
              else if (row > curRow) shown = false;     // not yet reached
              else shown = cellX < beamX;              // current row: beam passed it
              if (!shown) continue;
              var lit = half === 0 ? leftLit(row, col) : rightLit(row, col);
              if (!lit) continue;
              ctx.fillStyle = PF[regOf(col)];
              ctx.fillRect(cellX, scrY + row * cellH, cellW - 0.5, cellH - 0.5);
            }
          }
        }

        // seam
        ctx.strokeStyle = c.muted; ctx.globalAlpha = 0.6; ctx.setLineDash([4, 4]);
        ctx.beginPath(); ctx.moveTo(midX, scrY); ctx.lineTo(midX, scrY + scrH); ctx.stroke();
        ctx.setLineDash([]); ctx.globalAlpha = 1;

        // beam dot (parked in HBLANK during phase A)
        var rowMidY = scrY + curRow * cellH + cellH / 2;
        ctx.fillStyle = c.accent;
        ctx.beginPath(); ctx.arc(beamX, rowMidY, 4, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = c.accent; ctx.globalAlpha = 0.4;
        ctx.beginPath(); ctx.moveTo(beamX, scrY); ctx.lineTo(beamX, scrY + scrH); ctx.stroke();
        ctx.globalAlpha = 1;
        if (paint === "load") {
          ctx.fillStyle = c.accent; ctx.font = "9px system-ui, sans-serif"; ctx.textAlign = "left";
          ctx.fillText("HBLANK — beam waiting", beamX + 6, scrY + 12);
        }

        // --- register readout + running cycle counter -------------------
        var ly = scrY + scrH + 22;
        var HALF = 0, i; for (i = 0; i < CYC.length; i++) HALF += CYC[i];
        var run = 0;
        if (codeBlock === 0) { for (i = 0; i <= codeIdx; i++) run += CYC[i]; }
        else if (codeBlock === 1) { run = HALF; for (i = 0; i <= codeIdx; i++) run += CYC[i]; }
        else { run = HALF * 2; }
        var underBudget = run <= LINE_BUDGET;

        ctx.textAlign = "left"; ctx.font = "13px ui-monospace, Menlo, monospace";
        ctx.fillStyle = ink;
        ctx.fillText("PF0 PF1 PF2  " + (paint === "load" ? "← left values"
          : paint === "left" ? "= left values (painting)" : "= right values (painting)"), pad, ly);

        ctx.textAlign = "right"; ctx.font = "bold 13px ui-monospace, Menlo, monospace";
        ctx.fillStyle = underBudget ? ok : bad;
        ctx.fillText(run + " / " + LINE_BUDGET + " cyc", W - pad, ly);
        var cbW = 150, cbX = W - pad - cbW, cbY = ly + 6, cbH = 5;
        ctx.fillStyle = c.card; ctx.fillRect(cbX, cbY, cbW, cbH);
        ctx.strokeStyle = c.border; ctx.strokeRect(cbX + 0.5, cbY + 0.5, cbW - 1, cbH - 1);
        ctx.fillStyle = underBudget ? ok : bad;
        ctx.fillRect(cbX, cbY, Math.min(run / LINE_BUDGET, 1) * cbW, cbH);
        ctx.textAlign = "left";

        // --- assembly columns -------------------------------------------
        var colW = (W - pad * 3) / 2;
        var col0X = pad, col1X = pad + colW + pad;
        var hdrY = ly + 26, lineH = 16, codeTop = hdrY + 18;
        var activeIdx = codeIdx;
        function drawColumn(x, header, asm, cmt, isActive) {
          ctx.textAlign = "left";
          ctx.globalAlpha = isActive ? 1 : 0.45;
          ctx.font = "bold 11px ui-monospace, Menlo, monospace";
          ctx.fillStyle = ink; ctx.fillText(header, x, hdrY);
          ctx.font = "11px ui-monospace, Menlo, monospace";
          for (var k = 0; k < asm.length; k++) {
            var y = codeTop + k * lineH;
            var cur = isActive && k === activeIdx;
            if (cur) {
              ctx.globalAlpha = 0.18; ctx.fillStyle = c.accent;
              ctx.fillRect(x - 4, y - 11, colW - 8, lineH - 1); ctx.globalAlpha = 1;
            }
            ctx.fillStyle = cur ? c.accent : ink;
            ctx.globalAlpha = isActive ? 1 : 0.45;
            ctx.fillText(asm[k], x, y);
            ctx.fillStyle = c.muted; ctx.fillText("; " + cmt[k], x + colW * 0.5, y);
            ctx.textAlign = "right"; ctx.fillStyle = cur ? c.accent : c.muted;
            ctx.fillText(CYC[k] + "c", x + colW - 8, y);
            ctx.textAlign = "left";
          }
          ctx.globalAlpha = 1;
        }
        drawColumn(col0X, "LeftHalf:  ; left values", ASM_L, CMT_L, codeBlock === 0);
        drawColumn(col1X, "RightHalf: ; the rewrite", ASM_R, CMT_R, codeBlock === 1);

        // footer: phase note + the "why only where needed" reminder
        var footY = codeTop + ASM_L.length * lineH + 12;
        var phaseMsg = paint === "load"
          ? "Phase A — HBLANK: write the registers' LEFT values before any pixel paints."
          : paint === "left"
          ? "Phase B — left half painting while the CPU rewrites PF0/PF1/PF2 for the right."
          : "Phase C — right half painting from the rewritten registers.";
        ctx.fillStyle = ink; ctx.font = "bold 10px system-ui, sans-serif"; ctx.textAlign = "left";
        ctx.fillText(phaseMsg, pad, footY);
        ctx.fillStyle = c.muted; ctx.font = "10px system-ui, sans-serif";
        ctx.fillText("Six writes a line — each register, twice — is why asymmetry is spent only where needed.",
          pad, footY + 15);
      },
    };
  });

  // ===========================================================================
  // SCENE: "scoreboard" — building a two-player score with mid-line PF1 rewrites
  // ===========================================================================
  //
  // A two-digit-per-side scoreboard is the canonical asymmetric playfield: ONE
  // register, PF1, written twice per scanline. As the beam crosses the score
  // band the kernel loads PF1 with player 0's digit row for the LEFT half, then
  // rewrites PF1 with player 1's row before the beam reaches the RIGHT half.
  // Score mode (CTRLPF D1) paints the left half in COLUP0 and the right in
  // COLUP1, so each score comes out in its player's color for free.
  //
  // Digits use a chunky 3x5 playfield font; each digit is one nibble (3 px of
  // shape + a 1 px gap), so one row of two digits is a single PF1 byte — exactly
  // the "store the font doubled" trick from the page.
  // ===========================================================================
  VCSAnim.register("scoreboard", function (api) {
    var FONT = {
      "0": ["111", "101", "101", "101", "111"],
      "1": ["010", "110", "010", "010", "111"],
      "2": ["111", "001", "111", "100", "111"],
      "3": ["111", "001", "111", "001", "111"],
      "4": ["101", "101", "111", "001", "001"],
      "5": ["111", "100", "111", "001", "111"],
      "6": ["111", "100", "111", "101", "111"],
      "7": ["111", "001", "010", "100", "100"],
      "8": ["111", "101", "111", "101", "111"],
      "9": ["111", "101", "111", "001", "111"],
    };
    var ROWS = 5;

    // Per-row kernel: 7 instructions a half (fetch, mask, combine, store),
    // run twice — once for each player — chasing the beam across the line.
    var ASM0 = ["lda P0Tens,y", "and #$F0", "sta Temp", "lda P0Ones,y", "and #$0F", "ora Temp", "sta PF1"];
    var CMT0 = ["tens row", "high nibble", "stash", "ones row", "low nibble", "combine", "draw LEFT"];
    var ASM1 = ["lda P1Tens,y", "and #$F0", "sta Temp", "lda P1Ones,y", "and #$0F", "ora Temp", "sta PF1"];
    var CMT1 = ["tens row", "high nibble", "stash", "ones row", "low nibble", "combine", "rewrite!"];
    // Cycle cost of each instruction (lda abs,Y 4 · and # 2 · sta zp 3 · …).
    var CYC = [4, 2, 3, 4, 2, 3, 3];        // 21 per half, 42 across the line
    var LINE_BUDGET = 76;

    function two(n) {
      n = Math.max(0, Math.min(99, Math.round(n || 0)));
      return (n < 10 ? "0" : "") + n;
    }
    function nibble(bits3) { return parseInt(bits3 + "0", 2); } // 3 shape bits + gap
    function pf1Byte(num, row) {
      var s = two(num);
      return (nibble(FONT[s.charAt(0)][row]) << 4) | nibble(FONT[s.charAt(1)][row]);
    }
    function bin8(v) { var s = v.toString(2); while (s.length < 8) s = "0" + s; return s; }

    return {
      duration: 14,   // slow by default so the CPU's lead over the beam is readable
      height: 430,
      controls: [
        { id: "p0", label: "Player 0 score", min: 0, max: 99, step: 1, value: 42 },
        { id: "p1", label: "Player 1 score", min: 0, max: 99, step: 1, value: 17 },
      ],
      draw: function (ctx, t, p) {
        var c = api.colors;
        var W = api.width, H = api.height;
        var p0col = c.dark ? "#5ac8fa" : "#0f6fb5"; // COLUP0
        var p1col = c.dark ? "#ffd24a" : "#c98a00"; // COLUP1
        var s0 = two(p.p0), s1 = two(p.p1);
        var pad = 16;

        ctx.fillStyle = c.subtle;
        ctx.fillRect(0, 0, W, H);
        ctx.textBaseline = "alphabetic";

        ctx.fillStyle = c.muted;
        ctx.font = "12px system-ui, sans-serif";
        ctx.textAlign = "left";
        ctx.fillText("One register (PF1), written twice a line — left score, then right", pad, 22);

        // --- screen with the score band ----------------------------------
        var scrX = pad, scrY = 36, scrW = W - pad * 2, scrH = 150;
        ctx.fillStyle = c.dark ? "#000" : "#0a0f0a";
        ctx.fillRect(scrX, scrY, scrW, scrH);
        ctx.strokeStyle = c.muted;
        ctx.strokeRect(scrX + 0.5, scrY + 0.5, scrW - 1, scrH - 1);

        var midX = scrX + scrW / 2;
        ctx.strokeStyle = c.muted; ctx.globalAlpha = 0.5; ctx.setLineDash([4, 4]);
        ctx.beginPath(); ctx.moveTo(midX, scrY); ctx.lineTo(midX, scrY + scrH); ctx.stroke();
        ctx.setLineDash([]); ctx.globalAlpha = 1;

        // Each row runs in three phases so the CPU stays AHEAD of the beam —
        // every `sta PF1` lands before the beam paints the half it controls:
        //   A  load PF1: beam parked in HBLANK, run the LEFT block (ends sta PF1)
        //   B  paint left in P0's value WHILE running the RIGHT block (ends sta PF1
        //      before the seam)
        //   C  paint right in P1's value; the CPU's work for this line is done
        var phase = t * ROWS;
        var curRow = Math.min(ROWS - 1, Math.floor(phase));
        var r = phase - Math.floor(phase);   // 0..1 within this row
        // Phase boundaries chosen to mirror the real line: HBLANK is ~22 of 76
        // cycles (≈0.29), and the two visible halves are equal (0.36 each).
        var A = 0.28, B = 0.64;
        function clampIdx(x) { return Math.max(0, Math.min(ASM0.length - 1, x)); }

        var beamX, codeBlock, codeIdx, paint; // codeBlock: 0=left 1=right -1=idle
        if (r < A) {                          // phase A — load PF1 for the left
          beamX = scrX;
          codeBlock = 0; codeIdx = clampIdx(Math.floor((r / A) * ASM0.length));
          paint = "load";
        } else if (r < B) {                   // phase B — paint left, compute right
          beamX = scrX + ((r - A) / (B - A)) * (midX - scrX);
          codeBlock = 1; codeIdx = clampIdx(Math.floor(((r - A) / (B - A)) * ASM0.length));
          paint = "left";
        } else {                              // phase C — paint right
          beamX = midX + ((r - B) / (1 - B)) * (scrX + scrW - midX);
          codeBlock = -1; codeIdx = ASM0.length - 1;
          paint = "right";
        }

        var halfW = scrW / 2;
        var cellW = (halfW * 0.6) / 7; // 7 cols: 3 + 1 gap + 3
        var cellH = (scrH * 0.7) / ROWS;
        var oy = scrY + (scrH - ROWS * cellH) / 2;

        function drawNumber(numStr, halfX, color) {
          var blockW = 7 * cellW;
          var ox = halfX + (halfW - blockW) / 2;
          for (var d = 0; d < 2; d++) {
            var glyph = FONT[numStr.charAt(d)];
            var dx = ox + d * 4 * cellW; // 3 cols + 1 gap
            for (var ry = 0; ry < ROWS; ry++) {
              for (var col = 0; col < 3; col++) {
                if (glyph[ry].charAt(col) !== "1") continue;
                var cellX = dx + col * cellW;
                var shown;
                if (ry < curRow) shown = true;          // rows already drawn
                else if (ry > curRow) shown = false;     // not yet reached
                else shown = cellX < beamX;              // current row: beam passed it
                if (!shown) continue;
                ctx.fillStyle = color;
                ctx.fillRect(cellX, oy + ry * cellH, cellW - 1, cellH - 1);
              }
            }
          }
        }
        drawNumber(s0, scrX, p0col);
        drawNumber(s1, midX, p1col);

        // beam dot on the current row (parked in HBLANK during phase A)
        var rowMidY = oy + curRow * cellH + cellH / 2;
        ctx.fillStyle = c.accent;
        ctx.beginPath(); ctx.arc(beamX, rowMidY, 4, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = c.accent; ctx.globalAlpha = 0.4;
        ctx.beginPath(); ctx.moveTo(beamX, scrY); ctx.lineTo(beamX, scrY + scrH); ctx.stroke();
        ctx.globalAlpha = 1;
        if (paint === "load") {
          ctx.fillStyle = c.accent; ctx.font = "9px system-ui, sans-serif"; ctx.textAlign = "left";
          ctx.fillText("HBLANK — beam waiting", beamX + 6, scrY + 12);
        }

        // half color labels
        ctx.font = "10px system-ui, sans-serif"; ctx.textAlign = "center";
        ctx.fillStyle = p0col; ctx.fillText("COLUP0 (left)", scrX + halfW / 2, scrY + scrH - 8);
        ctx.fillStyle = p1col; ctx.fillText("COLUP1 (right)", midX + halfW / 2, scrY + scrH - 8);

        // --- running cycle total: the CPU's progress through this line ----
        var activeIdx = codeIdx;
        var HALF = 0, i;
        for (i = 0; i < CYC.length; i++) HALF += CYC[i];   // 21 cyc per half
        var run = 0;
        if (codeBlock === 0) {                              // running the left block
          for (i = 0; i <= codeIdx; i++) run += CYC[i];
        } else if (codeBlock === 1) {                       // left done, running right
          run = HALF; for (i = 0; i <= codeIdx; i++) run += CYC[i];
        } else {                                            // both blocks done
          run = HALF * 2;
        }
        var underBudget = run <= LINE_BUDGET;
        var ok = c.dark ? "#33ff66" : "#1f8a3b";
        var bad = c.dark ? "#ff5a5a" : "#c8102e";

        // --- PF1 readout + running cycle counter -------------------------
        var ly = scrY + scrH + 22;
        var isRightPaint = paint === "right";
        var pfNum = isRightPaint ? p.p1 : p.p0;   // what PF1 holds right now
        var pfCol = isRightPaint ? p1col : p0col;
        var arrow = paint === "load" ? "←" : "=";  // being written vs. driving paint
        var curByte = pf1Byte(pfNum, curRow);
        ctx.textAlign = "left"; ctx.font = "13px ui-monospace, Menlo, monospace";
        ctx.fillStyle = pfCol;
        ctx.fillText("PF1 " + arrow + " " + (isRightPaint ? "P1" : "P0") + "  (row " +
          (curRow + 1) + ")  =  %" + bin8(curByte), pad, ly);

        // cycle counter, right-aligned, green while under budget
        ctx.textAlign = "right"; ctx.font = "bold 13px ui-monospace, Menlo, monospace";
        ctx.fillStyle = underBudget ? ok : bad;
        ctx.fillText(run + " / " + LINE_BUDGET + " cyc", W - pad, ly);
        // thin budget bar beneath the counter
        var cbW = 150, cbX = W - pad - cbW, cbY = ly + 6, cbH = 5;
        ctx.fillStyle = c.card; ctx.fillRect(cbX, cbY, cbW, cbH);
        ctx.strokeStyle = c.border; ctx.strokeRect(cbX + 0.5, cbY + 0.5, cbW - 1, cbH - 1);
        ctx.fillStyle = underBudget ? ok : bad;
        ctx.fillRect(cbX, cbY, Math.min(run / LINE_BUDGET, 1) * cbW, cbH);
        ctx.textAlign = "left";

        var colW = (W - pad * 3) / 2;
        var col0X = pad, col1X = pad + colW + pad;
        var hdrY = ly + 26, lineH = 16, codeTop = hdrY + 18;

        function drawColumn(x, header, hdrColor, asm, cmt, isActive) {
          ctx.textAlign = "left";
          ctx.globalAlpha = isActive ? 1 : 0.45;
          ctx.font = "bold 11px ui-monospace, Menlo, monospace";
          ctx.fillStyle = hdrColor;
          ctx.fillText(header, x, hdrY);
          ctx.font = "11px ui-monospace, Menlo, monospace";
          for (var i = 0; i < asm.length; i++) {
            var y = codeTop + i * lineH;
            if (isActive && i === activeIdx) {
              ctx.globalAlpha = 0.18; ctx.fillStyle = c.accent;
              ctx.fillRect(x - 4, y - 11, colW - 8, lineH - 1);
              ctx.globalAlpha = 1;
            }
            var cur = isActive && i === activeIdx;
            ctx.fillStyle = cur ? c.accent : (c.dark ? "#d8d2c6" : "#2a261f");
            ctx.globalAlpha = isActive ? 1 : 0.45;
            ctx.fillText(asm[i], x, y);
            ctx.fillStyle = c.muted;
            ctx.fillText("; " + cmt[i], x + colW * 0.46, y);
            // per-instruction cycle cost, right-aligned in the column
            ctx.textAlign = "right";
            ctx.fillStyle = cur ? c.accent : c.muted;
            ctx.fillText(CYC[i] + "c", x + colW - 8, y);
            ctx.textAlign = "left";
          }
          ctx.globalAlpha = 1;
        }
        drawColumn(col0X, "LeftHalf:  ; player 0", p0col, ASM0, CMT0, codeBlock === 0);
        drawColumn(col1X, "RightHalf: ; player 1", p1col, ASM1, CMT1, codeBlock === 1);

        // footer: live phase status + the score-mode note
        var footY = codeTop + ASM0.length * lineH + 10;
        var phaseMsg = paint === "load"
          ? "Phase A — HBLANK: load PF1 with player 0 before any pixel is drawn."
          : paint === "left"
          ? "Phase B — left half painting (P0) while the CPU already computes player 1."
          : "Phase C — right half painting (P1); its sta PF1 landed before the seam.";
        ctx.fillStyle = pfCol; ctx.font = "bold 10px system-ui, sans-serif"; ctx.textAlign = "left";
        ctx.fillText(phaseMsg, pad, footY);
        ctx.fillStyle = c.muted; ctx.font = "10px system-ui, sans-serif";
        ctx.fillText("Score mode (CTRLPF D1) tints each half its player's color — no per-line color writes.",
          pad, footY + 15);
      },
    };
  });

  // ===========================================================================
  // SCENE: "resp0-hmove" — coarse strobe + fine HMOVE
  // ===========================================================================
  //
  // A player has no X register. STA RESP0 is a strobe: it snaps the sprite to
  // wherever the beam is *right now*, so position is chosen by *when* the store
  // runs — coarse, landing only near every ~15th color clock. HMP0 (a signed
  // nudge, +7 left to -8 right) plus STA HMOVE slides it the final few clocks.
  // HMOVE also blanks the leftmost 8 pixels: the "HMOVE comb."
  // ===========================================================================
  VCSAnim.register("resp0-hmove", function (api) {
    var CLOCKS = 152;   // visible span we let the sprite roam
    var STEP = 15;      // coarse granularity (~every 15th clock)
    var SPRITE_W = 8;

    return {
      duration: 5,
      height: 300,
      controls: [
        { id: "strobe", label: "Strobe cycle", min: 0, max: CLOCKS, step: 1, value: 60 },
        { id: "hmp0",   label: "HMP0 (+left/−right)", min: -8, max: 7, step: 1, value: 0 },
      ],
      draw: function (ctx, t, p) {
        var c = api.colors;
        var W = api.width, H = api.height;
        var accent = c.accent, ok = c.dark ? "#33ff66" : "#1f8a3b";
        var pad = 18;
        var stripX = pad, stripW = W - pad * 2;
        function px(clk) { return stripX + (clk / CLOCKS) * stripW; }

        var strobe = Math.round(p.strobe || 0);
        var hmp0 = Math.round(p.hmp0 || 0);
        var coarse = Math.round(strobe / STEP) * STEP;        // snap to ~15th
        var finalClk = Math.max(0, Math.min(CLOCKS, coarse - hmp0)); // +HMP0 = left
        var usedHmove = hmp0 !== 0;

        ctx.fillStyle = c.subtle;
        ctx.fillRect(0, 0, W, H);
        ctx.textBaseline = "alphabetic";

        // --- title -------------------------------------------------------
        ctx.fillStyle = c.muted; ctx.font = "12px system-ui, sans-serif"; ctx.textAlign = "left";
        ctx.fillText("Position by timing: strobe RESP0, then nudge with HMOVE", pad, 22);

        // --- the scanline strip ------------------------------------------
        var stripY = 70, stripH = 56;
        ctx.fillStyle = c.dark ? "#000" : "#0a0f0a";
        ctx.fillRect(stripX, stripY, stripW, stripH);
        ctx.strokeStyle = c.muted;
        ctx.strokeRect(stripX + 0.5, stripY + 0.5, stripW - 1, stripH - 1);

        // coarse landing ticks every 15 clocks
        ctx.strokeStyle = c.border; ctx.globalAlpha = 0.6;
        for (var k = 0; k <= CLOCKS; k += STEP) {
          ctx.beginPath(); ctx.moveTo(px(k), stripY + stripH - 8); ctx.lineTo(px(k), stripY + stripH); ctx.stroke();
        }
        ctx.globalAlpha = 1;

        // HMOVE comb: leftmost 8 pixels blanked when HMOVE is used
        if (usedHmove) {
          var combW = (SPRITE_W / CLOCKS) * stripW;
          ctx.fillStyle = c.dark ? "#1a1a1a" : "#000";
          for (var n = 0; n < 4; n++) {
            ctx.fillRect(stripX + (n / 4) * combW, stripY, (combW / 4) * 0.6, stripH);
          }
          ctx.fillStyle = c.muted; ctx.font = "9px system-ui, sans-serif"; ctx.textAlign = "left";
          ctx.fillText("HMOVE comb", stripX + combW + 3, stripY + stripH - 4);
        }

        // --- beam sweep; RESP0 fires when the beam reaches the strobe ----
        var beamClk = t * CLOCKS;
        var fired = beamClk >= strobe;
        ctx.strokeStyle = accent; ctx.globalAlpha = 0.5;
        ctx.beginPath(); ctx.moveTo(px(beamClk), stripY - 6); ctx.lineTo(px(beamClk), stripY + stripH + 6); ctx.stroke();
        ctx.globalAlpha = 1;
        // strobe marker
        ctx.strokeStyle = accent; ctx.setLineDash([3, 2]);
        ctx.beginPath(); ctx.moveTo(px(strobe), stripY - 10); ctx.lineTo(px(strobe), stripY + stripH); ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = accent; ctx.font = "9px system-ui, sans-serif"; ctx.textAlign = "center";
        ctx.fillText("STA RESP0", px(strobe), stripY - 12);
        if (fired && beamClk < strobe + 12) {
          ctx.fillStyle = accent; ctx.font = "bold 11px system-ui, sans-serif";
          ctx.fillText("snap!", px(strobe), stripY + stripH + 16);
        }

        // --- sprites: coarse ghost + final, with nudge arrow ------------
        function drawSprite(clk, alpha, color) {
          ctx.globalAlpha = alpha; ctx.fillStyle = color;
          ctx.fillRect(px(clk), stripY + 12, (SPRITE_W / CLOCKS) * stripW, stripH - 24);
          ctx.globalAlpha = 1;
        }
        if (fired) drawSprite(coarse, 0.4, c.muted);   // coarse landing (ghost)
        drawSprite(finalClk, 1, ok);                    // final position

        // nudge arrow coarse -> final
        if (fired && coarse !== finalClk) {
          var y = stripY + stripH / 2;
          ctx.strokeStyle = accent; ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(px(coarse) + 3, y); ctx.lineTo(px(finalClk) + 3, y); ctx.stroke();
          ctx.lineWidth = 1;
        }

        // --- readout -----------------------------------------------------
        var ry = stripY + stripH + 40;
        ctx.textAlign = "left"; ctx.font = "12px ui-monospace, Menlo, monospace";
        ctx.fillStyle = c.muted;
        ctx.fillText("coarse (RESP0): clock " + coarse + "   (≈ every " + STEP + "th)", pad, ry);
        ctx.fillStyle = ok;
        var dir = hmp0 > 0 ? "left" : (hmp0 < 0 ? "right" : "—");
        ctx.fillText("HMP0 = " + (hmp0 >= 0 ? "+" : "") + hmp0 + "  →  nudge " + dir +
          "  →  final clock " + finalClk, pad, ry + 20);
        ctx.fillStyle = c.muted; ctx.font = "10px system-ui, sans-serif";
        ctx.fillText("Positive HMP0 moves left, negative moves right — the most-flipped sign in VCS code.", pad, ry + 40);
      },
    };
  });

  // ===========================================================================
  // SCENE: "crt-scan" — how a CRT television paints a picture (pure TV terms)
  // ===========================================================================
  //
  // A single electron beam sweeps left→right (one scanline), snaps back during
  // horizontal blank, repeats down the screen, then snaps back to the top during
  // vertical blank — one frame. The set keeps the beam locked to the signal's
  // sync pulses; lose that lock and the picture rolls (no vertical sync) or
  // tears (unstable horizontal sync). The Vertical/Horizontal Hold sliders are
  // the old back-panel knobs: centered = locked, off-center = drifting.
  //
  // No VCS concepts here — just a beam, a clock, and a test pattern.
  // ===========================================================================
  VCSAnim.register("crt-scan", function (api) {
    var BARS = ["#f0f0f0", "#f0f000", "#00f0f0", "#00f000", "#f000f0", "#f00000", "#0000f0"];
    var NLINES = 22;          // visible left→right sweeps per top→bottom pass
    function frac(x) { return x - Math.floor(x); }

    // The test card, drawn in local coords (0..w, 0..h). Vertical structure
    // (blank bar, bars, gradient, blocks) makes vertical roll visible.
    function drawPattern(ctx, w, h) {
      ctx.fillStyle = "#000";
      ctx.fillRect(0, 0, w, h * 0.06);                 // inter-frame blanking bar
      var by = h * 0.06, bh = h * 0.52, bw = w / BARS.length;
      for (var i = 0; i < BARS.length; i++) {          // color bars
        ctx.fillStyle = BARS[i];
        ctx.fillRect(i * bw, by, bw + 1, bh);
      }
      var gy = h * 0.58, gh = h * 0.14, steps = 16;    // grayscale gradient
      for (var s = 0; s < steps; s++) {
        var v = Math.round((s / (steps - 1)) * 255);
        ctx.fillStyle = "rgb(" + v + "," + v + "," + v + ")";
        ctx.fillRect((s / steps) * w, gy, w / steps + 1, gh);
      }
      var blk = ["#0000f0", "#101010", "#f000f0", "#101010", "#00f000", "#101010"];
      var ky = h * 0.72, kh = h * 0.28, kw = w / blk.length;
      for (var k = 0; k < blk.length; k++) {
        ctx.fillStyle = blk[k];
        ctx.fillRect(k * kw, ky, kw + 1, kh);
      }
    }

    return {
      duration: 4,            // one full top→bottom beam pass per cycle
      height: 380,
      controls: [
        { id: "vhold", label: "Vertical Hold", min: -1, max: 1, step: 0.05, value: 0 },
        { id: "hhold", label: "Horizontal Hold", min: -1, max: 1, step: 0.05, value: 0 },
      ],
      draw: function (ctx, t, p) {
        var c = api.colors;
        var W = api.width, H = api.height;
        var pad = 16;
        var ok = c.dark ? "#33ff66" : "#1f8a3b";
        var bad = c.dark ? "#ff5a5a" : "#c8102e";

        ctx.fillStyle = c.subtle; ctx.fillRect(0, 0, W, H);
        ctx.textBaseline = "alphabetic";
        ctx.fillStyle = c.muted; ctx.font = "12px system-ui, sans-serif"; ctx.textAlign = "left";
        ctx.fillText("One beam, scanning line by line — the whole picture is just timing", pad, 22);

        // --- screen (CRT face) ------------------------------------------
        var scrX = pad, scrY = 38, scrW = W - pad * 2, scrH = 250;

        // sync state from the "knobs"
        var vhold = p.vhold || 0, hhold = p.hhold || 0;
        var rollCycles = Math.round(vhold * 4);          // integer → seamless wrap
        var rollOff = frac(t * rollCycles);              // 0 when locked
        var k = hhold * 0.45;                            // shear slope (tear)
        var rollPx = rollOff * scrH;

        // black backing so sheared corners read as torn-off (black) edges
        ctx.fillStyle = "#000";
        ctx.fillRect(scrX, scrY, scrW, scrH);

        // draw the (rolled, sheared) picture, clipped to the screen
        ctx.save();
        ctx.beginPath(); ctx.rect(scrX, scrY, scrW, scrH); ctx.clip();
        ctx.translate(scrX, scrY);
        ctx.transform(1, 0, k, 1, 0, 0);                 // horizontal shear by y
        ctx.save(); ctx.translate(0, rollPx); drawPattern(ctx, scrW, scrH); ctx.restore();
        ctx.save(); ctx.translate(0, rollPx - scrH); drawPattern(ctx, scrW, scrH); ctx.restore();
        ctx.restore();

        // screen bezel
        ctx.strokeStyle = c.muted; ctx.lineWidth = 1;
        ctx.strokeRect(scrX + 0.5, scrY + 0.5, scrW - 1, scrH - 1);

        // --- the beam: steady raster, independent of the rolling picture -
        var beamV = t;                                   // 0..1 down the screen
        var beamY = scrY + beamV * scrH;
        var beamH = frac(t * NLINES);                    // 0..1 across the line
        var beamX = scrX + beamH * scrW;
        // current scanline highlight
        ctx.fillStyle = c.dark ? "rgba(255,255,255,0.18)" : "rgba(255,255,255,0.30)";
        ctx.fillRect(scrX, beamY - 1, scrW, 2);
        // the part of this line already swept (trail) + the beam dot
        ctx.strokeStyle = "rgba(255,255,255,0.45)"; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(scrX, beamY); ctx.lineTo(beamX, beamY); ctx.stroke();
        ctx.lineWidth = 1;
        ctx.fillStyle = "#fff";
        ctx.beginPath(); ctx.arc(beamX, beamY, 3.5, 0, Math.PI * 2); ctx.fill();

        // HBLANK / VBLANK call-outs as the beam retraces
        ctx.font = "9px system-ui, sans-serif"; ctx.textAlign = "right";
        if (beamH > 0.9) {
          ctx.fillStyle = "#fff";
          ctx.fillText("HBLANK ↩", scrX + scrW - 4, beamY - 4);
        }
        if (beamV > 0.93) {
          ctx.fillStyle = "#fff"; ctx.textAlign = "center";
          ctx.fillText("VBLANK — retrace to top", scrX + scrW / 2, scrY + 12);
        }

        // --- status line -------------------------------------------------
        var ly = scrY + scrH + 24;
        var rolling = rollCycles !== 0, tearing = Math.abs(k) > 0.02;
        ctx.textAlign = "left"; ctx.font = "bold 13px system-ui, sans-serif";
        if (!rolling && !tearing) {
          ctx.fillStyle = ok;
          ctx.fillText("LOCKED — sync holding the picture steady", pad, ly);
        } else {
          ctx.fillStyle = bad;
          var msg = [];
          if (rolling) msg.push("VERTICAL ROLL (no vertical-sync lock)");
          if (tearing) msg.push("HORIZONTAL TEAR (unstable horizontal sync)");
          ctx.fillText(msg.join("   ·   "), pad, ly);
        }
        ctx.fillStyle = c.muted; ctx.font = "11px system-ui, sans-serif";
        ctx.fillText("Center both Holds to re-lock — exactly what the back-panel knobs did.", pad, ly + 20);
      },
    };
  });
  // ---------------------------------------------------------------------------
  // Auto-init — runs only after every scene above has registered. With a
  // deferred <script> the DOM is already parsed, so mount immediately;
  // otherwise wait for DOMContentLoaded.
  // ---------------------------------------------------------------------------
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", VCSAnim.mountAll);
  } else {
    VCSAnim.mountAll();
  }
})();
