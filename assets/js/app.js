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
      let x = e.target.value.replace(/\D/g, "")
        .match(/(\d{0,2})(\d{0,5})(\d{0,4})/);

      e.target.value = !x[2]
        ? x[1]
        : "(" + x[1] + ") " + x[2] + (x[3] ? "-" + x[3] : "");
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

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, PhoneMask, AutoClearFlash, TotemSounds },
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

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

