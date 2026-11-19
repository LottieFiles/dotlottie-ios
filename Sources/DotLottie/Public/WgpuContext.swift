//
//  WgpuContext.swift
//  DotLottie
//
//  Swift-side WebGPU context creation (Metal backend).
//
//  Creating an instance/adapter/device/surface from a CAMetalLayer is a platform
//  concern, so it lives here and calls wgpu-native (the shared `WgpuNative`
//  framework) directly — replacing the former Rust
//  `dotlottie_create_wgpu_context_from_metal_layer` wrapper. The resulting
//  pointers are handed to `DotLottiePlayer.setWebGPUTarget`, which is the only
//  WebGPU boundary the Rust runtime still exposes.
//
//  Not available on Mac Catalyst (wgpu is linked statically there) or on
//  tvOS/watchOS/visionOS (software renderer only).
//

#if canImport(WgpuNative) && ((os(iOS) && !targetEnvironment(macCatalyst)) || os(macOS))

import Foundation
import QuartzCore
import WgpuNative

/// Owns a WebGPU instance/adapter/device/queue/surface bound to a `CAMetalLayer`.
final class WgpuContext {

    private let instance: OpaquePointer
    private let adapter: OpaquePointer
    private let device: OpaquePointer
    private let queue: OpaquePointer
    private let surface: OpaquePointer

    /// Raw pointers for `DotLottiePlayer.setWebGPUTarget(device:instance:target:…)`.
    var devicePtr: UnsafeMutableRawPointer { UnsafeMutableRawPointer(device) }
    var instancePtr: UnsafeMutableRawPointer { UnsafeMutableRawPointer(instance) }
    var surfacePtr: UnsafeMutableRawPointer { UnsafeMutableRawPointer(surface) }

    /// Create a context from a `CAMetalLayer`.
    ///
    /// **Must be called on the main thread** — Metal requires it. Returns `nil`
    /// if any stage of WebGPU initialisation fails.
    init?(metalLayer: CAMetalLayer) {
        // --- Instance ---
        var instanceDesc = WGPUInstanceDescriptor()
        guard let instance = wgpuCreateInstance(&instanceDesc) else {
            return nil
        }

        // --- Surface from the CAMetalLayer ---
        var metalSource = WGPUSurfaceSourceMetalLayer()
        metalSource.chain.next = nil
        metalSource.chain.sType = WGPUSType_SurfaceSourceMetalLayer
        metalSource.layer = Unmanaged.passUnretained(metalLayer).toOpaque()

        let createdSurface: OpaquePointer? = withUnsafeMutablePointer(to: &metalSource.chain) { chainPtr in
            var surfaceDesc = WGPUSurfaceDescriptor()
            surfaceDesc.nextInChain = chainPtr
            surfaceDesc.label = WGPUStringView(data: nil, length: 0)
            return wgpuInstanceCreateSurface(instance, &surfaceDesc)
        }
        guard let surface = createdSurface else {
            wgpuInstanceRelease(instance)
            return nil
        }

        // --- Adapter (synchronous) ---
        guard let adapter = WgpuContext.requestAdapter(instance: instance, surface: surface) else {
            wgpuSurfaceRelease(surface)
            wgpuInstanceRelease(instance)
            return nil
        }

        // --- Device (synchronous) ---
        guard let device = WgpuContext.requestDevice(adapter: adapter) else {
            wgpuAdapterRelease(adapter)
            wgpuSurfaceRelease(surface)
            wgpuInstanceRelease(instance)
            return nil
        }

        // --- Queue ---
        guard let queue = wgpuDeviceGetQueue(device) else {
            wgpuDeviceRelease(device)
            wgpuAdapterRelease(adapter)
            wgpuSurfaceRelease(surface)
            wgpuInstanceRelease(instance)
            return nil
        }

        // Surface configuration is handled by ThorVG's wg engine; we hand it the
        // unconfigured surface, device, and instance.
        self.instance = instance
        self.adapter = adapter
        self.device = device
        self.queue = queue
        self.surface = surface
    }

    /// Block until all submitted GPU work has completed.
    ///
    /// Call before reconfiguring the surface (resize) or tearing the context down,
    /// so wgpu-native does not recycle/free a "(wgpu internal) Staging" buffer that
    /// a still-pending "(wgpu internal) Signal" command buffer references — which
    /// trips Metal's `notifyExternalReferencesNonZeroOnDealloc` assertion.
    func waitUntilIdle() {
        // wait = true: poll the device and block until the queue is drained.
        _ = wgpuDevicePoll(device, 1, nil)
    }

    /// Present the rendered frame to the screen. Call once per rendered frame;
    /// without it the frame stays off-screen.
    func present() {
        let status = wgpuSurfacePresent(surface)
        if status != WGPUStatus_Success {
            print("[WgpuContext] wgpuSurfacePresent failed: \(status.rawValue)")
        }
    }

    deinit {
        // Non-blocking poll: process already-completed submissions without creating
        // new Signal command buffers, then release in reverse creation order.
        wgpuDevicePoll(device, 0, nil)
        wgpuQueueRelease(queue)
        wgpuDeviceRelease(device)
        wgpuAdapterRelease(adapter)
        wgpuSurfaceRelease(surface)
        wgpuInstanceRelease(instance)
    }

    // MARK: - Synchronous adapter / device requests

    private final class AdapterBox {
        var adapter: OpaquePointer?
        let sem = DispatchSemaphore(value: 0)
    }

    private static func requestAdapter(instance: OpaquePointer, surface: OpaquePointer) -> OpaquePointer? {
        let box = AdapterBox()

        var options = WGPURequestAdapterOptions()
        options.featureLevel = WGPUFeatureLevel_Core
        options.powerPreference = WGPUPowerPreference_HighPerformance
        options.forceFallbackAdapter = 0
        options.backendType = WGPUBackendType_Metal
        options.compatibleSurface = surface

        var callbackInfo = WGPURequestAdapterCallbackInfo()
        callbackInfo.mode = WGPUCallbackMode_AllowSpontaneous
        callbackInfo.callback = { status, adapter, _, userdata1, _ in
            guard let userdata1 = userdata1 else { return }
            let box = Unmanaged<AdapterBox>.fromOpaque(userdata1).takeUnretainedValue()
            if status == WGPURequestAdapterStatus_Success {
                box.adapter = adapter
            }
            box.sem.signal()
        }
        callbackInfo.userdata1 = Unmanaged.passUnretained(box).toOpaque()

        _ = wgpuInstanceRequestAdapter(instance, &options, callbackInfo)

        // Metal initialization can be slow on first launch — allow up to 10 seconds.
        if box.sem.wait(timeout: .now() + 10) == .timedOut {
            print("[WgpuContext] adapter request timed out after 10s")
            return nil
        }
        return box.adapter
    }

    private static func requestDevice(adapter: OpaquePointer) -> OpaquePointer? {
        let box = DeviceBox()
        // wgpu-native v25 does not forward `userdata1` for the device-request
        // callback, so the result is passed via a file-private global. Context
        // creation is serialised on the main thread, so a single global is safe.
        wgpuPendingDeviceBox = box
        defer { wgpuPendingDeviceBox = nil }

        var deviceDesc = WGPUDeviceDescriptor()
        deviceDesc.deviceLostCallbackInfo.mode = WGPUCallbackMode_AllowSpontaneous

        var callbackInfo = WGPURequestDeviceCallbackInfo()
        callbackInfo.mode = WGPUCallbackMode_AllowSpontaneous
        callbackInfo.callback = { status, device, _, _, _ in
            guard let box = wgpuPendingDeviceBox else { return }
            if status == WGPURequestDeviceStatus_Success {
                box.device = device
            }
            box.sem.signal()
        }

        _ = wgpuAdapterRequestDevice(adapter, &deviceDesc, callbackInfo)

        if box.sem.wait(timeout: .now() + 10) == .timedOut {
            print("[WgpuContext] device request timed out after 10s")
            return nil
        }
        return box.device
    }
}

/// Result holder for the device-request callback (see `requestDevice`).
private final class DeviceBox {
    var device: OpaquePointer?
    let sem = DispatchSemaphore(value: 0)
}

/// Set immediately before `wgpuAdapterRequestDevice` and cleared right after,
/// because wgpu-native v25 drops the callback's `userdata1`.
private var wgpuPendingDeviceBox: DeviceBox?

#endif
