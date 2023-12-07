//
//  DotLottieCore.swift
//  DotLottieIos
//
//  Created by Sam on 18/10/2023.
//

import Foundation
import CoreGraphics
import SwiftUI
import Thorvg

enum ThorvgOperationFailure : Error {
    case operationFailed(description: String)
}

/// MARK: - DotLottieRenderer

/// The 'DotLottieRenderer' class wraps Thorvg and manages loading and rendering frames of animations.
class Thorvg {
    private var buffer: [UInt32] = []
    private var animation: OpaquePointer;
    private var canvas: OpaquePointer;
    private var bg: OpaquePointer;
    
    private var currentFrameState: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
    private var totalFramesState: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
    private var durationState: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
    
    var WIDTH: UInt32 = 0;
    var HEIGHT: UInt32 = 0;
    var animationData: String = "";
    
    // Private backing variable
    private var _direction: Int = 1
    
    // Public computed property for direction
    var direction: Int {
        get {
            return _direction
        }
        set {
            if newValue == 1 || newValue == -1 {
                _direction = newValue
            } else {
                print("Invalid direction value. Setting to default (1).")
                _direction = 1
            }
        }
    }
    
    init() {
        tvg_engine_init(TVG_ENGINE_SW, 0);
        
        self.animation = tvg_animation_new();
        self.canvas = tvg_swcanvas_create();
        self.totalFramesState.pointee = 0;
        self.currentFrameState.pointee = 0;
        self.bg = tvg_shape_new();
    }
    
    private func executeThorvgOperation(_ operation: () -> Tvg_Result, description: String) throws {
        let result = operation()
        
        guard result == TVG_RESULT_SUCCESS else {
            let errorDescription = "Thorvg operation failed: \(description). Error code: \(result)"
            throw ThorvgOperationFailure.operationFailed(description: errorDescription)
        }
    }

    /// Loads the animation data passed as a string (JSON content of a Lottie animation) - Returns false on failure
    func loadAnimation(animationData: String, width: Int, height: Int, direction: Int = 1) throws {
        self.WIDTH = UInt32(width);
        self.HEIGHT = UInt32(height);
        
        self.animationData = animationData
        
        self.buffer = [UInt32](repeating: 0, count: Int(width) * Int(height));
        
        self.direction = direction
        
        try self.buffer.withUnsafeMutableBufferPointer { bufferPointer in
            if (tvg_swcanvas_set_target(self.canvas, bufferPointer.baseAddress, self.WIDTH, self.WIDTH, self.HEIGHT, TVG_COLORSPACE_ABGR8888) != TVG_RESULT_SUCCESS) {
                throw ThorvgOperationFailure.operationFailed(description: "Set Target")
            }
        }
        
        do {
            try executeThorvgOperation( { tvg_canvas_clear(self.canvas, false, true) }, description: "Clear canvas" )
            
            try executeThorvgOperation( { tvg_shape_reset(self.bg) }, description: "Shape reset" )
            
            //reset the bg region
            try executeThorvgOperation( { tvg_shape_append_rect(self.bg, 0, 0, Float32(width), Float32(height), 0, 0) }, description: "Shape Append Rect" )
            
            try executeThorvgOperation( { tvg_canvas_push(self.canvas, self.bg) }, description: "Canvas Push" )
            
        } catch let error as ThorvgOperationFailure {
            throw error
        }
        
        let frame_image = tvg_animation_get_picture(self.animation);
        
        var load_result: Tvg_Result = TVG_RESULT_UNKNOWN;
        
        if let c_string = self.animationData.cString(using: .utf8) {
            c_string.withUnsafeBufferPointer{ bufferPointer in
                
                load_result = tvg_picture_load_data(frame_image, bufferPointer.baseAddress, numericCast(strlen(animationData)), "lottie", "", false)
            }
        }
        
        guard load_result == TVG_RESULT_SUCCESS else {
            tvg_animation_del(self.animation)
            
            throw ThorvgOperationFailure.operationFailed(description: "Picture Load Data")
        }
        
        do {
            //resize the animation with the given aspect ratio.
            let w: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
            let h: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
            
            try executeThorvgOperation( { tvg_picture_get_size(frame_image, w, h) }, description: "Get size")
            let scale = (Float32(width) / w.pointee)
            
            try executeThorvgOperation( { tvg_picture_set_size(frame_image, w.pointee * scale, h.pointee * scale) }, description: "Aspect ratio Set size")
            
            try executeThorvgOperation({ tvg_animation_get_total_frame(self.animation, self.totalFramesState) }, description: "Get Total Frame")
            
            try executeThorvgOperation({ tvg_animation_get_duration(self.animation, self.durationState) }, description: "Get Duration")
            
            try executeThorvgOperation({ tvg_canvas_push(self.canvas, frame_image) }, description: "Canvas Push")
            
            try executeThorvgOperation({ tvg_canvas_draw(self.canvas) }, description: "Canvas Draw")
            
            try executeThorvgOperation({ tvg_canvas_sync(self.canvas) }, description: "Canvas Sync")
        } catch let error as ThorvgOperationFailure {
            throw error
        }
    }
    
    /// Loads the animation from a disk path - Returns false on failure
    func loadAnimation(path: String, width: UInt32, height: UInt32, direction: Int = 1) throws {
        self.WIDTH = width;
        self.HEIGHT = height;
        
        //        self.animationData = animationData
        
        self.buffer = [UInt32](repeating: 0, count: Int(width) * Int(height));
        
        self.direction = direction
        
        try self.buffer.withUnsafeMutableBufferPointer { bufferPointer in
            if (tvg_swcanvas_set_target(self.canvas, bufferPointer.baseAddress, width, width, height, TVG_COLORSPACE_ABGR8888) != TVG_RESULT_SUCCESS) {
                throw ThorvgOperationFailure.operationFailed(description: "Set Target")
            }
        }
        
        do {
            try executeThorvgOperation( { tvg_canvas_clear(self.canvas, false, true) }, description: "Clear canvas" )
            
            try executeThorvgOperation( { tvg_shape_reset(self.bg) }, description: "Shape reset" )
            
            //reset the bg region
            try executeThorvgOperation( { tvg_shape_append_rect(self.bg, 0, 0, Float32(width), Float32(height), 0, 0) }, description: "Shape Append Rect" )
            
            try executeThorvgOperation( { tvg_canvas_push(self.canvas, self.bg) }, description: "Canvas Push" )
            
        } catch let error as ThorvgOperationFailure {
            throw error
        }
        
        let frame_image = tvg_animation_get_picture(self.animation);
        
        var load_result: Tvg_Result = TVG_RESULT_UNKNOWN;
        
        if let c_string = self.animationData.cString(using: .utf8) {
            c_string.withUnsafeBufferPointer{ bufferPointer in
                load_result = tvg_picture_load(frame_image, path)
            }
        }
        
        guard load_result == TVG_RESULT_SUCCESS else {
            tvg_animation_del(self.animation)
            
            throw ThorvgOperationFailure.operationFailed(description: "Picture Load Data")
        }
        
        do {
            //resize the animation with the given aspect ratio.
            let w: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
            let h: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
            
            try executeThorvgOperation( { tvg_picture_get_size(frame_image, w, h) }, description: "Get size")
            let scale = (Float32(width) / w.pointee)
            
            try executeThorvgOperation( { tvg_picture_set_size(frame_image, w.pointee * scale, h.pointee * scale) }, description: "Aspect ratio Set size")
            
            try executeThorvgOperation({ tvg_animation_get_total_frame(self.animation, self.totalFramesState) }, description: "Get Total Frame")
            
            try executeThorvgOperation({ tvg_animation_get_duration(self.animation, self.durationState) }, description: "Get Duration")
            
            try executeThorvgOperation({ tvg_canvas_push(self.canvas, frame_image) }, description: "Canvas Push")
            
            try executeThorvgOperation({ tvg_canvas_draw(self.canvas) }, description: "Canvas Draw")
            
            try executeThorvgOperation({ tvg_canvas_sync(self.canvas) }, description: "Canvas Sync")
        } catch let error as ThorvgOperationFailure {
            throw error
        }
    }
    
    func currentFrame() -> Float32 {
        return currentFrameState.pointee
    }
    
    func clear() throws {
        try executeThorvgOperation( { tvg_canvas_clear(self.canvas, false, true) }, description: "Clear canvas" )
    }
    
    func frame(no: Float32) throws {
        if no >= 0.0 && no <= totalFramesState.pointee - 1.0 {
            currentFrameState.pointee = no;
            try self.clear()
            try self.draw()
        } else {
            print("Frame: \(no) is outside of frame limits for this animation.")
        }
    }
    
    func totalFrames() -> Float32 {
        return totalFramesState.pointee
    }
    
    func duration() -> Float32 {
        return durationState.pointee
    }
    
    func draw() {
        tvg_animation_set_frame(animation, currentFrameState.pointee);
        tvg_canvas_update_paint(canvas, tvg_animation_get_picture(animation));
        tvg_canvas_draw(canvas);
        tvg_canvas_sync(canvas);
    }
    
    /// Returns the current frame as a CGImage
    func render() -> CGImage? {
        let bitsPerComponent = 8
        let bytesPerRow = 4 * WIDTH
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        if let context = CGContext(data: &buffer, width: Int(WIDTH), height: Int(HEIGHT), bitsPerComponent: bitsPerComponent, bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            if let newImage = context.makeImage() {
                return newImage
            }
        }
        
        return nil
    }
}
