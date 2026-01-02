// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/star_tickets"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const PhoneMask = {
  mounted() {
    this.el.addEventListener("input", (e) => {
      let v = e.target.value.replace(/\D/g, "");
      // Truncate to max 13 digits (2 country + 2 area + 9 number)
      if (v.length > 13) v = v.substring(0, 13);

      let formatted = "";

      if (v.length > 0) {
        formatted = "+" + v.substring(0, 2);
      }
      if (v.length > 2) {
        formatted += " (" + v.substring(2, 4);
      }
      if (v.length > 4) {
        formatted += ") " + v.substring(4, 9);
      }
      if (v.length > 9) {
        formatted = "+" + v.substring(0, 2) + " (" + v.substring(2, 4) + ") " + v.substring(4, 9) + "-" + v.substring(9, 13);
      }

      // Simple regex approach for varying length
      // +55 (11) 98888-8888
      // If length is small (e.g. 12 digits total = landline), adjust?
      // User asked for 0000-0000 (8 digits number) or 00000-0000 (9 digits).
      // Let's stick to a robust formatter.

      // Re-implementing more robust logic:
      v = e.target.value.replace(/\D/g, "");
      let f = "";

      if (v.length > 0) f += "+" + v.substring(0, 2);
      if (v.length > 2) f += " (" + v.substring(2, 4) + ") ";

      if (v.length > 4) {
        if (v.length < 13) {
          // 8 digit number logic (Total 12: 2+2+8)
          // +55 (11) 0000-0000
          // But while typing we don't know yet.
          // Standard approach: fill until hyphen position
          // 12 digits: +55 (11) 9999-9999
          // 13 digits: +55 (11) 99999-9999

          if (v.length <= 9) { // Up to 5 digits in first part
            f += v.substring(4);
          } else {
            // We have more than 5 digits for the number part (total > 9)
            // Split is tricky during typing.
            // Let's just format as XXXXX-XXXX if > 12 chars total, or XXXX-XXXX if 12.
          }
        }
      }

      // Simplified robust replacement for exact requested format + variant
      // 1. DDI (2)
      // 2. DDD (2)
      // 3. Number (8 or 9)

      v = v.substring(0, 13); // Max 13 digits (55 11 98888 8888)

      if (v.length <= 2) {
        e.target.value = "+" + v;
      } else if (v.length <= 4) {
        e.target.value = "+" + v.substring(0, 2) + " (" + v.substring(2);
      } else if (v.length <= 8) {
        e.target.value = "+" + v.substring(0, 2) + " (" + v.substring(2, 4) + ") " + v.substring(4);
      } else if (v.length <= 12) {
        // Landline style or incomplete mobile: +55 (11) 4444-4444
        e.target.value = "+" + v.substring(0, 2) + " (" + v.substring(2, 4) + ") " + v.substring(4, 8) + "-" + v.substring(8);
      } else {
        // Mobile style: +55 (11) 98888-8888
        e.target.value = "+" + v.substring(0, 2) + " (" + v.substring(2, 4) + ") " + v.substring(4, 9) + "-" + v.substring(9);
      }
    });
  }
}

const AutoClearFlash = {
  mounted() {
    setTimeout(() => {
      this.pushEvent("lv:clear-flash", { key: this.el.dataset.kind })
    }, 5000)
  }
}

// Totem sound effects hook
const TotemSounds = {
  mounted() {
    // Create audio context for generating sounds
    this.audioContext = null;

    // Handle custom sound events from LiveView
    this.handleEvent("play_sound", ({ sound }) => {
      this.playSound(sound);
    });
  },

  playSound(type) {
    // Lazy init audio context (needs user interaction first)
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    }

    const ctx = this.audioContext;
    const now = ctx.currentTime;

    switch (type) {
      case "click":
        // Short click sound
        this.playTone(ctx, 800, 0.05, "sine", 0.3);
        break;
      case "select":
        // Selection toggle sound
        this.playTone(ctx, 600, 0.08, "sine", 0.3);
        setTimeout(() => this.playTone(ctx, 900, 0.08, "sine", 0.3), 50);
        break;
      case "success":
        // Success chime (ascending)
        this.playTone(ctx, 523, 0.1, "sine", 0.4);
        setTimeout(() => this.playTone(ctx, 659, 0.1, "sine", 0.4), 100);
        setTimeout(() => this.playTone(ctx, 784, 0.15, "sine", 0.4), 200);
        break;
      case "back":
        // Back/cancel sound (descending)
        this.playTone(ctx, 400, 0.08, "sine", 0.3);
        break;
      case "clear":
        // Clear all sound
        this.playTone(ctx, 300, 0.1, "triangle", 0.3);
        break;
      case "confirm":
        // Confirmation sound
        this.playTone(ctx, 440, 0.1, "sine", 0.4);
        setTimeout(() => this.playTone(ctx, 660, 0.1, "sine", 0.4), 80);
        setTimeout(() => this.playTone(ctx, 880, 0.2, "sine", 0.4), 160);
        break;
    }
  },

  playTone(ctx, frequency, duration, type, volume) {
    const oscillator = ctx.createOscillator();
    const gainNode = ctx.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(ctx.destination);

    oscillator.type = type;
    oscillator.frequency.value = frequency;

    gainNode.gain.setValueAtTime(volume, ctx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + duration);

    oscillator.start(ctx.currentTime);
    oscillator.stop(ctx.currentTime + duration);
  }
}

const DeskPreference = {
  mounted() {
    // 1. Try to restore from cookie on mount
    const deskId = this.getCookie("reception_desk_id");
    if (deskId) {
      this.pushEvent("restore_desk_preference", { id: deskId });
    }

    // 2. Listen for save requests from server
    this.handleEvent("save_desk_preference", ({ id }) => {
      this.setCookie("reception_desk_id", id, 365); // Save for 1 year
    });
  },

  setCookie(name, value, days) {
    let expires = "";
    if (days) {
      const date = new Date();
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = "; expires=" + date.toUTCString();
    }
    document.cookie = name + "=" + (value || "") + expires + "; path=/";
  },

  getCookie(name) {
    const nameEQ = name + "=";
    const ca = document.cookie.split(';');
    for (let i = 0; i < ca.length; i++) {
      let c = ca[i];
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
    }
    return null;
  }
}

const RoomPreference = {
  mounted() {
    const roomId = this.getCookie("professional_room_id");
    if (roomId) {
      this.pushEvent("restore_room_preference", { id: roomId });
    }

    this.handleEvent("save_room_preference", ({ id }) => {
      this.setCookie("professional_room_id", id, 365);
    });
  },

  setCookie(name, value, days) {
    let expires = "";
    if (days) {
      const date = new Date();
      date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
      expires = "; expires=" + date.toUTCString();
    }
    document.cookie = name + "=" + (value || "") + expires + "; path=/";
  },

  getCookie(name) {
    const nameEQ = name + "=";
    const ca = document.cookie.split(';');
    for (let i = 0; i < ca.length; i++) {
      let c = ca[i];
      while (c.charAt(0) == ' ') c = c.substring(1, c.length);
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
    }
    return null;
  }
}


const AutoFocus = {
  mounted() {
    this.el.focus();
    this.el.select();
  },

  updated() {
    // Re-focus on update if still the same element
    if (document.activeElement !== this.el) {
      this.el.focus();
    }
  }
}

// TV Sound and TTS Hook
const TVSound = {
  mounted() {
    // Create audio context lazily
    this.audioContext = null;

    // Handle sound events
    this.handleEvent("play_alert", () => {
      this.playDingDong();
    });

    // Handle TTS events
    this.handleEvent("speak", ({ text }) => {
      this.speak(text);
    });

    // Resume audio context on any interaction
    document.addEventListener("click", () => this.resumeAudio(), { once: true });
    document.addEventListener("keydown", () => this.resumeAudio(), { once: true });
  },

  resumeAudio() {
    if (this.audioContext && this.audioContext.state === "suspended") {
      this.audioContext.resume();
    }
  },

  playDingDong() {
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    }

    const ctx = this.audioContext;
    if (ctx.state === "suspended") ctx.resume();

    const now = ctx.currentTime;

    // First note (high)
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.type = "sine";
    osc1.frequency.setValueAtTime(660, now);
    gain1.gain.setValueAtTime(0.5, now);
    gain1.gain.exponentialRampToValueAtTime(0.01, now + 0.4);
    osc1.start(now);
    osc1.stop(now + 0.4);

    // Second note (low)
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.type = "sine";
    osc2.frequency.setValueAtTime(440, now + 0.3);
    gain2.gain.setValueAtTime(0.5, now + 0.3);
    gain2.gain.exponentialRampToValueAtTime(0.01, now + 0.8);
    osc2.start(now + 0.3);
    osc2.stop(now + 0.8);
  },

  speak(text) {
    if (!window.speechSynthesis) return;

    // Cancel any ongoing speech
    window.speechSynthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = "pt-BR";
    utterance.rate = 0.9;
    utterance.pitch = 1;
    utterance.volume = 1;

    window.speechSynthesis.speak(utterance);
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, PhoneMask, AutoClearFlash, TotemSounds, DeskPreference, RoomPreference, AutoFocus, TVSound },
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Sentinel AI - Copy to clipboard helper
window.addEventListener("phx:copy_to_clipboard", (e) => {
  const text = e.detail.text;
  navigator.clipboard.writeText(text).then(() => {
    console.log("[Sentinel] JSON copied to clipboard!");
  }).catch(err => {
    console.error("[Sentinel] Failed to copy:", err);
  });
});

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if (keyDown === "d") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

// ============================================
// PWA Service Worker Registration
// ============================================
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then((registration) => {
        console.log('[PWA] Service Worker registered:', registration.scope);

        // Check for updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              console.log('[PWA] New content available, refresh to update');
            }
          });
        });
      })
      .catch((error) => {
        console.log('[PWA] Service Worker registration failed:', error);
      });
  });
}

// ============================================
// Hardware Info Collection (for device tracking)
// ============================================
(function collectHardwareInfo() {
  try {
    const hardwareInfo = {
      cpuCores: navigator.hardwareConcurrency || null,
      memoryGb: navigator.deviceMemory || null,
      screenResolution: `${screen.width}x${screen.height}`,
      platform: navigator.platform || null,
      language: navigator.language || null,
      connectionType: navigator.connection?.effectiveType || null,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || null
    };

    // Encode as base64 JSON and store in cookie
    const jsonStr = JSON.stringify(hardwareInfo);
    const encoded = btoa(jsonStr);

    // Set cookie with 1 hour expiry
    document.cookie = `_st_hardware_info=${encoded}; path=/; max-age=3600; SameSite=Lax`;

    console.log('[Hardware] Info collected:', hardwareInfo);
  } catch (e) {
    console.log('[Hardware] Failed to collect info:', e);
  }
})();
