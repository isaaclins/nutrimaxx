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

/// Hosts the capture session and a Cancel button. Requests camera access first
/// and only configures/starts the session once access is granted, so the
/// preview never shows a permanent black frame.
final class ScannerViewController: UIViewController {
    weak var coordinator: BarcodeScannerView.Coordinator?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "nutrimaxx.scanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addOverlayControls()
        requestAccessThenConfigure()
    }

    private func addOverlayControls() {
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancel)

        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            cancel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            cancel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func requestAccessThenConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configureAndStart() }
                    else { self?.showStatus("Camera access denied.") }
                }
            }
        default:
            showStatus("Camera access is off. Enable it in Settings > nutrimaxx.")
        }
    }

    private func configureAndStart() {
        statusLabel.text = nil

        // Build the preview layer on the main thread so it has correct bounds.
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else {
                self?.startRunningIfNeeded()
                return
            }
            self.session.beginConfiguration()

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.showStatus("No camera available.") }
                return
            }
            self.session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.showStatus("Scanner unavailable.") }
                return
            }
            self.session.addOutput(output)
            output.setMetadataObjectsDelegate(self.coordinator, queue: .main)
            output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .code39, .qr]

            self.session.commitConfiguration()
            self.isConfigured = true
            self.session.startRunning()
        }
    }

    private func startRunningIfNeeded() {
        if !session.isRunning { session.startRunning() }
    }

    private func showStatus(_ message: String) {
        statusLabel.text = message
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @objc private func cancelTapped() {
        coordinator?.onCancel()
    }
}
