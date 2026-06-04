import AppKit
import SwiftUI
import UserNotifications

// MARK: - App

@main
struct HermesControlApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @StateObject private var ctrl = GatewayController()

  var body: some Scene {
    MenuBarExtra {
      ContentView()
        .environmentObject(ctrl)
    } label: {
      MenuBarIcon(
        isProcessing: ctrl.isProcessing,
        isRunning: ctrl.isRunning,
        modelReady: ctrl.currentModel.availability == .available,
        blinkOn: ctrl.blinkOn
      )
    }
    .menuBarExtraStyle(.window)
  }
}

/// Menu bar label: an antenna icon with a small status badge in the top-trailing corner.
/// ON = green dot, OFF = hollow grey dot, processing = a spinning braille glyph (orange).
///
/// MenuBarExtra flattens its label to a template (monochrome) image, which strips colors.
/// To keep the badge colored we rasterize the composed view and display it with
/// `.renderingMode(.original)`, which tells the menu bar not to re-tint it.
struct MenuBarIcon: View {
  let isProcessing: Bool
  let isRunning: Bool
  let modelReady: Bool
  let blinkOn: Bool

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    if let image = rendered() {
      Image(nsImage: image).renderingMode(.original)
    } else {
      Text("H").font(.system(size: 11, weight: .bold))
    }
  }

  @MainActor private func rendered() -> NSImage? {
    // The "H" takes the menu bar's label color; the badge keeps its own color.
    let glyphColor: Color = (colorScheme == .dark) ? .white : .black
    // Dot sits above the bold "H" with a small gap; the menu bar scales the whole
    // image to fit the bar height, so the gap is preserved.
    let content = VStack(spacing: -2) {
      badge.frame(height: 9)
      Text("H")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(glyphColor)
    }
    .frame(width: 26, alignment: .center)

    let renderer = ImageRenderer(content: content)
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
    guard let image = renderer.nsImage else { return nil }
    image.isTemplate = false
    return image
  }

  @ViewBuilder private var badge: some View {
    let color: Color = isProcessing
      ? (blinkOn ? .orange : .clear)
      : isRunning ? (modelReady ? .green : .yellow) : .gray
    Circle()
      .fill(color)
      .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
      .frame(width: 9, height: 9)
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  func applicationWillFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = self
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    NotificationManager.setup()
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(400))
      MoveToApplications.promptIfNeeded()
    }
  }
  // Show the banner even while the app is frontmost.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    handler([.banner, .sound])
  }
  // Open the Thinking window when a notification is clicked.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler handler: @escaping () -> Void
  ) {
    Task { @MainActor in
      guard let ctrl = GatewayController.shared else { return }
      let entry = ctrl.currentRequest ?? ctrl.recentActivity.first
      if let entry { ctrl.showThinking(for: entry) }
    }
    handler()
  }
}

enum NotificationManager {
  static func setup() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        switch settings.authorizationStatus {
        case .notDetermined:
          // An LSUIElement app gets no permission dialog without a foreground presence,
          // so briefly become a regular (Dock) app while requesting.
          NSApp.setActivationPolicy(.regular)
          NSApp.activate(ignoringOtherApps: true)
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            _, _ in
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
          }
        case .denied:
          // Already denied — surface it in the UI so the user can re-enable in System Settings.
          NotificationManager.notificationDenied = true
        default:
          break
        }
      }
    }
  }

  static func send(_ title: String, _ subtitle: String, _ body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.subtitle = subtitle
    content.body = body
    content.sound = .default
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    )
  }

  static func openSystemSettings() {
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
  }

  @MainActor static var notificationDenied = false

  @MainActor
  static func requestOrTest(ctrl: GatewayController) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        switch settings.authorizationStatus {
        case .authorized, .provisional:
          ctrl.notify("Hermes Control", "Test", "Notifications are working")
        case .denied:
          openSystemSettings()
        default:  // notDetermined
          NSApp.setActivationPolicy(.regular)
          NSApp.activate(ignoringOtherApps: true)
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            granted, _ in
            DispatchQueue.main.async {
              NSApp.setActivationPolicy(.accessory)
              if granted {
                ctrl.notify(
                  "Hermes Control", "Notifications enabled",
                  "You'll be alerted when a request comes in")
              } else {
                notificationDenied = true
              }
            }
          }
        }
      }
    }
  }
}

// MARK: - Move to Applications

enum MoveToApplications {
  @MainActor
  static func promptIfNeeded() {
    let path = Bundle.main.bundlePath
    if path.hasPrefix("/Applications/") { return }
    if UserDefaults.standard.bool(forKey: "skipMoveToApplications") { return }
    let dest = "/Applications/\(URL(fileURLWithPath: path).lastPathComponent)"

    let alert = NSAlert()
    alert.messageText = "Move to Applications folder?"
    alert.informativeText =
      "Moving HermesControl to /Applications makes launch-at-login work reliably and keeps it in a stable location."
    alert.addButton(withTitle: "Install & Relaunch")
    alert.addButton(withTitle: "Later")
    alert.showsSuppressionButton = true
    alert.suppressionButton?.title = "Don't ask again"
    NSApp.activate(ignoringOtherApps: true)
    let resp = alert.runModal()
    if alert.suppressionButton?.state == .on {
      UserDefaults.standard.set(true, forKey: "skipMoveToApplications")
    }
    guard resp == .alertFirstButtonReturn else { return }
    install(from: path, to: dest)
  }

  @MainActor
  private static func install(from src: String, to dest: String) {
    let fm = FileManager.default
    do {
      if fm.fileExists(atPath: dest) { try fm.removeItem(atPath: dest) }
      try fm.copyItem(atPath: src, toPath: dest)
    } catch {
      // Escape single quotes for the POSIX shell inside AppleScript's `do shell script`.
      func shq(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
      let script =
        "do shell script \"rm -rf \(shq(dest)) && cp -R \(shq(src)) /Applications/\" with administrator privileges"
      _ = sh("/usr/bin/osascript", ["-e", script])
      guard fm.fileExists(atPath: dest) else { return }
    }
    // Relaunch the installed copy once this instance exits.
    let pid = ProcessInfo.processInfo.processIdentifier
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = [
      "-c", "while /bin/kill -0 $0 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$1\"",
      "\(pid)", dest,
    ]
    try? p.run()
    NSApp.terminate(nil)
  }
}

// MARK: - Models

struct ActivityEntry: Identifiable {
  let id = UUID()
  let platform: String
  let user: String
  let message: String
  let model: String
  let startedAt: Date
  var responseTime: String?
  var dbSessionId: String?  // resolved after DB lookup
  var inputTokens: Int?
  var outputTokens: Int?
  var reasoningTokens: Int?
  var costUsd: Double?
}

enum ModelAvailability: Equatable {
  case available   // local: loaded in MLX server / cloud: gateway connected
  case unavailable // local: server down or model not loaded / cloud: gateway off
  case unknown     // not yet checked
}

struct ModelOption: Identifiable, Equatable {
  let id: String
  let modelId: String
  let provider: String
  let baseUrl: String
  var availability: ModelAvailability = .unknown

  var isLocal: Bool { provider == "custom" }

  /// Reject values that could break out of the config write or inject shell/script content.
  var isValid: Bool {
    let idOK = modelId.range(of: #"^[A-Za-z0-9._/\-]+$"#, options: .regularExpression) != nil
    let provOK = provider.range(of: #"^[A-Za-z0-9._\-]*$"#, options: .regularExpression) != nil
    let urlOK =
      baseUrl.isEmpty
      || baseUrl.range(of: #"^[A-Za-z0-9._:/\-]+$"#, options: .regularExpression) != nil
    return idOK && provOK && urlOK
  }
}

// MARK: - Thinking window content (shared singleton)

struct ConversationMessage: Identifiable {
  let id = UUID()
  let role: String  // "user" | "assistant"
  let text: String
}

@MainActor
final class ThinkingContent: ObservableObject {
  static let shared = ThinkingContent()
  @Published var title = ""
  @Published var blocks: [String] = []
  @Published var conversation: [ConversationMessage] = []
  @Published var isLive = false
  @Published var inputTokens: Int?
  @Published var outputTokens: Int?
  @Published var reasoningTokens: Int?
  @Published var costUsd: Double?
  private init() {}
}

// MARK: - Thinking window controller

@MainActor
final class ThinkingWindowController {
  static let shared = ThinkingWindowController()
  private var window: NSWindow?
  private init() {}

  func show() {
    if window == nil {
      let hosting = NSHostingView(rootView: ThinkingView())
      let win = NSWindow(
        contentRect: NSRect(x: 200, y: 200, width: 660, height: 500),
        styleMask: [.titled, .closable, .resizable, .miniaturizable],
        backing: .buffered,
        defer: false
      )
      win.title = "Thinking Process"
      win.contentView = hosting
      win.setFrameAutosaveName("HermesThinking")
      win.isReleasedWhenClosed = false
      window = win
    }
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func updateTitle(_ t: String) { window?.title = t }
}

// MARK: - Shell helpers

@discardableResult
func sh(_ path: String, _ args: [String]) -> String {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: path)
  p.arguments = args
  let pipe = Pipe()
  p.standardOutput = pipe
  p.standardError = Pipe()
  do { try p.run() } catch { return "" }
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  p.waitUntilExit()
  return String(data: data, encoding: .utf8) ?? ""
}

func extract(_ pattern: String, from text: String) -> String? {
  guard let re = try? NSRegularExpression(pattern: pattern),
    let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
    m.numberOfRanges > 1,
    let r = Range(m.range(at: 1), in: text)
  else { return nil }
  return String(text[r])
}

/// Locate an executable by checking common install dirs and the PATH.
/// Returns nil if not found anywhere — callers surface an install hint.
func findExecutable(_ name: String, extraDirs: [String] = []) -> String? {
  let fm = FileManager.default
  var dirs = extraDirs.map { ($0 as NSString).expandingTildeInPath }
  dirs += ["~/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    .map { ($0 as NSString).expandingTildeInPath }
  if let path = ProcessInfo.processInfo.environment["PATH"] {
    dirs += path.split(separator: ":").map(String.init)
  }
  for dir in dirs {
    let candidate = (dir as NSString).appendingPathComponent(name)
    if fm.isExecutableFile(atPath: candidate) { return candidate }
  }
  return nil
}

// MARK: - Paths

/// Hermes home (`~/.hermes` by default, overridable via HERMES_HOME — matches the Hermes CLI).
private let kHermesHome: String = {
  if let env = ProcessInfo.processInfo.environment["HERMES_HOME"], !env.isEmpty {
    return (env as NSString).expandingTildeInPath
  }
  return ("~/.hermes" as NSString).expandingTildeInPath
}()

/// `hermes` CLI — discovered on PATH (commonly installed to ~/.local/bin via pipx/uv).
private let kHermes: String =
  findExecutable("hermes") ?? ("~/.local/bin/hermes" as NSString).expandingTildeInPath
/// Python from the Hermes virtualenv — has PyYAML available for config read/write.
private let kPython: String = (kHermesHome as NSString).appendingPathComponent(
  "hermes-agent/venv/bin/python3")
private let kSqlite3 = "/usr/bin/sqlite3"
private let kPlistBuddy = "/usr/libexec/PlistBuddy"
private let kPlistPath = ("~/Library/LaunchAgents/ai.hermes.gateway.plist" as NSString)
  .expandingTildeInPath
private let kGatewayLog = (kHermesHome as NSString).appendingPathComponent("logs/gateway.log")
private let kStateDb = (kHermesHome as NSString).appendingPathComponent("state.db")
private let kConfigYaml = (kHermesHome as NSString).appendingPathComponent("config.yaml")
private let kSpinner = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

/// True when the Hermes installation backing this app is present.
func hermesInstalled() -> Bool {
  FileManager.default.fileExists(atPath: kStateDb)
    || FileManager.default.fileExists(atPath: kConfigYaml)
}

// MARK: - Controller

@MainActor
final class GatewayController: ObservableObject {
  static weak var shared: GatewayController?
  @Published var isRunning = false
  @Published var busy = false
  @Published var isProcessing = false
  @Published var currentRequest: ActivityEntry? = nil
  @Published var recentActivity: [ActivityEntry] = []
  @Published var spinnerFrame = kSpinner[0]
  @Published var blinkOn = true
  @Published var elapsed = ""
  @Published var currentModel = ModelOption(id: "", modelId: "", provider: "", baseUrl: "")
  @Published var modelOptions: [ModelOption] = []

  private var spinnerIdx = 0
  private var logOffset: UInt64 = 0
  private var isPolling = false
  private var thinkPollIdx = 0
  private var fsStream: FSEventStreamRef?
  private var fsContext = FSEventStreamContext(
    version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)

  init() {
    if let fh = FileHandle(forReadingAtPath: kGatewayLog) {
      logOffset = fh.seekToEndOfFile()
      fh.closeFile()
    }
    refresh()
    loadModelOptions()
    Task { @MainActor [weak self] in
      while true {
        try? await Task.sleep(for: .seconds(5))
        self?.refresh()
        self?.loadModelOptions()
      }
    }
    Task { @MainActor [weak self] in
      while true {
        try? await Task.sleep(for: .seconds(1))
        self?.pollLog()
      }
    }
    // Spinner ticks fast only while a request is in flight; otherwise it idles at 1s.
    Task { @MainActor [weak self] in
      while true {
        let processing = self?.isProcessing ?? false
        try? await Task.sleep(for: processing ? .milliseconds(150) : .seconds(1))
        self?.tick()
      }
    }
    fsContext.info = Unmanaged.passUnretained(self).toOpaque()
    GatewayController.shared = self
    watchDbChanges()
  }

  // FSEvents: refresh thinking the moment the Hermes DB changes.
  private func watchDbChanges() {
    let dbDir = (kStateDb as NSString).deletingLastPathComponent
    let stream = FSEventStreamCreate(
      nil,
      { _, info, _, _, _, _ in
        guard let info else { return }
        let ctrl = Unmanaged<GatewayController>.fromOpaque(info).takeUnretainedValue()
        Task { @MainActor in ctrl.onDbChange() }
      },
      &fsContext,
      [dbDir] as CFArray,
      FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
      0.3,
      FSEventStreamCreateFlags(
        kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
    )
    if let stream {
      FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
      FSEventStreamStart(stream)
      fsStream = stream
    }
  }

  private func onDbChange() {
    guard let req = currentRequest, isProcessing else { return }
    updateLiveThinking(req)
  }

  // MARK: Gateway toggle

  /// Detect the running gateway off the main thread (pgrep spawns a subprocess),
  /// then apply the result on the main actor. Keeps the UI from stalling.
  func refresh() {
    Task.detached(priority: .utility) {
      let out = sh("/usr/bin/pgrep", ["-f", "hermes_cli.main gateway run"])
      let running = !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      await MainActor.run { self.isRunning = running }
    }
  }

  func toggle() {
    guard !busy else { return }
    let wasRunning = isRunning
    busy = true
    Task.detached(priority: .userInitiated) { [weak self] in
      if wasRunning {
        _ = sh(kHermes, ["gateway", "stop"])
      } else {
        _ = sh(kHermes, ["gateway", "start"])
        _ = sh(kPlistBuddy, ["-c", "Set :RunAtLoad false", kPlistPath])
      }
      await MainActor.run { [weak self] in
        self?.refresh()
        self?.busy = false
      }
    }
  }

  // MARK: Model management

  func loadModelOptions() {
    Task.detached(priority: .utility) { [weak self] in
      // 1. Read Hermes config models (home passed as argv to avoid interpolation).
      let script = #"""
        import yaml, json, os, sys
        home = sys.argv[1]
        def read_cfg(path):
            try:
                with open(path) as f: return yaml.safe_load(f) or {}
            except: return {}
        results = []
        main = read_cfg(os.path.join(home, 'config.yaml'))
        mm = main.get('model', {})
        if mm.get('default'):
            results.append({'id': mm.get('provider','') + ':' + mm['default'],
                'model': mm['default'], 'provider': mm.get('provider',''),
                'baseUrl': mm.get('base_url',''), 'current': True})
        profiles_dir = os.path.join(home, 'profiles')
        if os.path.exists(profiles_dir):
            for p in sorted(os.listdir(profiles_dir)):
                cfg = read_cfg(os.path.join(profiles_dir, p, 'config.yaml'))
                pm = cfg.get('model', {})
                if pm.get('default') and pm.get('provider'):
                    entry = {'id': pm['provider']+':'+pm['default'],
                        'model': pm['default'], 'provider': pm.get('provider',''),
                        'baseUrl': pm.get('base_url',''), 'current': False}
                    if not any(r['id'] == entry['id'] for r in results):
                        results.append(entry)
        print(json.dumps(results))
        """#
      let out = sh(kPython, ["-c", script, kHermesHome])
      guard let data = out.data(using: .utf8),
        let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
      else { return }
      let currentId = arr.first(where: { $0["current"] as? Bool == true })?["id"] as? String ?? ""
      let hermesOptions = arr.map { d in
        ModelOption(
          id: d["id"] as? String ?? "",
          modelId: d["model"] as? String ?? "",
          provider: d["provider"] as? String ?? "",
          baseUrl: d["baseUrl"] as? String ?? ""
        )
      }

      // 2. Merge in any models the running MLX server exposes.
      let mlxBase = hermesOptions.first(where: { $0.provider == "custom" })?.baseUrl
        ?? "http://127.0.0.1:8080/v1"
      let mlxState = Self.scanMlxServer(baseUrl: mlxBase)
      // MLX server may return short IDs; match on bare name after "/" for dedup.
      func bareName(_ id: String) -> String { String(id.split(separator: "/").last ?? Substring(id)) }
      let extra = mlxState.models.filter { m in
        !hermesOptions.contains(where: {
          $0.modelId == m.modelId || bareName($0.modelId) == bareName(m.modelId)
        })
      }
      // Availability: local = currently loaded in GPU (/health default_model); cloud = gateway up.
      let gatewayUp = !sh("/usr/bin/pgrep", ["-f", "hermes_cli.main gateway run"])
        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

      func availability(for opt: ModelOption) -> ModelAvailability {
        if opt.isLocal {
          guard let loaded = mlxState.loadedModelId else { return .unavailable }
          return (loaded == opt.modelId || bareName(loaded) == bareName(opt.modelId))
            ? .available : .unavailable
        } else {
          return gatewayUp ? .available : .unavailable
        }
      }

      // Subscription (non-custom) models first, local (custom) models below.
      let options = (hermesOptions + extra)
        .map { opt -> ModelOption in var m = opt; m.availability = availability(for: opt); return m }
        .sorted { ($0.isLocal ? 1 : 0) < ($1.isLocal ? 1 : 0) }

      let currentOpt =
        options.first(where: { $0.id == currentId }) ?? options.first
        ?? ModelOption(id: "", modelId: "", provider: "", baseUrl: "")
      await MainActor.run { [weak self] in
        self?.modelOptions = options
        self?.currentModel = currentOpt
      }
    }
  }

  struct MlxServerState {
    let models: [ModelOption]   // all known models from /v1/models
    let loadedModelId: String?  // currently loaded model, from the server's --model process arg
  }

  /// Query the running MLX server.
  /// /v1/models gives the catalog; /health gives the model currently in GPU memory.
  nonisolated static func scanMlxServer(baseUrl: String) -> MlxServerState {
    // Discover all known models
    let modelsOut = sh("/usr/bin/curl", ["-sf", "-m", "2", "\(baseUrl)/models"])
    var models: [ModelOption] = []
    if let data = modelsOut.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let items = json["data"] as? [[String: Any]]
    {
      models = items.compactMap { item -> ModelOption? in
        guard let modelId = item["id"] as? String, !modelId.isEmpty else { return nil }
        return ModelOption(id: "custom:\(modelId)", modelId: modelId,
                           provider: "custom", baseUrl: baseUrl)
      }
    }

    // Find which model is actually loaded in GPU memory by reading --model from the
    // running mlx_lm.server (or mlx-lm) process args. This is read-only — it observes
    // the server without triggering inference or forcing a model to load.
    var loadedId: String? = nil
    let psOut = sh("/bin/ps", ["aux"])
    for line in psOut.components(separatedBy: "\n") {
      guard line.contains("mlx_lm") || line.contains("mlx-lm") else { continue }
      guard let r = line.range(of: "--model ") else { continue }
      let tail = String(line[r.upperBound...])
      let modelId = tail.components(separatedBy: " ").first ?? ""
      if !modelId.isEmpty { loadedId = modelId; break }
    }

    return MlxServerState(models: models, loadedModelId: loadedId)
  }

  func switchModel(_ option: ModelOption) {
    guard option != currentModel, !busy, option.isValid else { return }
    busy = true
    let wasRunning = isRunning
    // Values are passed as argv (sys.argv), never interpolated into the script source,
    // so model/provider/base_url cannot break out of the string or inject Python.
    let script = """
      import yaml, sys
      path, model, provider, base_url = sys.argv[1:5]
      with open(path) as f: data = yaml.safe_load(f)
      data.setdefault('model', {})
      data['model']['default'] = model
      data['model']['provider'] = provider
      data['model']['base_url'] = base_url
      with open(path, 'w') as f: yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
      """
    Task.detached(priority: .userInitiated) { [weak self] in
      _ = sh(kPython, ["-c", script, kConfigYaml, option.modelId, option.provider, option.baseUrl])
      if wasRunning {
        _ = sh(kHermes, ["gateway", "stop"])
        try? await Task.sleep(for: .seconds(1))
        _ = sh(kHermes, ["gateway", "start"])
        _ = sh(kPlistBuddy, ["-c", "Set :RunAtLoad false", kPlistPath])
      }
      await MainActor.run { [weak self] in
        self?.currentModel = option
        self?.refresh()
        self?.busy = false
      }
    }
  }

  // MARK: Log polling

  func tick() {
    guard isProcessing else { return }
    spinnerIdx = (spinnerIdx + 1) % kSpinner.count
    spinnerFrame = kSpinner[spinnerIdx]
    // Blink the menu bar dot: toggle every 4 ticks = ~600ms on / 600ms off
    if spinnerIdx % 4 == 0 { blinkOn.toggle() }
    if let req = currentRequest {
      let s = Int(Date().timeIntervalSince(req.startedAt))
      elapsed = s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }
    // Poll DB for thinking every ~1.5s (every 10 ticks at 150ms)
    thinkPollIdx = (thinkPollIdx + 1) % 10
    if thinkPollIdx == 0, let req = currentRequest {
      updateLiveThinking(req)
    }
  }

  /// Tail the gateway log off the main thread, then parse new lines on the main actor.
  /// `isPolling` guards against two in-flight reads covering the same byte range,
  /// which would duplicate notifications and recentActivity rows.
  func pollLog() {
    guard !isPolling else { return }
    isPolling = true
    let startOffset = logOffset
    Task.detached(priority: .utility) {
      let result: (UInt64, String)? = {
        guard let fh = FileHandle(forReadingAtPath: kGatewayLog) else { return nil }
        defer { fh.closeFile() }
        let fileSize = fh.seekToEndOfFile()
        var from = startOffset
        if fileSize < from { from = 0 }
        guard fileSize > from else { return nil }
        fh.seek(toFileOffset: from)
        guard let text = String(data: fh.readDataToEndOfFile(), encoding: .utf8) else { return nil }
        return (fileSize, text)
      }()
      await MainActor.run {
        if let (fileSize, text) = result {
          self.logOffset = fileSize
          text.components(separatedBy: "\n").forEach { self.parseLine($0) }
        }
        self.isPolling = false
      }
    }
  }

  private func logTimestamp(from line: String) -> Date {
    // "2026-06-04 00:12:18,696 INFO ..."
    let pattern = #"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"#
    guard let r = line.range(of: pattern, options: .regularExpression) else { return Date() }
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
    fmt.locale = Locale(identifier: "en_US_POSIX")
    return fmt.date(from: String(line[r])) ?? Date()
  }

  nonisolated func notify(_ title: String, _ subtitle: String, _ body: String) {
    DispatchQueue.main.async { NotificationManager.send(title, subtitle, body) }
  }

  private func parseLine(_ line: String) {
    if line.contains("inbound message:") {
      let platform = extract("platform=(\\w+)", from: line) ?? "unknown"
      let user = extract("user=(.+?) chat=", from: line) ?? ""
      let msg = extract("msg='(.*)'", from: line) ?? ""
      currentRequest = ActivityEntry(
        platform: platform, user: user, message: msg,
        model: currentModel.modelId, startedAt: logTimestamp(from: line))
      isProcessing = true
      elapsed = "0s"
      ThinkingContent.shared.blocks = []
      ThinkingContent.shared.isLive = true
      let pName = platformName(platform)
      let preview = msg.count > 60 ? String(msg.prefix(60)) + "…" : msg
      Task.detached { [weak self] in
        self?.notify("Hermes Control", "\(pName) · \(user)", preview)
      }
    } else if line.contains("response ready:") {
      let time = extract("time=([\\d.]+s)", from: line)
      if var req = currentRequest {
        req.responseTime = time
        let startTs = req.startedAt.timeIntervalSince1970
        // Resolve DB session and token usage asynchronously
        Task.detached(priority: .utility) {
          let tokenInfo = self.queryTokenUsageByTimestamp(startTs: startTs)
          await MainActor.run {
            var updated = req
            updated.dbSessionId = tokenInfo?.sessionId
            updated.inputTokens = tokenInfo?.usage.input
            updated.outputTokens = tokenInfo?.usage.output
            updated.reasoningTokens = tokenInfo?.usage.reasoning
            updated.costUsd = tokenInfo?.usage.cost
            self.recentActivity.insert(updated, at: 0)
            if self.recentActivity.count > 10 { self.recentActivity.removeLast() }
          }
        }
      }
      currentRequest = nil
      isProcessing = false
      elapsed = ""
      ThinkingContent.shared.isLive = false
    }
  }

  // MARK: Thinking DB queries

  // Hermes reuses the same session per channel — look up by message timestamp, not session start
  struct TokenUsage {
    let input: Int?
    let output: Int?
    let reasoning: Int?
    let cost: Double?
  }

  nonisolated func queryThinkingByTimestamp(startTs: Double) -> [String] {
    let endTs = startTs + 900
    let out = sh(
      kSqlite3,
      [
        "-json", kStateDb,
        "SELECT reasoning_content AS rc FROM messages WHERE timestamp > \(startTs - 5) AND timestamp < \(endTs) AND reasoning_content IS NOT NULL AND reasoning_content != '' ORDER BY id ASC;",
      ])
    guard let data = out.data(using: .utf8),
      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }
    return rows.compactMap { $0["rc"] as? String }.filter { !$0.isEmpty }
  }

  nonisolated func queryConversationByTimestamp(startTs: Double) -> [ConversationMessage] {
    let endTs = startTs + 900
    let out = sh(
      kSqlite3,
      [
        "-json", kStateDb,
        "SELECT role, content FROM messages WHERE timestamp > \(startTs - 5) AND timestamp < \(endTs) AND role IN ('user','assistant') AND content IS NOT NULL AND content != '' AND content NOT LIKE '[System note:%' ORDER BY id ASC;",
      ])
    guard let data = out.data(using: .utf8),
      let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else { return [] }
    return rows.compactMap { row -> ConversationMessage? in
      guard let role = row["role"] as? String,
        let text = row["content"] as? String, !text.isEmpty
      else { return nil }
      return ConversationMessage(role: role, text: text)
    }
  }

  nonisolated func queryTokenUsageByTimestamp(startTs: Double) -> (
    sessionId: String, usage: TokenUsage
  )? {
    let endTs = startTs + 900
    // Find session_id from messages in this time window
    let sidOut = sh(
      kSqlite3,
      [
        kStateDb,
        "SELECT DISTINCT session_id FROM messages WHERE timestamp > \(startTs - 5) AND timestamp < \(endTs) ORDER BY id ASC LIMIT 1;",
      ])
    let sid = sidOut.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !sid.isEmpty else { return nil }
    let out = sh(
      kSqlite3,
      [
        kStateDb,
        "SELECT input_tokens, output_tokens, reasoning_tokens, estimated_cost_usd FROM sessions WHERE id='\(sid)';",
      ])
    let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
    guard parts.count >= 4 else { return nil }
    let usage = TokenUsage(
      input: Int(parts[0]), output: Int(parts[1]),
      reasoning: Int(parts[2]), cost: Double(parts[3]))
    return (sid, usage)
  }

  private func updateLiveThinking(_ req: ActivityEntry) {
    let startTs = req.startedAt.timeIntervalSince1970
    Task.detached(priority: .utility) {
      let blocks = self.queryThinkingByTimestamp(startTs: startTs)
      let convo = self.queryConversationByTimestamp(startTs: startTs)
      await MainActor.run {
        ThinkingContent.shared.blocks = blocks
        ThinkingContent.shared.conversation = convo
      }
    }
  }

  func showThinking(for entry: ActivityEntry) {
    let isCurrentlyLive = currentRequest?.id == entry.id
    ThinkingContent.shared.isLive = isCurrentlyLive
    ThinkingContent.shared.title =
      "\(platformName(entry.platform)) · \(entry.user.isEmpty ? "Unknown" : entry.user)"
    ThinkingContent.shared.inputTokens = entry.inputTokens
    ThinkingContent.shared.outputTokens = entry.outputTokens
    ThinkingContent.shared.reasoningTokens = entry.reasoningTokens
    ThinkingContent.shared.costUsd = entry.costUsd
    let startTs = entry.startedAt.timeIntervalSince1970
    Task.detached(priority: .utility) {
      let blocks = self.queryThinkingByTimestamp(startTs: startTs)
      let convo = self.queryConversationByTimestamp(startTs: startTs)
      let tokenInfo = self.queryTokenUsageByTimestamp(startTs: startTs)
      await MainActor.run {
        ThinkingContent.shared.blocks = blocks
        ThinkingContent.shared.conversation = convo
        if let t = tokenInfo?.usage {
          ThinkingContent.shared.inputTokens = t.input
          ThinkingContent.shared.outputTokens = t.output
          ThinkingContent.shared.reasoningTokens = t.reasoning
          ThinkingContent.shared.costUsd = t.cost
        }
      }
    }
    ThinkingWindowController.shared.show()
    ThinkingWindowController.shared.updateTitle(
      "Thinking · \(platformName(entry.platform)) · \(entry.message.prefix(40))")
  }

  // MARK: Display helpers

  func platformName(_ p: String) -> String {
    switch p.lowercased() {
    case "telegram": return "Telegram"
    case "discord": return "Discord"
    case "slack": return "Slack"
    case "whatsapp": return "WhatsApp"
    case "signal": return "Signal"
    default: return p.capitalized
    }
  }

  func modelDisplayName(_ opt: ModelOption) -> String {
    let m = opt.modelId
    switch opt.provider {
    case "openai-codex": return m + " (Codex)"
    case "custom":
      if m.contains("Qwen") {
        let part = String(m.split(separator: "/").last ?? Substring(m))
        return part.replacingOccurrences(of: "-4bit", with: " (Local)")
      }
      return m + " (Local)"
    default: return m
    }
  }

  func modelDisplayNameFromId(_ modelId: String) -> String {
    if let opt = modelOptions.first(where: { $0.modelId == modelId }) {
      return modelDisplayName(opt)
    }
    if modelId.contains("Qwen") {
      let part = String(modelId.split(separator: "/").last ?? Substring(modelId))
      return part.replacingOccurrences(of: "-4bit", with: " (Local)")
    }
    return modelId
  }
}

// MARK: - Thinking View (standalone window)

struct ThinkingView: View {
  @ObservedObject private var content = ThinkingContent.shared
  @State private var selectedTab = 0

  var body: some View {
    VStack(spacing: 0) {
      headerBar
      Divider()
      Picker("", selection: $selectedTab) {
        Text("Thinking (\(content.blocks.count))").tag(0)
        Text("Conversation (\(content.conversation.count))").tag(1)
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      Divider()
      if selectedTab == 0 {
        thinkingTab
      } else {
        conversationTab
      }
    }
    .frame(minWidth: 560, minHeight: 360)
  }

  // MARK: Header

  var headerBar: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(content.isLive ? Color.orange : Color.secondary)
        .frame(width: 7, height: 7)
      Text(content.isLive ? "Live · \(content.title)" : content.title)
        .font(.system(size: 12, weight: .medium))
      Spacer()
      if let i = content.inputTokens, let o = content.outputTokens {
        Text(
          "↑\(i) ↓\(o)\(content.reasoningTokens.map { " 🧠\($0)" } ?? "")\(content.costUsd.map { String(format: "  $%.4f", $0) } ?? "")"
        )
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(Color(NSColor.windowBackgroundColor))
  }

  // MARK: Thinking tab

  var thinkingTab: some View {
    Group {
      if content.blocks.isEmpty {
        emptyState(content.isLive ? "Waiting for thinking…" : "No thinking recorded")
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
              ForEach(Array(content.blocks.enumerated()), id: \.offset) { idx, block in
                thinkingBlock(index: idx, text: block)
              }
              Color.clear.frame(height: 1).id("bottom")
            }
          }
          .onChange(of: content.blocks.count) {
            if content.isLive {
              withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
          }
        }
      }
    }
  }

  func thinkingBlock(index: Int, text: String) -> some View {
    Text(text)
      .font(.system(size: 12))
      .foregroundStyle(.primary)
      .textSelection(.enabled)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        index % 2 == 0
          ? Color(NSColor.windowBackgroundColor)
          : Color(NSColor.controlBackgroundColor))
  }

  // MARK: Conversation tab

  var conversationTab: some View {
    Group {
      if content.conversation.isEmpty {
        emptyState("No conversation recorded")
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
              ForEach(content.conversation) { msg in
                conversationBubble(msg)
              }
              Color.clear.frame(height: 1).id("bottom")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
          }
          .onChange(of: content.conversation.count) {
            if content.isLive {
              withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
          }
        }
      }
    }
  }

  func conversationBubble(_ msg: ConversationMessage) -> some View {
    let isUser = msg.role == "user"
    return HStack(alignment: .top, spacing: 0) {
      if isUser { Spacer(minLength: 60) }
      Text(msg.text)
        .font(.system(size: 12))
        .foregroundStyle(isUser ? Color.white : Color.primary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isUser ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      if !isUser { Spacer(minLength: 60) }
    }
  }

  // MARK: Empty state

  func emptyState(_ msg: String) -> some View {
    VStack {
      Spacer()
      Text(msg).foregroundStyle(.secondary).font(.system(size: 13))
      Spacer()
    }
  }
}

// MARK: - Model Row

/// A selectable model row with a hover highlight. Unselected rows stay full-color
/// (not greyed) so they read as clickable; the selected row gets an accent tint.
struct ModelRow: View {
  let title: String
  let isSelected: Bool
  let isBusy: Bool
  let availability: ModelAvailability
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
          .font(.system(size: 13))
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        Text(title)
          .font(.system(size: 12, weight: isSelected ? .medium : .regular))
          .foregroundStyle(.primary)
        Spacer()
        if isBusy && isSelected {
          ProgressView().controlSize(.mini)
        } else {
          availabilityBadge
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(rowBackground)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    // Don't disable the selected row — that dims its text. switchModel() already
    // ignores re-selecting the current model, so a click is a harmless no-op.
    .disabled(isBusy)
    .onHover { hovering = $0 }
  }

  @ViewBuilder private var availabilityBadge: some View {
    switch availability {
    case .available:
      Text("ready")
        .font(.system(size: 10))
        .foregroundStyle(.green)
    case .unavailable:
      Text("offline")
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    case .unknown:
      EmptyView()
    }
  }

  private var rowBackground: some View {
    RoundedRectangle(cornerRadius: 6)
      .fill(
        isSelected
          ? Color.accentColor.opacity(0.12)
          : (hovering && !isBusy ? Color.primary.opacity(0.06) : Color.clear)
      )
      .padding(.horizontal, 8)
  }
}

// MARK: - Main Content View

struct ContentView: View {
  @EnvironmentObject var ctrl: GatewayController

  var body: some View {
    VStack(spacing: 0) {
      statusHeader
      if !hermesInstalled() {
        Divider()
        notInstalledBanner
      }
      if let req = ctrl.currentRequest {
        Divider()
        processingRow(req)
      }
      if !ctrl.recentActivity.isEmpty {
        Divider()
        recentSection
      }
      Divider()
      modelSection
      Divider()
      footer
    }
    .frame(width: 310)
  }

  // MARK: Status header

  var statusHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "antenna.radiowaves.left.and.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
        Text("Hermes Control")
          .font(.system(size: 13, weight: .semibold))
        Spacer()
      }
      HStack(spacing: 8) {
        Circle()
          .fill(statusColor)
          .frame(width: 8, height: 8)
        Text(statusText)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
        Spacer()
        if ctrl.isRunning, !ctrl.currentModel.modelId.isEmpty {
          Text(ctrl.modelDisplayName(ctrl.currentModel))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  var notInstalledBanner: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .font(.system(size: 12))
      VStack(alignment: .leading, spacing: 2) {
        Text("Hermes not found")
          .font(.system(size: 12, weight: .medium))
        Text("Install Hermes Agent — this app controls its gateway.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Link(
          "nousresearch.com/hermes",
          destination: URL(string: "https://hermes-agent.nousresearch.com")!
        )
        .font(.system(size: 11))
      }
      Spacer()
    }
    .padding(.horizontal, 14).padding(.vertical, 9)
  }

  var statusColor: Color {
    guard ctrl.isRunning else { return .secondary }
    return ctrl.isProcessing ? .orange : .green
  }

  var statusText: String {
    if ctrl.isProcessing { return "Processing…" }
    return ctrl.isRunning ? "Connected" : "Disconnected"
  }

  // MARK: Processing row (clickable → thinking window)

  func processingRow(_ req: ActivityEntry) -> some View {
    Button {
      ctrl.showThinking(for: req)
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(ctrl.platformName(req.platform))
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
          if !req.user.isEmpty {
            Text(req.user).font(.system(size: 11)).foregroundStyle(.secondary)
          }
          Spacer()
          Text(ctrl.elapsed)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        if !req.message.isEmpty {
          Text(req.message).font(.system(size: 12)).lineLimit(2)
        }
        HStack(spacing: 4) {
          if !req.model.isEmpty {
            Text(ctrl.modelDisplayNameFromId(req.model))
              .font(.system(size: 10)).foregroundStyle(.tertiary)
          }
          Spacer()
          Image(systemName: "brain")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
          Text("View Thinking")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 14).padding(.vertical, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: Recent section

  var recentSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("RECENT")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .padding(.top, 8).padding(.bottom, 2)
      ForEach(Array(ctrl.recentActivity.prefix(5).enumerated()), id: \.element.id) { idx, entry in
        if idx > 0 { Divider().padding(.horizontal, 14) }
        recentRow(entry)
      }
    }
  }

  func recentRow(_ entry: ActivityEntry) -> some View {
    Button {
      ctrl.showThinking(for: entry)
    } label: {
      HStack(alignment: .top, spacing: 8) {
        Text("✓").font(.system(size: 11)).foregroundStyle(.green).padding(.top, 1)
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 4) {
            Text(ctrl.platformName(entry.platform))
              .font(.system(size: 11, weight: .medium))
            if !entry.user.isEmpty {
              Text("·").foregroundStyle(.tertiary)
              Text(entry.user).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let rt = entry.responseTime {
              Text("·").foregroundStyle(.tertiary)
              Text(rt).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
          }
          if !entry.message.isEmpty {
            Text(entry.message).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
          }
          if !entry.model.isEmpty {
            Text(ctrl.modelDisplayNameFromId(entry.model))
              .font(.system(size: 10)).foregroundStyle(.tertiary)
          }
          if let i = entry.inputTokens, let o = entry.outputTokens {
            Text("↑\(i) ↓\(o)\(entry.reasoningTokens.map { " 🧠\($0)" } ?? "")")
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(.tertiary)
          }
        }
        Spacer()
        Image(systemName: "brain")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 14).padding(.vertical, 7)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: Model section

  var modelSection: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("MODEL")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .padding(.top, 8).padding(.bottom, 2)
      ForEach(ctrl.modelOptions) { option in
        ModelRow(
          title: ctrl.modelDisplayName(option),
          isSelected: option == ctrl.currentModel,
          isBusy: ctrl.busy,
          availability: option.availability
        ) {
          ctrl.switchModel(option)
        }
      }
    }
    .padding(.bottom, 6)
  }

  // MARK: Footer

  var footer: some View {
    HStack {
      if ctrl.busy {
        Text("Working…").font(.system(size: 12)).foregroundStyle(.secondary)
      } else {
        Button(ctrl.isRunning ? "Disconnect" : "Connect") { ctrl.toggle() }
          .controlSize(.small)
      }
      Spacer()
      Button {
        NotificationManager.requestOrTest(ctrl: ctrl)
      } label: {
        Image(systemName: "bell")
      }
      .controlSize(.small)
      .help(NotificationManager.notificationDenied
        ? "Notifications blocked — open System Settings"
        : "Enable notifications / send a test")
      Button("Quit") { NSApp.terminate(nil) }
        .controlSize(.small).foregroundStyle(.secondary)
    }
    .padding(.horizontal, 14).padding(.vertical, 9)
  }
}
