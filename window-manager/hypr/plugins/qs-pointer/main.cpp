// qs-pointer -- tells Quickshell where the pointer is, without Quickshell
// polling.
//
// Quickshell only sees the pointer while it is over one of its own surfaces.
// The cursor effects (trail, click ripple, ring visualizer) and the hover
// dropdowns over the bar need it everywhere, so this plugin posts it on
// Hyprland's event socket (socket2), where Quickshell already listens.
//
// NOTHING IS POSTED UNLESS ASKED FOR. Every stream below starts off, and
// Quickshell switches on only what something on screen currently needs:
//
//   hyprctl qspointer track 0|1          "qspos>>X,Y"         pointer moves
//   (layout coords),
//                                                            at most once per
//                                                            ~8 ms, plus the
//                                                            final resting
//                                                            position
//   hyprctl qspointer clicks 0|1         "qsclick>>1|0"       button press /
//   release hyprctl qspointer shapes 0|1         "qsshape>>NAME"      cursor
//   shape changed
//                                                            ("" while a client
//                                                            draws its own)
//   hyprctl qspointer zone NAME X Y W H  "qszone>>NAME,1|0"   pointer entered /
//   left a rectangle;
//                                                            only the edges are
//                                                            posted, so a zone
//                                                            costs nothing
//                                                            while you are
//                                                            elsewhere or still
//   hyprctl qspointer unzone NAME|*      drop one zone, or all of them
//   hyprctl qspointer pop 0|1            on a press, show the theme's
//   pop_<shape>
//                                        cursor (the Fluent accent theme's
//                                        swell- and-settle); only for themes
//                                        that have them, so Quickshell turns it
//                                        on only then
//   hyprctl qspointer invert 0|1         draw the themed cursor INVERTED: each
//                                        pixel becomes the opposite of what is
//                                        under it (white over black, black over
//                                        white), like Windows' inverted
//                                        pointer. Meant for a pure-white theme,
//                                        which Quickshell generates for it.
//                                        Cursors a client draws itself are left
//                                        as they are.
//   hyprctl qspointer trail MODE LIFE HEAD   while inverting, draw the
//                                        pointer trail here, inverted the same
//                                        way, so trail and pointer are always
//                                        one colour (MODE off|comet|dots|
//                                        sparks, LIFE in ms, HEAD in px).
//                                        Quickshell hides its own trail then.
//                                        The click effect and ring stay in
//                                        Quickshell's layer and are NOT
//                                        inverted (see PLUGIN_INIT).
//   hyprctl qspointer status             what is on, for debugging
//
// Built and loaded by ./load.sh at login, which rebuilds it whenever Hyprland
// itself has changed (the plugin ABI is per-build). If it is missing or stale,
// Hyprland simply has no `qspointer` command and the shell's effects stay off.

#define WLR_USE_UNSTABLE
#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/ipc/s1/S1.hpp>
#include <hyprland/src/ipc/s2/S2.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/pointer/PointerManager.hpp>
#include <hyprland/src/pointer/cursor/CursorManager.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/render/pass/PassElement.hpp>
#include <hyprland/src/render/pass/RectPassElement.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include <chrono>
#include <cmath>
#include <deque>
#include <map>
#include <random>
#include <sstream>

using Pointer::Cursor::CCursorManager;

static HANDLE handle;

static bool trackOn = false;
static bool clicksOn = false;
static bool shapesOn = false;
static bool popOn = false;
static bool invertOn = false;

struct SZone {
  double x, y, w, h;
  bool inside = false;
};
static std::map<std::string, SZone> zones;

// --- position, throttled -----------------------------------------------------
static constexpr int64_t MIN_GAP_MS = 8;
static int64_t lastPostMs = 0;
static Vector2D lastPos{-1, -1};
static Vector2D pendingPos;
static bool pending = false;
static wl_event_source *trailTimer;

static int64_t nowMs() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}

static void post(const std::string &name, const std::string &data) {
  IPC::Socket2::sock()->postEvent({name, data});
}

static void postPos(const Vector2D &p) {
  lastPostMs = nowMs();
  lastPos = p;
  std::ostringstream s;
  s << (int)std::round(p.x) << "," << (int)std::round(p.y);
  post("qspos", s.str());
}

static int trail(void *) {
  if (pending && trackOn)
    postPos(pendingPos);
  pending = false;
  return 0;
}

static void checkZones(const Vector2D &p) {
  for (auto &[name, z] : zones) {
    const bool in =
        p.x >= z.x && p.y >= z.y && p.x < z.x + z.w && p.y < z.y + z.h;
    if (in != z.inside) {
      z.inside = in;
      post("qszone", name + (in ? ",1" : ",0"));
    }
  }
}

static void trailMove(const Vector2D &p);

static void onMove() {
  trailMove(g_pInputManager->getMouseCoordsInternal());
  if (!trackOn && zones.empty())
    return;
  const Vector2D p = g_pInputManager->getMouseCoordsInternal();
  checkZones(p);
  if (!trackOn || p == lastPos)
    return;
  if (nowMs() - lastPostMs >= MIN_GAP_MS) {
    pending = false;
    postPos(p);
  } else {
    // Too soon: remember it and post when the gap is up, so the last
    // position before the pointer stops is never lost.
    pendingPos = p;
    if (!pending)
      wl_event_source_timer_update(trailTimer, MIN_GAP_MS);
    pending = true;
  }
}

// --- cursor shape ------------------------------------------------------------
using NameFn = void (*)(CCursorManager *, const std::string &);
using SurfaceFn = void (*)(CCursorManager *, SP<Desktop::View::CWLSurface>,
                           const Vector2D &);
static CFunctionHook *nameHook;
static CFunctionHook *surfaceHook;
static std::string lastShape = "-";
static CCursorManager *manager = nullptr;

static void postShape(const std::string &name) {
  if (name == lastShape)
    return;
  lastShape = name;
  if (shapesOn)
    post("qsshape", name);
}

static void onName(CCursorManager *self, const std::string &name) {
  manager = self;
  ((NameFn)nameHook->m_original)(self, name);
  postShape(name);
}

static void onSurface(CCursorManager *self, SP<Desktop::View::CWLSurface> surf,
                      const Vector2D &hotspot) {
  ((SurfaceFn)surfaceHook->m_original)(self, surf, hotspot);
  postShape("");
}

static CFunctionHook *hook(const std::string &name, void *fn,
                           const std::string &cls = "CCursorManager::") {
  for (auto &m : HyprlandAPI::findFunctionsByName(handle, name))
    if (m.demangled.contains(cls + name)) {
      auto h = HyprlandAPI::createFunctionHook(handle, m.address, fn);
      h->hook();
      return h;
    }
  return nullptr;
}

// --- inverted cursor ---------------------------------------------------------
// Hyprland draws the (software) cursor as one texture pass element, blended
// with GL_ONE, GL_ONE_MINUS_SRC_ALPHA (premultiplied "over"). Inverting is the
// same draw with GL_ONE_MINUS_DST_COLOR as the source factor:
//
//     out = src * (1 - dst) + dst * (1 - srcAlpha)
//
// which for a white pixel of coverage a is mix(dst, 1 - dst, a): fully covered
// pixels are the exact inverse of the screen, anti-aliased edges fade into it.
//
// The renderer re-sets the blend function before every draw, but through a
// cache that skips the GL call when the cached value already matches. So two
// pass elements go round the cursor's: the first makes the cache say "over"
// (blend(true)) and then sets the real GL state to "invert" behind its back;
// the cursor draw asks for "over", the cache says it is already there, and the
// inverted state is what it draws with. The second puts the real state back
// and resyncs the cache, so nothing after the cursor is affected.
using Render::GL::CHyprOpenGLImpl;

class CInvertPass : public IPassElement {
public:
  explicit CInvertPass(bool begin) : m_begin(begin) {}

  std::vector<UP<IPassElement>> draw(Render::CRenderContext &) override {
    auto gl = g_pHyprRenderer->glBackend();
    if (!gl)
      return {};
    static bool wasBlend = true;
    if (m_begin) {
      wasBlend = gl->blendEnabled();
      gl->blend(true); // cache and GL both: ONE, ONE_MINUS_SRC_ALPHA
      // Colour inverts; alpha composites as usual, so the framebuffer's
      // alpha channel stays what the rest of the renderer expects.
      glBlendFuncSeparate(GL_ONE_MINUS_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA,
                          GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    } else {
      // Force both the cache and GL (colour and alpha: glBlendFunc sets
      // both) back to "over", whatever happened in between, then
      // restore whether blending was on at all.
      gl->blendFunc(GL_ZERO, GL_ZERO);
      gl->blendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
      gl->blend(wasBlend);
    }
    return {};
  }
  bool needsLiveBlur(Render::CRenderContext &) override { return false; }
  bool needsPrecomputeBlur(Render::CRenderContext &) override { return false; }
  // Never dropped by the occlusion pass: the "end" one must always run once
  // the "begin" one has.
  bool undiscardable(Render::CRenderContext &) override { return true; }
  const char *passName() override {
    return m_begin ? "CQsInvertBegin" : "CQsInvertEnd";
  }
  ePassElementType type() override { return EK_CUSTOM; }

private:
  bool m_begin;
};

using SwCursorFn = void (*)(Pointer::CPointerManager *,
                            Render::CRenderContext &, PHLMONITOR,
                            const Time::steady_tp &, CRegion &,
                            std::optional<Vector2D>, bool, bool);
static CFunctionHook *swHook;
static bool softwareLocked = false;
static void addTrail(Render::CRenderContext &ctx, PHLMONITOR mon);
static bool trailActive();

static void onSwCursors(Pointer::CPointerManager *self,
                        Render::CRenderContext &ctx, PHLMONITOR mon,
                        const Time::steady_tp &now, CRegion &damage,
                        std::optional<Vector2D> pos, bool screencopy,
                        bool force) {
  // Only the theme's own cursors ("" = a client is drawing its own).
  const bool inv =
      invertOn && !lastShape.empty() && g_pHyprRenderer->glBackend();
  // The trail first, so the pointer is drawn on top of it.
  if (trailActive() && mon && g_pHyprRenderer->glBackend())
    addTrail(ctx, mon);
  if (inv)
    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CInvertPass>(true));
  ((SwCursorFn)swHook->m_original)(self, ctx, std::move(mon), now, damage, pos,
                                   screencopy, force);
  if (inv)
    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CInvertPass>(false));
}

// The effects layer: the same two pass elements round its surfaces.
static constexpr const char *FX_LAYER = "qs-cursorfx";
using LayerFn = void (*)(Render::IHyprRenderer *, Render::CRenderContext &,
                         PHLLS, PHLMONITOR, const Time::steady_tp &, bool, bool,
                         bool);
static CFunctionHook *layerHook;

static void onLayer(Render::IHyprRenderer *self, Render::CRenderContext &ctx,
                    PHLLS ls, PHLMONITOR mon, const Time::steady_tp &now,
                    bool popups, bool lockscreen, bool workspaceScene) {
  const bool inv =
      invertOn && ls && ls->m_namespace == FX_LAYER && self->glBackend();
  if (inv)
    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CInvertPass>(true));
  ((LayerFn)layerHook->m_original)(self, ctx, std::move(ls), std::move(mon),
                                   now, popups, lockscreen, workspaceScene);
  if (inv)
    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CInvertPass>(false));
}


// --- inverted trail ----------------------------------------------------------
// While the cursor is inverted the trail is drawn HERE, not by Quickshell: a
// Qt layer can only paint colours, never "the opposite of what is under me",
// and wrapping that layer in the invert blend meant hooking renderLayer, which
// crashed the session. This draws through the cursor hook above, which already
// runs safely every frame.
//
// The whole trail is one region of pixel spans, drawn once with the invert
// blend: overlapping dots of an inverting trail would otherwise invert each
// other back. The cursor's own pixels are cut out of it for the same reason,
// so where trail and pointer meet the screen is inverted exactly once and both
// read as the same colour.
//
//   hyprctl qspointer trail off|comet|dots|sparks LIFE_MS HEAD_PX
//
// Quickshell sends its trail settings; this draws only while inverting, and
// Quickshell hides its own trail then.
struct STrailPt {
  double x, y, t;
};
struct SSpark {
  double x, y, vx, vy, t0, life, size;
};
static std::string trailMode = "off";
static double trailLife = 130, trailHead = 6;
static std::deque<STrailPt> trailPts;
static std::vector<SSpark> sparks;
static double sparkCarry = 0, lastSparkT = 0;
static wl_event_source *fadeTimer;
static CBox lastTrailBox;
static std::mt19937 rng{12345};
static constexpr size_t TRAIL_MAX = 40;

static double nowMsD() {
  return std::chrono::duration<double, std::milli>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}
static bool trailActive() { return invertOn && trailMode != "off"; }
static double spacing() {
  return trailMode == "dots" ? std::max(10.0, trailHead * 1.6)
                             : std::max(2.0, trailHead * 0.3);
}
static double sparkLifeBase() { return 160 + (trailLife - 90) / 260 * 500; }

static void prune(double t) {
  while (!trailPts.empty() && t - trailPts.front().t >= trailLife)
    trailPts.pop_front();
  std::erase_if(sparks, [t](const SSpark &s) { return t - s.t0 >= s.life; });
}

// Global layout box round everything currently drawn, padded.
static CBox trailBounds(double t) {
  double x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  auto grow = [&](double x, double y, double r) {
    x0 = std::min(x0, x - r);
    y0 = std::min(y0, y - r);
    x1 = std::max(x1, x + r);
    y1 = std::max(y1, y + r);
  };
  for (auto &p : trailPts)
    grow(p.x, p.y, trailHead);
  for (auto &s : sparks) {
    const double a = (t - s.t0) / 1000;
    grow(s.x + s.vx * a, s.y + s.vy * a + 30 * a * a, s.size);
  }
  if (x1 < x0)
    return {};
  return CBox{x0 - 3, y0 - 3, x1 - x0 + 6, y1 - y0 + 6};
}

static void damageTrail() {
  const double t = nowMsD();
  prune(t);
  const CBox cur = trailBounds(t);
  if (!lastTrailBox.empty())
    g_pHyprRenderer->damageBox(lastTrailBox);
  if (!cur.empty())
    g_pHyprRenderer->damageBox(cur);
  lastTrailBox = cur;
  if (!cur.empty())
    wl_event_source_timer_update(fadeTimer, 8);
}

static int onFade(void *) {
  damageTrail();
  return 0;
}

static void clearTrail() {
  trailPts.clear();
  sparks.clear();
  if (fadeTimer)
    damageTrail();
}

static void trailMove(const Vector2D &p) {
  if (!trailActive())
    return;
  const double t = nowMsD();
  prune(t);
  if (trailMode == "sparks") {
    // ~140 a second while moving, like Quickshell's emitter.
    sparkCarry += std::min(60.0, t - lastSparkT) * 0.14;
    lastSparkT = t;
    std::uniform_real_distribution<double> u(-1, 1);
    while (sparkCarry >= 1 && sparks.size() < 200) {
      sparkCarry -= 1;
      const double ang = (u(rng) + 1) * M_PI, mag = 40 + 30 * u(rng);
      sparks.push_back({p.x, p.y, std::cos(ang) * mag, std::sin(ang) * mag, t,
                        std::max(60.0, sparkLifeBase() + 120 * u(rng)),
                        std::max(2.0, 7 + 4 * u(rng))});
    }
  } else {
    if (!trailPts.empty()) {
      const auto last = trailPts.back();
      const double dx = p.x - last.x, dy = p.y - last.y;
      const double dist = std::sqrt(dx * dx + dy * dy);
      if (dist < spacing())
        return;
      // Fill the gaps of a fast flick so the comet stays one ribbon.
      const int steps = std::min(12, (int)std::floor(dist / spacing()));
      for (int i = 1; i < steps; i++)
        trailPts.push_back({last.x + dx * i / steps, last.y + dy * i / steps,
                            last.t + (t - last.t) * i / steps});
    }
    trailPts.push_back({p.x, p.y, t});
    while (trailPts.size() > TRAIL_MAX)
      trailPts.pop_front();
  }
  damageTrail();
}

// The cursor image's covered pixels, in its own pixel grid, cached per image.
static void *maskFor = nullptr;
static CRegion maskImg;
static Vector2D maskSize;

static bool cursorMask(CRegion &out, PHLMONITOR mon) {
  const auto &img = Pointer::mgr()->currentCursorImage();
  const auto buf = img.pBuffer;
  if (!buf)
    return false;
  if (buf.get() != maskFor) {
    maskFor = buf.get();
    maskImg.clear();
    maskSize = {};
    if (buf->caps() & Aquamarine::BUFFER_CAPABILITY_DATAPTR) {
      const int w = (int)img.size.x, h = (int)img.size.y;
      auto [data, fmt, len] = buf->beginDataPtr(0);
      // The third value is the row stride (some buffers report the whole
      // size instead; accept either).
      const size_t stride =
          h > 0 && len >= (size_t)w * 4 * h ? len / h : len;
      if (data && w > 0 && h > 0 && stride >= (size_t)w * 4) {
        for (int y = 0; y < h; y++) {
          const uint8_t *row = data + y * stride;
          // Only pixels the pointer visibly covers: themes often fill their
          // middle with near-zero alpha (hit area), and cutting that out
          // would leave a hole at the trail's head.
          constexpr uint8_t MIN_A = 48;
          for (int x = 0; x < w;) {
            if (row[x * 4 + 3] < MIN_A) {
              x++;
              continue;
            }
            int e = x;
            while (e < w && row[e * 4 + 3] >= MIN_A)
              e++;
            maskImg.add(x, y, e - x, 1);
            x = e;
          }
        }
        maskSize = {(double)w, (double)h};
      }
      buf->endDataPtr();
    }
  }
  if (maskSize.x <= 0)
    return false;
  // Into the same monitor-local logical grid as the trail.
  const CBox cb = Pointer::mgr()->getCursorBoxGlobal();
  out = maskImg.copy();
  out.scale(Vector2D{cb.w / maskSize.x, cb.h / maskSize.y});
  out.translate(Vector2D{cb.x - mon->m_position.x, cb.y - mon->m_position.y});
  return true;
}

// The trail on this monitor as one region, on the monitor's LOGICAL pixel grid
// (monitor-local). Hyprland clips every rect element to its box rounded to
// whole logical pixels, so anything finer is cut into stripes.
static CRegion trailShape(PHLMONITOR mon) {
  CRegion shape;
  const double t = nowMsD();
  const Vector2D o = mon->m_position;
  auto disc = [&](double cx, double cy, double d) {
    const double r = d / 2;
    if (r < 0.5)
      return;
    const double px = cx - o.x, py = cy - o.y;
    for (int y = (int)std::floor(py - r); y < (int)std::ceil(py + r); y++) {
      const double yc = y + 0.5 - py, h2 = r * r - yc * yc;
      if (h2 <= 0)
        continue;
      const double hw = std::sqrt(h2);
      const int x0 = (int)std::lround(px - hw), x1 = (int)std::lround(px + hw);
      if (x1 > x0)
        shape.add(x0, y, x1 - x0, 1);
    }
  };
  for (auto &p : trailPts) {
    // 1 at the head, falling to 0 at the end of its life.
    const double k = std::max(0.0, 1 - (t - p.t) / trailLife);
    if (k <= 0)
      continue;
    // The trail fades by thinning: every pixel of it is fully inverted, the
    // same as the pointer, so the two always read as one colour.
    const double d = trailMode == "dots" ? trailHead * 0.55 * (0.4 + 0.6 * k)
                                         : trailHead * std::sqrt(k);
    disc(p.x, p.y, d);
  }
  for (auto &sp : sparks) {
    const double a = (t - sp.t0) / 1000, k = 1 - (t - sp.t0) / sp.life;
    if (k <= 0)
      continue;
    disc(sp.x + sp.vx * a, sp.y + sp.vy * a + 30 * a * a,
         (1 + (sp.size - 1) * k) * 0.6);
  }
  shape.intersect(0, 0, mon->m_size.x, mon->m_size.y);
  return shape;
}

static void addTrail(Render::CRenderContext &ctx, PHLMONITOR mon) {
  if (trailPts.empty() && sparks.empty())
    return;
  CRegion shape = trailShape(mon);
  CRegion mask;
  if (!lastShape.empty() && cursorMask(mask, mon))
    shape.subtract(mask);
  if (shape.empty())
    return;
  // One rect per span: the region never overlaps itself, so every pixel is
  // inverted exactly once. Alpha just under 1 keeps the renderer blending (an
  // opaque rect may switch blending off), and blending is what inverts.
  Render::IHyprRenderer::addPassElement(ctx, makeUnique<CInvertPass>(true));
  for (auto &b : shape.getRects()) {
    CRectPassElement::SRectData d;
    // The element takes output pixels.
    d.box = CBox{(double)b.x1, (double)b.y1, (double)(b.x2 - b.x1),
                 (double)(b.y2 - b.y1)}
                .scale(mon->m_scale);
    d.color = CHyprColor(1.F, 1.F, 1.F, 0.999F);
    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CRectPassElement>(d));
  }
  Render::IHyprRenderer::addPassElement(ctx, makeUnique<CInvertPass>(false));
}

// A hardware cursor plane cannot blend with the screen, so while inverting
// the cursor is always drawn by the renderer.
static void setInvert(bool on) {
  invertOn = on && swHook;
  if (!invertOn)
    clearTrail();
  if (invertOn != softwareLocked) {
    if (invertOn)
      Pointer::mgr()->lockSoftwareAll();
    else
      Pointer::mgr()->unlockSoftwareAll();
    softwareLocked = invertOn;
  }
  for (auto &m : State::monitorState()->monitors()) {
    Pointer::mgr()->damageCursor(m);
    g_pHyprRenderer->damageMonitor(
        m); // the effects layer, wherever it is drawn
  }
}

// --- hyprctl qspointer ... ---------------------------------------------------
static std::string command(const std::string &line) {
  std::istringstream in(line);
  std::string word, verb;
  in >> word >> verb; // "qspointer", then the verb
  auto flag = [&](bool &f) {
    std::string v;
    in >> v;
    f = v == "1" || v == "on" || v == "true";
    return std::string{"ok"};
  };
  if (verb == "track") {
    flag(trackOn);
    lastPos = {-1, -1};
    if (trackOn)
      onMove(); // hand over the current position straight away
    return "ok";
  }
  if (verb == "clicks")
    return flag(clicksOn);
  if (verb == "pop")
    return flag(popOn);
  if (verb == "invert") {
    bool on = false;
    flag(on);
    setInvert(on);
    return invertOn || !on ? "ok" : "invert unavailable (render hook missing)";
  }
  if (verb == "trail") {
    std::string mode;
    double life = 0, head = 0;
    if (!(in >> mode))
      return "usage: qspointer trail off|comet|dots|sparks LIFE_MS HEAD_PX";
    in >> life >> head;
    if (mode != "comet" && mode != "dots" && mode != "sparks")
      mode = "off";
    if (mode != trailMode)
      clearTrail();
    trailMode = mode;
    if (life > 0)
      trailLife = std::clamp(life, 30.0, 2000.0);
    if (head > 0)
      trailHead = std::clamp(head, 1.0, 64.0);
    return "ok";
  }
  if (verb == "shapes") {
    flag(shapesOn);
    if (shapesOn && lastShape != "-")
      post("qsshape", lastShape);
    return "ok";
  }
  if (verb == "zone") {
    std::string name;
    SZone z;
    if (!(in >> name >> z.x >> z.y >> z.w >> z.h))
      return "usage: qspointer zone NAME X Y W H";
    auto it = zones.find(name);
    if (it != zones.end())
      z.inside = it->second.inside;
    zones[name] = z;
    checkZones(g_pInputManager->getMouseCoordsInternal());
    return "ok";
  }
  if (verb == "unzone") {
    std::string name;
    in >> name;
    if (name == "*" || name.empty())
      zones.clear();
    else
      zones.erase(name);
    return "ok";
  }
  if (verb == "status") {
    std::ostringstream s;
    s << "track " << trackOn << "\nclicks " << clicksOn << "\nshapes "
      << shapesOn << "\npop " << popOn << "\ninvert " << invertOn << "\ntrail " << trailMode << " "
      << trailLife << " " << trailHead << " points " << trailPts.size()
      << " sparks " << sparks.size()
      << "\nshape-hooks " << (nameHook && surfaceHook) << "\ninvert-hook "
      << (swHook != nullptr) << "\ninvert-fx-hook " << (layerHook != nullptr)
      << "\nzones";
    for (auto &[name, z] : zones)
      s << " " << name << (z.inside ? "*" : "");
    return s.str() + "\n";
  }
  return "qspointer: track|clicks|shapes|pop|invert 0|1, zone NAME X Y W H, "
         "unzone NAME|*, trail MODE LIFE HEAD, status";
}

static CHyprSignalListener moveListener;
static CHyprSignalListener clickListener;
static SP<IPC::Socket1::SCommand> ctl;

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE h) {
  handle = h;
  if (std::string{__hyprland_api_get_hash()} !=
      std::string{__hyprland_api_get_client_hash()})
    throw std::runtime_error(
        "qs-pointer: built for another Hyprland, rebuild it (load.sh does)");

  trailTimer =
      wl_event_loop_add_timer(g_pCompositor->m_wlEventLoop, trail, nullptr);
  fadeTimer =
      wl_event_loop_add_timer(g_pCompositor->m_wlEventLoop, onFade, nullptr);

  moveListener = Event::bus()->m_events.input.mouse.move.listen(
      [](Vector2D, Event::SCallbackInfo &) { onMove(); });
  clickListener = Event::bus()->m_events.input.mouse.button.listen(
      [](IPointer::SButtonEvent e, Event::SCallbackInfo &) {
        const bool down = e.state == WL_POINTER_BUTTON_STATE_PRESSED;
        if (clicksOn)
          post("qsclick", down ? "1" : "0");
        // Straight to the original: the bounce is not a shape change of its
        // own, so lastShape keeps naming the real shape underneath.
        if (down && popOn && manager && nameHook && !lastShape.empty() &&
            lastShape != "-")
          ((NameFn)nameHook->m_original)(manager, "pop_" + lastShape);
      });

  // Shape hooks are a nicety: if a future Hyprland renames these, the
  // plugin still loads and everything but `qsshape` keeps working.
  nameHook = hook("setCursorFromName", (void *)&onName);
  surfaceHook = hook("setCursorSurface", (void *)&onSurface);
  swHook = hook("renderSoftwareCursorsFor", (void *)&onSwCursors,
                "CPointerManager::");
  // NOT HOOKED: inverting the qs-cursorfx layer through renderLayer crashed
  // the live session (2026-11-28) -- random SEGVs in frame/animation/monitor
  // code right after login, i.e. memory corruption. renderLayer can run while
  // a render pass is being drawn, so adding pass elements there is unsafe.
  // The nested selftest never caught it: it has no qs-cursorfx layer.
  // Do not re-enable without a selftest that renders that layer.
  (void)&onLayer;
  layerHook = nullptr;

  ctl = HyprlandAPI::registerHyprCtlCommand(
      handle, {"qspointer", IPC::Socket1::COMMAND_MATCH_PREFIX,
               [](const IPC::Socket1::SRequest &req) {
                 return IPC::Socket1::SResponse{command(req.command)};
               }});
  // Tell Quickshell a fresh copy is up (its state -- zones, streams -- starts
  // empty), so it hands everything over again without waiting to poll.
  post("qspointer", "loaded");
  return {"qs-pointer",
          "Pointer position, clicks, shape and hover zones for Quickshell",
          "kairav", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
  setInvert(false);
  moveListener.reset();
  clickListener.reset();
  wl_event_source_remove(trailTimer);
  wl_event_source_remove(fadeTimer);
  fadeTimer = nullptr;
}
