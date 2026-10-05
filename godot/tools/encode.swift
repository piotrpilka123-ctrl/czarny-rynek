// Składa klatki JPG i ścieżkę WAV w film MP4 (H.264 + AAC).
// Użycie: swift encode.swift <folder z klatkami> <audio.wav> <wyjście.mp4> [fps] [bitrate w Mb/s] [wysokość obrazu]
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("użycie: swift encode.swift <klatki> <audio.wav> <wyjście.mp4> [fps]")
    exit(1)
}
let framesDir = URL(fileURLWithPath: args[1])
let audioURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])
let fps = Int32(args.count > 4 ? (Int(args[4]) ?? 30) : 30)
let mbps = args.count > 5 ? (Double(args[5]) ?? 11.0) : 11.0
let outHeight = args.count > 6 ? (Int(args[6]) ?? 0) : 0

let files = (try FileManager.default.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil))
    .filter { $0.pathExtension.lowercased() == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else {
    print("brak klatek")
    exit(1)
}
print("klatek: \(files.count)")

func loadImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

guard let first = loadImage(files[0]) else {
    print("nie umiem wczytać pierwszej klatki")
    exit(1)
}
let height = outHeight > 0 ? outHeight : first.height
let width = outHeight > 0 ? (first.width * outHeight / first.height) / 2 * 2 : first.width
try? FileManager.default.removeItem(at: outURL)

let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let vSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: Int(mbps * 1_000_000),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: 60,
    ],
]
let vin = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings)
vin.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: vin,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
writer.add(vin)

// dźwięk
let audioAsset = AVURLAsset(url: audioURL)
var ain: AVAssetWriterInput? = nil
var reader: AVAssetReader? = nil
var rout: AVAssetReaderTrackOutput? = nil
if FileManager.default.fileExists(atPath: audioURL.path), let track = audioAsset.tracks(withMediaType: .audio).first {
    let r = try AVAssetReader(asset: audioAsset)
    let o = AVAssetReaderTrackOutput(track: track, outputSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ])
    r.add(o)
    let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 192_000,
    ])
    a.expectsMediaDataInRealTime = false
    writer.add(a)
    ain = a
    reader = r
    rout = o
} else {
    print("uwaga: brak ścieżki dźwiękowej, film będzie niemy")
}

guard writer.startWriting() else {
    print("błąd startu: \(String(describing: writer.error))")
    exit(1)
}
writer.startSession(atSourceTime: .zero)
reader?.startReading()

let group = DispatchGroup()
var frameIndex = 0
group.enter()
vin.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
    while vin.isReadyForMoreMediaData {
        if frameIndex >= files.count {
            vin.markAsFinished()
            group.leave()
            return
        }
        autoreleasepool {
            guard let pool = adaptor.pixelBufferPool else { return }
            var pbOpt: CVPixelBuffer? = nil
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOpt)
            guard let pb = pbOpt, let img = loadImage(files[frameIndex]) else { return }
            CVPixelBufferLockBaseAddress(pb, [])
            if let ctx = CGContext(
                data: CVPixelBufferGetBaseAddress(pb), width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
            {
                ctx.interpolationQuality = .high
                ctx.draw(img, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frameIndex), timescale: fps))
        }
        frameIndex += 1
        if frameIndex % 300 == 0 { print("  wideo \(frameIndex)/\(files.count)") }
    }
}
if let a = ain, let o = rout {
    let limit = CMTime(value: CMTimeValue(files.count), timescale: fps)
    group.enter()
    a.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
        while a.isReadyForMoreMediaData {
            if let sb = o.copyNextSampleBuffer(), CMSampleBufferGetPresentationTimeStamp(sb) < limit {
                a.append(sb)
            } else {
                a.markAsFinished()
                group.leave()
                return
            }
        }
    }
}
group.wait()
let done = DispatchSemaphore(value: 0)
writer.endSession(atSourceTime: CMTime(value: CMTimeValue(files.count), timescale: fps))
writer.finishWriting { done.signal() }
done.wait()
if writer.status == .completed {
    let size = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
    print("gotowe: \(outURL.path) (\(size / 1_000_000) MB, \(Double(files.count) / Double(fps)) s)")
} else {
    print("błąd zapisu: \(String(describing: writer.error))")
    exit(1)
}
