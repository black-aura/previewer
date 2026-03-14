import AudioToolbox
import AppKit
@preconcurrency import AVFoundation
import CoreAudioKit
import SwiftUI

extension Notification.Name {
    static let playPreviewNote = Notification.Name("playPreviewNote")
}

final class HostPresentationModel: ObservableObject {
    @Published var showsPluginOnly = false

    func togglePluginOnly() {
        showsPluginOnly.toggle()
    }
}

struct AudioUnitComponentInfo: Identifiable, Hashable {
    let name: String
    let manufacturerName: String
    let typeName: String
    let audioComponentDescription: AudioComponentDescription

    var id: String {
        [
            String(audioComponentDescription.componentType),
            String(audioComponentDescription.componentSubType),
            String(audioComponentDescription.componentManufacturer),
            name,
            manufacturerName,
        ].joined(separator: ".")
    }

    static func == (lhs: AudioUnitComponentInfo, rhs: AudioUnitComponentInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class AudioUnitInstantiationResult: @unchecked Sendable {
    let audioUnit: AVAudioUnit?
    let error: Error?

    init(audioUnit: AVAudioUnit?, error: Error?) {
        self.audioUnit = audioUnit
        self.error = error
    }
}

final class RequestedPluginViewController: @unchecked Sendable {
    let viewController: NSViewController?

    init(viewController: NSViewController?) {
        self.viewController = viewController
    }
}

final class AudioUnitHostModel: ObservableObject, @unchecked Sendable {
    @Published var components: [AudioUnitComponentInfo] = []
    @Published var selectedComponentID: AudioUnitComponentInfo.ID?
    @Published var hostedViewController: NSViewController?
    @Published var statusMessage = "Choose an Audio Unit instrument to load its UI."
    @Published var loadedInstrumentName = "No instrument loaded"

    private let engine = AVAudioEngine()
    private var currentInstrument: AVAudioUnitMIDIInstrument?
    private let previewNote: UInt8 = 60
    private let previewVelocity: UInt8 = 100
    private let previewDuration: TimeInterval = 1.5

    init() {
        refreshComponents()
    }

    func refreshComponents() {
        let manager = AVAudioUnitComponentManager.shared()
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0,
            componentManufacturer: 0,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        components = manager.components(matching: description)
            .map {
                AudioUnitComponentInfo(
                    name: $0.name,
                    manufacturerName: $0.manufacturerName,
                    typeName: $0.typeName,
                    audioComponentDescription: $0.audioComponentDescription
                )
            }
            .sorted {
                if $0.manufacturerName == $1.manufacturerName {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }

                return $0.manufacturerName.localizedCaseInsensitiveCompare($1.manufacturerName) == .orderedAscending
            }

        if let selectedComponentID, components.contains(where: { $0.id == selectedComponentID }) {
            return
        }

        selectedComponentID = components.first?.id
    }

    func loadSelectedAudioUnit() {
        guard let component = selectedComponent else {
            hostedViewController = nil
            loadedInstrumentName = "No instrument loaded"
            statusMessage = components.isEmpty
                ? "No instrument Audio Units were found on this Mac."
                : "Choose an Audio Unit instrument to load its UI."
            return
        }

        statusMessage = "Loading \(component.name)..."
        hostedViewController = nil

        AVAudioUnit.instantiate(with: component.audioComponentDescription, options: []) { [weak self] audioUnit, error in
            let result = AudioUnitInstantiationResult(audioUnit: audioUnit, error: error)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                if let error = result.error {
                    self.loadedInstrumentName = "Load failed"
                    self.statusMessage = "Could not load \(component.name): \(error.localizedDescription)"
                    return
                }

                guard let instrument = result.audioUnit as? AVAudioUnitMIDIInstrument else {
                    self.loadedInstrumentName = "Unsupported Audio Unit"
                    self.statusMessage = "\(component.name) loaded, but it does not expose MIDI instrument playback."
                    return
                }

                self.installInstrument(instrument, named: component.name)
                self.loadPluginView(for: instrument, componentName: component.name)
            }
        }
    }

    func playPreviewNote() {
        guard let currentInstrument else {
            statusMessage = "Load an Audio Unit before trying to play a note."
            return
        }

        currentInstrument.startNote(previewNote, withVelocity: previewVelocity, onChannel: 0)
        statusMessage = "Playing C4 on \(loadedInstrumentName)..."

        DispatchQueue.main.asyncAfter(deadline: .now() + previewDuration) { [weak self] in
            guard let self, let currentInstrument = self.currentInstrument else { return }
            currentInstrument.stopNote(self.previewNote, onChannel: 0)
            self.statusMessage = "Loaded \(self.loadedInstrumentName)."
        }
    }

    private var selectedComponent: AudioUnitComponentInfo? {
        components.first(where: { $0.id == selectedComponentID })
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }

        do {
            try engine.start()
        } catch {
            statusMessage = "Audio engine failed to start: \(error.localizedDescription)"
        }
    }

    private func installInstrument(_ instrument: AVAudioUnitMIDIInstrument, named name: String) {
        if let currentInstrument {
            engine.disconnectNodeOutput(currentInstrument)
            engine.detach(currentInstrument)
        }

        engine.attach(instrument)
        engine.connect(instrument, to: engine.mainMixerNode, format: nil)
        startEngineIfNeeded()

        currentInstrument = instrument
        loadedInstrumentName = name
        statusMessage = "Loaded \(name)."
    }

    private func loadPluginView(for instrument: AVAudioUnitMIDIInstrument, componentName: String) {
        instrument.auAudioUnit.requestViewController { [weak self] (viewController: NSViewController?) in
            let result = RequestedPluginViewController(viewController: viewController)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                if let viewController = result.viewController {
                    self.hostedViewController = viewController
                    self.statusMessage = "Loaded \(componentName)."
                } else {
                    self.hostedViewController = nil
                    self.statusMessage = "\(componentName) loaded, but it does not provide an embeddable plugin UI."
                }
            }
        }
    }
}

struct PluginViewControllerHost: NSViewControllerRepresentable {
    let viewController: NSViewController

    func makeNSViewController(context: Context) -> PluginContainerViewController {
        let container = PluginContainerViewController()
        container.setHostedViewController(viewController)
        return container
    }

    func updateNSViewController(_ nsViewController: PluginContainerViewController, context: Context) {
        nsViewController.setHostedViewController(viewController)
    }
}

final class PluginContainerViewController: NSViewController {
    private weak var hostedViewController: NSViewController?
    private var hostedSizeConstraints: [NSLayoutConstraint] = []
    private let stageView = NSView()

    override func loadView() {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.masksToBounds = true
        view.canDrawSubviewsIntoLayer = true
        self.view = view

        stageView.translatesAutoresizingMaskIntoConstraints = false
        stageView.wantsLayer = true
        stageView.layer?.backgroundColor = NSColor.black.cgColor
        stageView.layer?.masksToBounds = true
        stageView.canDrawSubviewsIntoLayer = true
        view.addSubview(stageView)

        NSLayoutConstraint.activate([
            stageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stageView.topAnchor.constraint(equalTo: view.topAnchor),
            stageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func setHostedViewController(_ newViewController: NSViewController) {
        guard hostedViewController !== newViewController else { return }

        if let hostedViewController {
            hostedViewController.view.removeFromSuperview()
            hostedViewController.removeFromParent()
        }

        addChild(newViewController)
        newViewController.view.wantsLayer = true
        newViewController.view.layer?.backgroundColor = NSColor.black.cgColor
        newViewController.view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        newViewController.view.layer?.masksToBounds = true
        stageView.addSubview(newViewController.view)
        newViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.deactivate(hostedSizeConstraints)

        let preferredSize = resolvedSize(for: newViewController)
        newViewController.view.frame = NSRect(origin: .zero, size: preferredSize)
        hostedSizeConstraints = [
            newViewController.view.widthAnchor.constraint(equalToConstant: preferredSize.width),
            newViewController.view.heightAnchor.constraint(equalToConstant: preferredSize.height),
        ]

        NSLayoutConstraint.activate([
            newViewController.view.centerXAnchor.constraint(equalTo: stageView.centerXAnchor),
            newViewController.view.centerYAnchor.constraint(equalTo: stageView.centerYAnchor),
            newViewController.view.leadingAnchor.constraint(greaterThanOrEqualTo: stageView.leadingAnchor),
            newViewController.view.topAnchor.constraint(greaterThanOrEqualTo: stageView.topAnchor),
            newViewController.view.trailingAnchor.constraint(lessThanOrEqualTo: stageView.trailingAnchor),
            newViewController.view.bottomAnchor.constraint(lessThanOrEqualTo: stageView.bottomAnchor),
        ] + hostedSizeConstraints)

        stageView.needsDisplay = true
        newViewController.view.needsDisplay = true
        hostedViewController = newViewController
    }

    private func resolvedSize(for viewController: NSViewController) -> CGSize {
        let preferredContentSize = viewController.preferredContentSize
        if preferredContentSize.width > 0, preferredContentSize.height > 0 {
            return preferredContentSize
        }

        let fittingSize = viewController.view.fittingSize
        if fittingSize.width > 0, fittingSize.height > 0 {
            return fittingSize
        }

        let frameSize = viewController.view.frame.size
        if frameSize.width > 0, frameSize.height > 0 {
            return frameSize
        }

        return CGSize(width: 800, height: 600)
    }
}

struct ContentView: View {
    @StateObject private var model = AudioUnitHostModel()
    @EnvironmentObject private var presentationModel: HostPresentationModel

    var body: some View {
        Group {
            if presentationModel.showsPluginOnly {
                pluginStage
            } else {
                NavigationSplitView {
                    List(model.components, selection: $model.selectedComponentID) { component in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(component.name)
                                .font(.headline)
                            Text("\(component.manufacturerName) • \(component.typeName)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .navigationTitle("Audio Units")
                    .toolbar {
                        Button("Reload List") {
                            model.refreshComponents()
                        }
                    }
                } detail: {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.loadedInstrumentName)
                                .font(.title2.weight(.semibold))
                            Text(model.statusMessage)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Button("Load Selected") {
                                model.loadSelectedAudioUnit()
                            }
                            .keyboardShortcut(.defaultAction)

                            Button("Play C4") {
                                model.playPreviewNote()
                            }
                        }

                        pluginStage
                    }
                    .padding(20)
                    .navigationTitle("Host")
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 700)
        .onReceive(NotificationCenter.default.publisher(for: .playPreviewNote)) { _ in
            model.playPreviewNote()
        }
    }

    private var pluginStage: some View {
        Group {
            if let hostedViewController = model.hostedViewController {
                PluginViewControllerHost(viewController: hostedViewController)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("Plugin UI Unavailable")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Select an Audio Unit and load it. If the plugin exposes an embeddable Cocoa view, it will appear here.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var localKeyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
        configureWindows()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    private func installKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !event.isARepeat else {
                return event
            }

            if event.charactersIgnoringModifiers?.lowercased() == "a" {
                NotificationCenter.default.post(name: .playPreviewNote, object: nil)
                return nil
            }

            return event
        }
    }

    @MainActor
    private func configureWindows() {
        for window in NSApp.windows {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.remove(.titled)
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
    }
}

@main
struct PreviewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var presentationModel = HostPresentationModel()

    var body: some Scene {
        WindowGroup("Audio Unit Previewer") {
            ContentView()
                .environmentObject(presentationModel)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("View") {
                Button(presentationModel.showsPluginOnly ? "Show Host Panels" : "Hide All Panels") {
                    presentationModel.togglePluginOnly()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
