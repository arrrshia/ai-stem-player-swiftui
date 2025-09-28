import AVFoundation
import Combine

final class StemEngine: ObservableObject {
    enum Stem: Int, CaseIterable {
        case right = 0, top, left, bottom
    }

    @Published var levels: [Int] = [4, 4, 4, 4] { // 1...4
        didSet { applyVolumes() }
    }
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoaded = false
    var maxVolume: Float = 1.0

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = Stem.allCases.map { _ in AVAudioPlayerNode() }
    private var mixer: AVAudioMixerNode { engine.mainMixerNode }
    private var audioFiles: [AVAudioFile?] = [nil, nil, nil, nil]
    private var endObservers: [AnyCancellable] = []
    private var securityResources: [SecurityScopedResource] = []

    init() {
        setupGraph()
    }

    private func setupGraph() {
        engine.stop()
        engine.reset()

        // Attach and connect 4 player nodes
        players.forEach { player in
            engine.attach(player)
            engine.connect(player, to: mixer, format: nil)
        }

        engine.prepare()
        do { try engine.start() } catch { print("Engine start error: \(error)") }
    }

    func load(urls: [URL]) {
        releaseSecurityResources()
        loadResolved(urls: urls)
    }

    func load(folder: StemFolder) {
        let resources = folder.makeStemResources()
        guard !resources.isEmpty else { return }
        releaseSecurityResources()
        securityResources = resources
        loadResolved(urls: resources.map { $0.url })
    }

    func play() {
        guard isLoaded else { return }
        scheduleAll()
        players.forEach { if !$0.isPlaying { $0.play() } }
        isPlaying = true
    }

    func pause() {
        players.forEach { $0.pause() }
        isPlaying = false
    }

    func stop() {
        players.forEach { $0.stop() }
        isPlaying = false
    }

    deinit {
        releaseSecurityResources()
    }

    private func scheduleAll() {
        // Schedule from start for each loaded file
        for i in 0..<players.count {
            guard let file = audioFiles[i] else { continue }
            players[i].stop()
            file.framePosition = 0
            players[i].scheduleFile(file, at: nil, completionHandler: nil)
        }
        applyVolumes()
    }

    private func levelToVolume(_ level: Int) -> Float {
        // 1..4 -> 0..1 mapped like the web demo ((level - 1)/3 * maxVolume)
        let clamped = max(1, min(4, level))
        return Float(clamped - 1) / 3.0 * maxVolume
    }

    private func applyVolumes() {
        for i in 0..<players.count {
            let vol = levelToVolume(levels[i])
            players[i].volume = vol
        }
    }

    private func loadResolved(urls: [URL]) {
        stop()
        audioFiles = [nil, nil, nil, nil]
        for i in 0..<min(urls.count, 4) {
            audioFiles[i] = try? AVAudioFile(forReading: urls[i])
        }
        if urls.count == 1 {
            audioFiles = Stem.allCases.map { _ in try? AVAudioFile(forReading: urls[0]) }
        }
        isLoaded = audioFiles.contains { $0 != nil }
    }

    private func releaseSecurityResources() {
        securityResources.forEach { $0.stopAccessing() }
        securityResources.removeAll()
    }
}
