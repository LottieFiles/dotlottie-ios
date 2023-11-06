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
    
    func setBackgroundColor(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        tvg_shape_set_fill_color(self.bg, r, g, b, a);
    }
    
    /// Loads the animation data passed as a string (JSON content of a Lottie animation) - Returns false on failure
    func loadAnimation(animationData: String, width: UInt32, height: UInt32, direction: Int = 1) -> Bool {
        self.WIDTH = width;
        self.HEIGHT = height;
        
        self.animationData = animationData
        
        self.buffer = [UInt32](repeating: 0, count: Int(width) * Int(height));
        
        self.direction = direction
        
        _ = self.buffer.withUnsafeMutableBufferPointer{ bufferPointer in
            tvg_swcanvas_set_target(self.canvas, bufferPointer.baseAddress, width, width, height, TVG_COLORSPACE_ABGR8888);
        }
        
        //clear the canvas
        tvg_canvas_clear(self.canvas, false);
        
        //reset the bg region
        tvg_shape_reset(self.bg);
        tvg_shape_append_rect(self.bg, 0, 0, Float32(width), Float32(height), 0, 0);
        
        tvg_canvas_push(self.canvas, self.bg);
        
        let frame_image = tvg_animation_get_picture(self.animation);
        
        var load_result: Tvg_Result = TVG_RESULT_UNKNOWN;
        
        if let c_string = self.animationData.cString(using: .utf8) {
            c_string.withUnsafeBufferPointer{ bufferPointer in
                load_result = tvg_picture_load_data(frame_image, bufferPointer.baseAddress, numericCast(strlen(animationData)), "lottie", false);
            }
        }
        
        if (load_result != TVG_RESULT_SUCCESS) {
            tvg_animation_del(self.animation)
            
            print("ERROR LOADING ANIMATION")
            
            return false
        } else {
            tvg_animation_get_total_frame(self.animation, self.totalFramesState);
            tvg_animation_get_duration(self.animation, self.durationState);
            tvg_animation_set_frame(animation, direction == 1 ? 0.0 : self.totalFramesState.pointee - 1);
            
            tvg_canvas_push(self.canvas, frame_image);
            tvg_canvas_draw(self.canvas);
            tvg_canvas_sync(self.canvas);
        }
        
        return true
    }
    
    // Goes to the frame passed as argument
    //    func setFrame(frame: Float32) {
    //        if frame >= 0 && currentFrameState.pointee <= totalFramesState.pointee - 1.0 {
    //            currentFrameState.pointee = frame;
    //        }
    //
    //        tvg_animation_set_frame(animation, currentFrameState.pointee);
    //
    //        tvg_canvas_update_paint(canvas, tvg_animation_get_picture(animation));
    //
    //        //Draw the canvas
    //        tvg_canvas_draw(canvas);
    //        tvg_canvas_sync(canvas);
    //    }
    
    func currentFrame() -> Float32 {
        tvg_animation_get_frame(animation, currentFrameState);
        
        return currentFrameState.pointee
    }
    
    func frame(no: Float32) {
        if no >= 0 && currentFrameState.pointee <= totalFramesState.pointee - 1.0 {
            currentFrameState.pointee = no;
            tvg_animation_set_frame(animation, no);
    
            tvg_canvas_update_paint(canvas, tvg_animation_get_picture(animation));
            tvg_canvas_draw(canvas);
            tvg_canvas_sync(canvas);
        } else {
            print("NOT Setting frame..")
        }
    }
    
    func totalFrame() -> Float32 {
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
    
    /// Advance the animation by one frame depending on the current direction.
    func tick() {
        tvg_animation_get_frame(animation, currentFrameState);
        
        if _direction == 1  {
            if currentFrameState.pointee > 0 && currentFrameState.pointee >= totalFramesState.pointee - 1.0 {
                currentFrameState.pointee = 0.0;
            } else {
                currentFrameState.pointee += 1.0;
            }
        } else if _direction == -1 {
            if currentFrameState.pointee <= 0 {
                currentFrameState.pointee = totalFramesState.pointee - 1.0;
            } else {
                currentFrameState.pointee -= 1.0;
            }
        }
        
        self.draw()
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
