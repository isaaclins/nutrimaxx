import SwiftUI
import AVFoundation

/// Camera barcode scanner. Reports the first scanned barcode string.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        let onCancel: () -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !didScan,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            didScan = true
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScan(value)
        }
    }
}

/// Hosts the capture session and a Cancel button.
final class ScannerViewController: UIViewController {
    weak var coordinator: BarcodeScannerView.Coordinator?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancel)
        NSLayoutConstraint.activate([
            cancel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            cancel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(coordinator, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    @objc private func cancelTapped() {
        coordinator?.onCancel()
    }
}
