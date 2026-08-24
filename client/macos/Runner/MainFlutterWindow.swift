import Cocoa
import FlutterMacOS
import AVFoundation
import CoreAudioTypes

class MainFlutterWindow: NSWindow {
  /// 语音录制器（record 插件 macOS stop() 挂起，原生通道替代）
  private var voiceRecorder: AVAudioRecorder?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 视频缩略图通道（F-MEDIA-1）：AVAssetImageGenerator 抽取首帧，返回 JPEG 字节
    let thumbChannel = FlutterMethodChannel(
      name: "lonisle/video_thumb",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    thumbChannel.setMethodCallHandler { call, result in
      guard call.method == "thumbnail",
            let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let asset = AVAsset(url: URL(fileURLWithPath: path))
          let generator = AVAssetImageGenerator(asset: asset)
          generator.appliesPreferredTrackTransform = true
          generator.maximumSize = CGSize(width: 480, height: 480)
          let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
          let rep = NSBitmapImageRep(cgImage: cgImage)
          guard let data = rep.representation(
            using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            DispatchQueue.main.async {
              result(FlutterError(code: "encode", message: "JPEG 编码失败", details: nil))
            }
            return
          }
          DispatchQueue.main.async {
            result(FlutterStandardTypedData(bytes: data))
          }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "extract", message: error.localizedDescription, details: nil))
          }
        }
      }
    }

    // 语音录制通道（F-MEDIA-7）：AVAudioRecorder 录制 AAC/m4a，
    // stop 同步可靠（record 插件在 macOS 的 stop() 永不返回）
    let voiceChannel = FlutterMethodChannel(
      name: "lonisle/voice_recorder",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    voiceChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "requestPermission":
        // 显式请求麦克风权限（未决定时触发系统授权弹窗）
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
          result(true)
        case .notDetermined:
          AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { result(granted) }
          }
        default:
          NSLog("[Voice] 麦克风权限状态：%ld（denied/restricted）",
                AVCaptureDevice.authorizationStatus(for: .audio).rawValue)
          result(false)
        }
      case "start":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "args", message: "缺少 path", details: nil))
          return
        }
        let settings: [String: Any] = [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 44100,
          AVNumberOfChannelsKey: 1,
          AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
          let recorder = try AVAudioRecorder(
            url: URL(fileURLWithPath: path), settings: settings)
          // prepareToRecord 立即创建文件并打开编码器；
          // record() 返回 false 说明录音未真正启动（后续 stop 必然文件不存在）
          guard recorder.prepareToRecord(), recorder.record() else {
            let tcc = AVCaptureDevice.authorizationStatus(for: .audio).rawValue
            NSLog("[Voice] record() 返回 false，TCC 状态=%ld", tcc)
            result(FlutterError(
              code: "start",
              message: "录音启动失败（麦克风不可用或权限被拒）",
              details: "TCC 状态: \(tcc)（0=未决定 1=限制 2=拒绝 3=已允许）"))
            return
          }
          self?.voiceRecorder = recorder
          result(true)
        } catch {
          result(FlutterError(code: "start", message: error.localizedDescription, details: nil))
        }
      case "stop":
        guard let recorder = self?.voiceRecorder else {
          result(nil)
          return
        }
        recorder.stop()
        self?.voiceRecorder = nil
        // stop 只标记结束，文件头由系统异步收尾 —— 轮询等待文件出现，
        // 否则 Dart 侧立即读文件会 PathNotFoundException
        let url = recorder.url
        DispatchQueue.global(qos: .userInitiated).async {
          var attempts = 0
          while attempts < 50 {
            if FileManager.default.fileExists(atPath: url.path),
               (try? FileHandle(forReadingFrom: url)) != nil {
              break
            }
            attempts += 1
            Thread.sleep(forTimeInterval: 0.05)
          }
          DispatchQueue.main.async {
            result(url.path)
          }
        }
      case "cancel":
        self?.voiceRecorder?.stop()
        self?.voiceRecorder?.deleteRecording()
        self?.voiceRecorder = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
