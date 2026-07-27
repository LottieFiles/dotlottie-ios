//
//  UIKitExampleViewController.swift
//  DotLottieIosTestApp
//
//  Example of using DotLottiePlayerUIView (UIKit approach similar to LottieAnimationView)
//

#if canImport(UIKit) && !os(tvOS)
    import UIKit
    import DotLottie

    class UIKitExampleViewController: UIViewController {

        private var playerView: DotLottiePlayerUIView!
        private var playPauseButton: UIButton!
        private var stopButton: UIButton!
        private var progressSlider: UISlider!
        private var speedSlider: UISlider!
        private var loopSwitch: UISwitch!
        private var statusLabel: UILabel!
        private var wasPlayingBeforeScrub = false

        override func viewDidLoad() {
            super.viewDidLoad()

            view.backgroundColor = .systemBackground
            title = "UIKit DotLottiePlayerUIView Example"

            setupPlayerView()
            setupControls()
            setupConstraints()
        }

        private func setupPlayerView() {
            // Create config
            let config = AnimationConfig(
                autoplay: false,
                loop: false,
                speed: 1.0
            )

            // Initialize with file name from bundle
            playerView = DotLottiePlayerUIView(
                name: "Flow",
                bundle: .main,
                config: config
            ) { [weak self] view, error in
                if let error = error {
                    print("Error loading animation: \(error)")
                } else {
                    print("Animation loaded successfully!")
                    self?.updateStatusLabel()
                }
            }

            playerView.translatesAutoresizingMaskIntoConstraints = false
            playerView.loopMode = .playOnce
            playerView.backgroundColor = .systemGray6
            playerView.layer.cornerRadius = 12
            playerView.clipsToBounds = true

            view.addSubview(playerView)
        }

        private func setupControls() {
            // Play/Pause Toggle Button
            playPauseButton = UIButton(type: .system)
            playPauseButton.setTitle("Play", for: .normal)
            playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
            playPauseButton.translatesAutoresizingMaskIntoConstraints = false

            // Stop Button
            stopButton = UIButton(type: .system)
            stopButton.setTitle("Stop", for: .normal)
            stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
            stopButton.translatesAutoresizingMaskIntoConstraints = false

            // Progress Slider
            let progressLabel = UILabel()
            progressLabel.text = "Progress:"
            progressLabel.font = .systemFont(ofSize: 14)
            progressLabel.translatesAutoresizingMaskIntoConstraints = false

            progressSlider = UISlider()
            progressSlider.minimumValue = 0
            progressSlider.maximumValue = 1
            progressSlider.value = 0
            progressSlider.isContinuous = true
            progressSlider.addTarget(self, action: #selector(progressChanged), for: .valueChanged)
            progressSlider.addTarget(
                self, action: #selector(progressSliderTouchBegan), for: .touchDown)
            progressSlider.addTarget(
                self, action: #selector(progressSliderTouchEnded),
                for: [.touchUpInside, .touchUpOutside, .touchCancel])
            progressSlider.translatesAutoresizingMaskIntoConstraints = false

            // Speed Slider
            let speedLabel = UILabel()
            speedLabel.text = "Speed:"
            speedLabel.font = .systemFont(ofSize: 14)
            speedLabel.translatesAutoresizingMaskIntoConstraints = false

            speedSlider = UISlider()
            speedSlider.minimumValue = 0.25
            speedSlider.maximumValue = 3.0
            speedSlider.value = 1.0
            speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
            speedSlider.translatesAutoresizingMaskIntoConstraints = false

            // Loop Switch
            let loopLabel = UILabel()
            loopLabel.text = "Loop:"
            loopLabel.font = .systemFont(ofSize: 14)
            loopLabel.translatesAutoresizingMaskIntoConstraints = false

            loopSwitch = UISwitch()
            loopSwitch.isOn = false
            loopSwitch.addTarget(self, action: #selector(loopChanged), for: .valueChanged)
            loopSwitch.translatesAutoresizingMaskIntoConstraints = false

            // Status Label
            statusLabel = UILabel()
            statusLabel.text = "Status: Stopped"
            statusLabel.font = .systemFont(ofSize: 12)
            statusLabel.textColor = .secondaryLabel
            statusLabel.textAlignment = .center
            statusLabel.numberOfLines = 0
            statusLabel.translatesAutoresizingMaskIntoConstraints = false

            // Add to view
            let buttonStack = UIStackView(arrangedSubviews: [playPauseButton, stopButton])
            buttonStack.axis = .horizontal
            buttonStack.distribution = .fillEqually
            buttonStack.spacing = 16
            buttonStack.translatesAutoresizingMaskIntoConstraints = false

            let progressStack = UIStackView(arrangedSubviews: [progressLabel, progressSlider])
            progressStack.axis = .horizontal
            progressStack.spacing = 12
            progressStack.translatesAutoresizingMaskIntoConstraints = false

            let speedStack = UIStackView(arrangedSubviews: [speedLabel, speedSlider])
            speedStack.axis = .horizontal
            speedStack.spacing = 12
            speedStack.translatesAutoresizingMaskIntoConstraints = false

            let loopStack = UIStackView(arrangedSubviews: [loopLabel, loopSwitch])
            loopStack.axis = .horizontal
            loopStack.spacing = 12
            loopStack.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(buttonStack)
            view.addSubview(progressStack)
            view.addSubview(speedStack)
            view.addSubview(loopStack)
            view.addSubview(statusLabel)

            // Constraints
            NSLayoutConstraint.activate([
                buttonStack.topAnchor.constraint(equalTo: playerView.bottomAnchor, constant: 24),
                buttonStack.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                buttonStack.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

                progressStack.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 24),
                progressStack.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                progressStack.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

                speedStack.topAnchor.constraint(equalTo: progressStack.bottomAnchor, constant: 16),
                speedStack.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                speedStack.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

                loopStack.topAnchor.constraint(equalTo: speedStack.bottomAnchor, constant: 16),
                loopStack.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),

                statusLabel.topAnchor.constraint(equalTo: loopStack.bottomAnchor, constant: 24),
                statusLabel.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                statusLabel.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            ])

            // Start a timer to update UI
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateUI()
            }
        }

        private func setupConstraints() {
            NSLayoutConstraint.activate([
                playerView.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                playerView.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                playerView.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
                playerView.heightAnchor.constraint(equalToConstant: 300),
            ])
        }

        // MARK: - Actions

        @objc private func playPauseTapped() {
            if playerView.isAnimationPlaying {
                playerView.pause()
            } else {
                playerView.play()
            }
            updateStatusLabel()
            updatePlayPauseButton()
        }

        @objc private func stopTapped() {
            playerView.stop()
            updateStatusLabel()
        }

        @objc private func progressSliderTouchBegan() {
            // Remember if we were playing and pause for scrubbing
            wasPlayingBeforeScrub = playerView.isAnimationPlaying
            if wasPlayingBeforeScrub {
                playerView.pause()
            }
        }

        @objc private func progressChanged() {
            // Update progress while scrubbing
            playerView.currentProgress = CGFloat(progressSlider.value)
            updateStatusLabel()
        }

        @objc private func progressSliderTouchEnded() {
            // Resume playing if we were playing before scrubbing
            if wasPlayingBeforeScrub {
                playerView.play()
                wasPlayingBeforeScrub = false
            }
        }

        @objc private func speedChanged() {
            playerView.animationSpeed = CGFloat(speedSlider.value)
            updateStatusLabel()
        }

        @objc private func loopChanged() {
            playerView.loopMode = loopSwitch.isOn ? .loop : .playOnce
            updateStatusLabel()
        }

        private func updateUI() {
            if !progressSlider.isTracking {
                progressSlider.value = Float(playerView.currentProgress)
            }
            updatePlayPauseButton()
        }

        private func updatePlayPauseButton() {
            let title = playerView.isAnimationPlaying ? "Pause" : "Play"
            playPauseButton.setTitle(title, for: .normal)
        }

        private func updateStatusLabel() {
            let status =
                playerView.isAnimationPlaying
                ? "Playing" : playerView.isAnimationPaused ? "Paused" : "Stopped"

            let info = """
                Status: \(status)
                Frame: \(Int(playerView.currentFrame)) / \(Int(playerView.totalFrames))
                Progress: \(String(format: "%.1f%%", playerView.currentProgress * 100))
                Speed: \(String(format: "%.2fx", playerView.animationSpeed))
                Loop: \(playerView.loopMode == .loop ? "On" : "Off")
                Duration: \(String(format: "%.1fs", playerView.duration))
                """

            statusLabel.text = info
        }
    }

#endif
