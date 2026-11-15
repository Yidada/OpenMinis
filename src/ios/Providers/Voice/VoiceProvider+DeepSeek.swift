import Foundation

// MARK: - DeepSeek (speech recognition only)
//
// DeepSeek's speech-to-text is NOT the OpenAI path. It lives at
// `POST /v1/tools/asr`, `multipart/form-data`, with ONE field — `file`
// (16-bit PCM WAV or Ogg Opus) — and it accepts none of the OpenAI extras
// (`model` / `language` / `response_format` / `prompt`). The response is
// `{"text", "duration_ms", "request_id"}`; the base parser decodes `text`
// and ignores the extra keys, so only the REQUEST has to be reshaped here.
//
// TTS (`/v1/tools/tts`) is deliberately not wired yet: it streams raw
// WAV/PCM from a vendor-specific JSON body (`voice_id`, `filter_markdown`),
// which is a separate change. `supportsVoiceOutput` is false until then.
//
// The model id is a LOCAL label only — nothing is sent in its place —
// so pick an id that does not trip `usesChatBasedASR` (no "audio"/"omni").

final class DeepSeekVoiceProvider: VoiceProvider {

    override var supportsVoiceOutput: Bool { false }

    override func defaultVoiceInputModel() -> String { "deepseek-asr" }

    override func voiceInputEndpointPath() -> String { "/v1/tools/asr" }

    override func buildVoiceInputRequest(_ request: VoiceInputRequest) throws -> URLRequest {
        let urlStr = composedURLString(path: voiceInputEndpointPath())
        guard let url = URL(string: urlStr) else {
            throw VoiceProviderError.parseError("Invalid URL: \(urlStr)")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        applyVoiceAuth(&urlRequest)

        let boundary = "VoiceBoundary-\(UUID().uuidString)"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)",
                            forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = Self.singleFileMultipartBody(file: request.audioData,
                                                          boundary: boundary)
        return urlRequest
    }

    override func buildVoiceOutputRequest(_ request: VoiceOutputRequest) throws -> URLRequest {
        throw VoiceProviderError.unsupported("DeepSeek speech synthesis is not wired yet")
    }

    /// A `multipart/form-data` body with a single `file` part.
    ///
    /// The base class's builder (`buildMultipartBody`) also emits model,
    /// language, response_format and prompt; this endpoint documents only
    /// `file`, and sending unknown fields to a strict parser is a needless
    /// 400 risk. The Data helpers in VoiceProvider.swift are file-private,
    /// so the few bytes are written out here instead.
    private static func singleFileMultipartBody(file: Data, boundary: String) -> Data {
        var body = Data()
        body.reserveCapacity(file.count + 256)
        func append(_ text: String) { body.append(Data(text.utf8)) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"voice.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(file)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}
