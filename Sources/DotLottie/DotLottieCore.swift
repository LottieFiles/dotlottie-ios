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

class DotLottieCore {
    var buffer: [UInt32] = []
    var animation: OpaquePointer;
    var canvas: OpaquePointer;
    var currentFrame: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
    var totalFrames: UnsafeMutablePointer<Float32> = UnsafeMutablePointer<Float32>.allocate(capacity: 1);
    var WIDTH: UInt32 = 0;
    var HEIGHT: UInt32 = 0;
    var animationData: String = "";
    var direction = 1;
    
    init() {
        tvg_engine_init(TVG_ENGINE_SW, 0);
        
        self.animation = tvg_animation_new();
        self.canvas = tvg_swcanvas_create();
        self.totalFrames.pointee = 0;
        self.currentFrame.pointee = 0;
    }
    
    func load_animation(animation_data: String, width: UInt32, height: UInt32, direction: Int = 1) {
        self.WIDTH = width;
        self.HEIGHT = height;
        
        self.animationData = animation_data
        
        self.buffer = [UInt32](repeating: 0, count: Int(width) * Int(height));
        
        self.direction = direction
        
        _ = self.buffer.withUnsafeMutableBufferPointer{ bufferPointer in
            tvg_swcanvas_set_target(self.canvas, bufferPointer.baseAddress, width, width, height, TVG_COLORSPACE_ABGR8888);
        }
        
        let frame_image = tvg_animation_get_picture(self.animation);
        
        var load_result: Tvg_Result = TVG_RESULT_UNKNOWN;
        
        if let c_string = self.animationData.cString(using: .utf8) {
            c_string.withUnsafeBufferPointer{ bufferPointer in
                load_result = tvg_picture_load_data(frame_image, bufferPointer.baseAddress, numericCast(strlen(animation_data)), "lottie", false);
            }
        }

        if (load_result != TVG_RESULT_SUCCESS ) {
            tvg_animation_del(self.animation)
        } else {
            tvg_paint_scale(frame_image, 1.0);
            
            tvg_animation_get_total_frame(self.animation, self.totalFrames);
            
            tvg_animation_set_frame(animation, direction == 1 ? 0.0 : self.totalFrames.pointee - 1);
            tvg_canvas_push(self.canvas, frame_image);
            tvg_canvas_draw(self.canvas);
            tvg_canvas_sync(self.canvas);
        }
    }
    
    func tick() {
        tvg_animation_get_frame(animation, currentFrame);
        
        if direction == 1  {
            if currentFrame.pointee > 0 && currentFrame.pointee >= totalFrames.pointee - 1.0 {
                currentFrame.pointee = 0.0;
            } else {
                currentFrame.pointee += 1.0;
            }
        } else if direction == -1 {
            if currentFrame.pointee <= 0 {
                currentFrame.pointee = totalFrames.pointee - 1.0;
            } else {
                currentFrame.pointee -= 1.0;
            }
        }
        
        tvg_animation_set_frame(animation, currentFrame.pointee);

        tvg_canvas_update_paint(canvas, tvg_animation_get_picture(animation));

        //Draw the canvas
        tvg_canvas_draw(canvas);
        tvg_canvas_sync(canvas);
    }
    
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
