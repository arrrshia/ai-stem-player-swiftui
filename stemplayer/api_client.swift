//
//  api_client.swift
//  stemplayer
//
//  Created by Andrew Arshia Almasi on 9/27/25.
//

import Foundation
import os

// MARK: - Logger

private let log = Logger(subsystem: "AudioSeparatorAPIClient", category: "api")

// MARK: - Helpers

extension Dictionary where Key == String, Value == String {
    mutating func set(_ key: String, bool value: Bool) { self[key] = value ? "true" : "false" }
    mutating func set<T: LosslessStringConvertible>(_ key: String, number value: T) { self[key] = String(value) }
    mutating func setJSON<T: Encodable>(_ key: String, _ value: T?) {
        guard let value else { return }
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        if let data = try? enc.encode(value), let s = String(data: data, encoding: .utf8) {
            self[key] = s
        }
    }
}

private extension CharacterSet {
    static let urlPathAllowedStrict: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        // Remove "/" to make it fully safe for path components.
        set.remove(charactersIn: "/")
        return set
    }()
}

private func percentEncodePathComponent(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowedStrict) ?? s
}

private struct MultipartFormData {
    let boundary: String = "Boundary-\(UUID().uuidString)"
    private(set) var body = Data()

    mutating func addField(name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func addFileField(name: String, filename: String, mimeType: String, fileData: Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
    }

    mutating func finalize() {
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
    }

    var contentTypeHeader: String { "multipart/form-data; boundary=\(boundary)" }
}

// MARK: - Dynamic Files field (list or map)

enum FilesField: Decodable {
    case list([String])
    case map([String: String])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([String].self) {
            self = .list(arr)
        } else if let dict = try? container.decode([String: String].self) {
            self = .map(dict)
        } else {
            throw DecodingError.typeMismatch(
                FilesField.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected [String] or [String:String]")
            )
        }
    }

    var asList: [String] {
        switch self {
        case .list(let a): return a
        case .map(let m):  return Array(m.values)
        }
    }

    var asMap: [String: String] {
        switch self {
        case .list(let a): return Dictionary(uniqueKeysWithValues: a.map { ($0, $0) })
        case .map(let m):  return m
        }
    }

    var count: Int {
        switch self {
        case .list(let a): return a.count
        case .map(let m):  return m.count
        }
    }
}

// MARK: - Decodable responses (loose, with fallbacks)

struct SeparateResponse: Decodable {
    let task_id: String
}

struct StatusResponse: Decodable {
    let status: String
    let progress: Int?
    let current_model_index: Int?
    let total_models: Int?
    let files: FilesField?

    // allow unknown extra keys without failing
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? c.decode(String.self, forKey: .status)) ?? "unknown"
        progress = try? c.decode(Int.self, forKey: .progress)
        current_model_index = try? c.decode(Int.self, forKey: .current_model_index)
        total_models = try? c.decode(Int.self, forKey: .total_models)
        files = try? c.decode(FilesField.self, forKey: .files)
    }

    enum CodingKeys: String, CodingKey {
        case status, progress, current_model_index, total_models, files
    }
}

struct HealthResponse: Decodable {
    let version: String?
}

// MARK: - Parameters (mirrors Python defaults)

struct SeparatorParams: Encodable {
    // Model selection
    var model: String? = nil
    var models: [String]? = nil

    // Output
    var output_format: String = "flac"
    var output_bitrate: String? = nil
    var normalization_threshold: Double = 0.9
    var amplification_threshold: Double = 0.0
    var output_single_stem: String? = nil
    var invert_using_spec: Bool = false
    var sample_rate: Int = 44100
    var use_soundfile: Bool = false
    var use_autocast: Bool = false
    var custom_output_names: [String: String]? = nil

    // MDX
    var mdx_segment_size: Int = 256
    var mdx_overlap: Double = 0.25
    var mdx_batch_size: Int = 1
    var mdx_hop_length: Int = 1024
    var mdx_enable_denoise: Bool = false

    // VR
    var vr_batch_size: Int = 1
    var vr_window_size: Int = 512
    var vr_aggression: Int = 5
    var vr_enable_tta: Bool = false
    var vr_high_end_process: Bool = false
    var vr_enable_post_process: Bool = false
    var vr_post_process_threshold: Double = 0.2

    // Demucs
    var demucs_segment_size: String = "Default"
    var demucs_shifts: Int = 2
    var demucs_overlap: Double = 0.25
    var demucs_segments_enabled: Bool = true

    // MDXC
    var mdxc_segment_size: Int = 256
    var mdxc_override_model_segment_size: Bool = false
    var mdxc_overlap: Int = 8
    var mdxc_batch_size: Int = 1
    var mdxc_pitch_shift: Int = 0
}

// MARK: - High-level result (mirrors Python return)

struct SeparationCompleted {
    let taskID: String
    let status: String          // "completed" | "error" | "timeout"
    let files: FilesField?
    var downloadedFiles: [URL] = []
    var error: String? = nil
}

// MARK: - Client

final class AudioSeparatorAPIClient {
    private let apiURL: URL
    private let urlSession: URLSession

    init(apiURL: String, session: URLSession = .shared) {
        self.apiURL = URL(string: apiURL.trimmingCharacters(in: .whitespacesAndNewlines))!
        self.urlSession = session
    }

    // POST /separate
    func separateAudio(fileURL: URL, params: SeparatorParams = SeparatorParams(), timeout: TimeInterval = 300) async throws -> SeparateResponse {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "AudioSeparator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio file not found: \(fileURL.path)"])
        }

        let endpoint = apiURL.appendingPathComponent("separate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout

        // Multipart payload
        var form = MultipartFormData()

        // Handle model vs models (back-compat)
        if let models = params.models, !models.isEmpty {
            // server expects JSON string for "models"
            var fields: [String: String] = [:]
            fields.setJSON("models", models)
            for (k, v) in fields { form.addField(name: k, value: v) }
        } else if let model = params.model {
            form.addField(name: "model", value: model)
        }

        // All other parameters as strings
        var fields: [String: String] = [:]
        fields["output_format"] = params.output_format
        if let br = params.output_bitrate { fields["output_bitrate"] = br }
        fields.set("normalization_threshold", number: params.normalization_threshold)
        fields.set("amplification_threshold", number: params.amplification_threshold)
        if let single = params.output_single_stem { fields["output_single_stem"] = single }
        fields.set("invert_using_spec", bool: params.invert_using_spec)
        fields.set("sample_rate", number: params.sample_rate)
        fields.set("use_soundfile", bool: params.use_soundfile)
        fields.set("use_autocast", bool: params.use_autocast)
        fields.setJSON("custom_output_names", params.custom_output_names)

        // MDX
        fields.set("mdx_segment_size", number: params.mdx_segment_size)
        fields.set("mdx_overlap", number: params.mdx_overlap)
        fields.set("mdx_batch_size", number: params.mdx_batch_size)
        fields.set("mdx_hop_length", number: params.mdx_hop_length)
        fields.set("mdx_enable_denoise", bool: params.mdx_enable_denoise)

        // VR
        fields.set("vr_batch_size", number: params.vr_batch_size)
        fields.set("vr_window_size", number: params.vr_window_size)
        fields.set("vr_aggression", number: params.vr_aggression)
        fields.set("vr_enable_tta", bool: params.vr_enable_tta)
        fields.set("vr_high_end_process", bool: params.vr_high_end_process)
        fields.set("vr_enable_post_process", bool: params.vr_enable_post_process)
        fields.set("vr_post_process_threshold", number: params.vr_post_process_threshold)

        // Demucs
        fields["demucs_segment_size"] = params.demucs_segment_size
        fields.set("demucs_shifts", number: params.demucs_shifts)
        fields.set("demucs_overlap", number: params.demucs_overlap)
        fields.set("demucs_segments_enabled", bool: params.demucs_segments_enabled)

        // MDXC
        fields.set("mdxc_segment_size", number: params.mdxc_segment_size)
        fields.set("mdxc_override_model_segment_size", bool: params.mdxc_override_model_segment_size)
        fields.set("mdxc_overlap", number: params.mdxc_overlap)
        fields.set("mdxc_batch_size", number: params.mdxc_batch_size)
        fields.set("mdxc_pitch_shift", number: params.mdxc_pitch_shift)

        for (k, v) in fields {
            form.addField(name: k, value: v)
        }

        // File field
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let mime = "audio/\(fileURL.pathExtension.lowercased().isEmpty ? "octet-stream" : fileURL.pathExtension.lowercased())"
        form.addFileField(name: "file", filename: filename, mimeType: mime, fileData: fileData)
        form.finalize()

        request.setValue(form.contentTypeHeader, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.body

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "AudioSeparator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Separation request failed", "response": response, "body": String(data: data, encoding: .utf8) ?? ""])
        }

        return try JSONDecoder().decode(SeparateResponse.self, from: data)
    }

    // GET /status/{task_id}
    func getJobStatus(_ taskID: String) async throws -> StatusResponse {
        let url = apiURL.appendingPathComponent("status").appendingPathComponent(taskID)
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "AudioSeparator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Status request failed"])
        }
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }

    // Convenience: submit + poll + (optionally) download
    func separateAudioAndWait(
        fileURL: URL,
        params: SeparatorParams = SeparatorParams(),
        timeoutSeconds: Int = 600,
        pollIntervalSeconds: Int = 10,
        download: Bool = true,
        outputDirectory: URL? = nil
    ) async -> SeparationCompleted {
        do {
            let submit = try await separateAudio(fileURL: fileURL, params: params)
            let taskID = submit.task_id
            log.info("Job submitted. Task ID: \(taskID, privacy: .public)")

            let start = Date()
            var lastProgress: Int = -1

            while Date().timeIntervalSince(start) < TimeInterval(timeoutSeconds) {
                do {
                    let status = try await getJobStatus(taskID)
                    if let p = status.progress, p != lastProgress {
                        if let idx = status.current_model_index, let total = status.total_models {
                            log.info("Progress: \(p)% (Model \(idx + 1)/\(total))")
                        } else {
                            log.info("Progress: \(p)%")
                        }
                        lastProgress = p
                    }

                    switch status.status.lowercased() {
                    case "completed":
                        log.info("Separation completed.")
                        var result = SeparationCompleted(taskID: taskID, status: "completed", files: status.files, downloadedFiles: [])
                        guard download, let filesField = status.files else {
                            return result
                        }

                        var downloaded: [URL] = []

                        switch filesField {
                        case .list(let filenames):
                            log.info("Downloading \(filenames.count) files (legacy list).")
                            for name in filenames {
                                do {
                                    let outputURL = (outputDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)
                                        .appendingPathComponent(name)
                                    let saved = try await downloadFile(taskID: taskID, filename: name, outputURL: outputURL)
                                    downloaded.append(saved)
                                } catch {
                                    log.error("Failed to download \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                    _ = try? await getServerVersion() // log-able side effect
                                }
                            }

                        case .map(let hashToName):
                            log.info("Downloading \(hashToName.count) files (hash map).")
                            for (hash, name) in hashToName {
                                do {
                                    let outputURL = (outputDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)
                                        .appendingPathComponent(name)
                                    let saved = try await downloadFileByHash(taskID: taskID, fileHash: hash, filename: name, outputURL: outputURL)
                                    downloaded.append(saved)
                                } catch {
                                    log.error("Failed to download \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                                    _ = try? await getServerVersion()
                                }
                            }
                        }

                        result.downloadedFiles = downloaded
                        log.info("Downloaded \(downloaded.count) files.")
                        return result

                    case "error":
                        return SeparationCompleted(taskID: taskID, status: "error", files: nil, downloadedFiles: [], error: "Job failed")
                    default:
                        break
                    }
                } catch {
                    log.warning("Polling error: \(error.localizedDescription, privacy: .public)")
                }

                try? await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds) * 1_000_000_000)
            }

            return SeparationCompleted(taskID: taskID, status: "timeout", files: nil, downloadedFiles: [], error: "Job polling timed out after \(timeoutSeconds) seconds")
        } catch {
            log.error("Submission failed: \(error.localizedDescription, privacy: .public)")
            return SeparationCompleted(taskID: "", status: "error", files: nil, downloadedFiles: [], error: error.localizedDescription)
        }
    }

    // Legacy filename download: GET /download/{task_id}/{encodedFilename}
    func downloadFile(taskID: String, filename: String, outputURL: URL) async throws -> URL {
        let encoded = percentEncodePathComponent(filename)
        let url = apiURL
            .appendingPathComponent("download")
            .appendingPathComponent(taskID)
            .appendingPathComponent(encoded)

        log.info("Downloading (legacy) \(filename, privacy: .public) from \(url.absoluteString, privacy: .public)")
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AudioSeparator", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            log.error("Download failed. Status: \(http.statusCode), headers: \(http.allHeaderFields), body (first 500): \(body.prefix(500))")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "AudioSeparator", code: 5, userInfo: [NSLocalizedDescriptionKey: "Download failed with status \(http.statusCode)"])
        }
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    // Hash download: GET /download/{task_id}/{file_hash}
    func downloadFileByHash(taskID: String, fileHash: String, filename: String, outputURL: URL) async throws -> URL {
        let url = apiURL
            .appendingPathComponent("download")
            .appendingPathComponent(taskID)
            .appendingPathComponent(fileHash)

        log.info("Downloading (hash) \(filename, privacy: .public) from \(url.absoluteString, privacy: .public)")
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AudioSeparator", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        if http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            log.error("Download failed. Status: \(http.statusCode), headers: \(http.allHeaderFields), body (first 500): \(body.prefix(500))")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "AudioSeparator", code: 7, userInfo: [NSLocalizedDescriptionKey: "Download failed with status \(http.statusCode)"])
        }
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    // GET /health
    func getServerVersion() async throws -> String {
        let url = apiURL.appendingPathComponent("health")
        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "AudioSeparator", code: 11, userInfo: [NSLocalizedDescriptionKey: "Health check failed"])
        }
        let health = try JSONDecoder().decode(HealthResponse.self, from: data)
        return health.version ?? "unknown"
    }
}

// MARK: - Example Usage
/*
let client = AudioSeparatorAPIClient(apiURL: "https://your-separator.example.com")
Task {
    do {
        var params = SeparatorParams()
        params.models = ["mdx23c", "htdemucs_ft"]
        let fileURL = URL(fileURLWithPath: "/path/to/audio.wav")

        let result = await client.separateAudioAndWait(
            fileURL: fileURL,
            params: params,
            timeoutSeconds: 600,
            pollIntervalSeconds: 10,
            download: true,
            outputDirectory: FileManager.default.temporaryDirectory
        )

        switch result.status {
        case "completed":
            print("Done. Downloaded: \(result.downloadedFiles)")
        case "error", "timeout":
            print("Failed: \(result.error ?? "Unknown error")")
        default:
            break
        }
    }
}
*/
