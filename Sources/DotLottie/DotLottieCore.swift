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

public class DotLottieCore {
    var buffer: [UInt32] = []
    var animation: OpaquePointer;
    var canvas: OpaquePointer;
    var current_frame: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 1);
    var total_frames: UnsafeMutablePointer<UInt32> = UnsafeMutablePointer<UInt32>.allocate(capacity: 1);
    var WIDTH: UInt32 = 0;
    var HEIGHT: UInt32 = 0;
    @Published var paused = false;
    
    init() {
        tvg_engine_init(TVG_ENGINE_SW, 0);
        
        self.animation = tvg_animation_new();
        self.canvas = tvg_swcanvas_create();
        self.total_frames.pointee = 0;
        self.current_frame.pointee = 0;
    }
    
    func load_animation(animation_data: String, width: UInt32, height: UInt32) {
        self.WIDTH = width;
        self.HEIGHT = height;
        
        self.buffer  = [UInt32](repeating: 0, count: Int(width) * Int(height));
        
        self.buffer.withUnsafeMutableBufferPointer{ bufferPointer in
            tvg_swcanvas_set_target(self.canvas, bufferPointer.baseAddress, width, width, height, TVG_COLORSPACE_ABGR8888);
        }
        
        let frame_image = tvg_animation_get_picture(self.animation);
        
        var load_result: Tvg_Result = TVG_RESULT_UNKNOWN;
        
       if let c_string = animation_data.cString(using: .utf8) {
            let unsafePointer = UnsafePointer<CChar>(c_string)
            
            load_result = tvg_picture_load_data(frame_image, unsafePointer, numericCast(strlen(animation_data)), "lottie", false);
        }

        if (load_result != TVG_RESULT_SUCCESS ) {
            tvg_animation_del(self.animation)
        } else {
            tvg_paint_scale(frame_image, 1.0);
            
            tvg_animation_get_total_frame(self.animation, self.total_frames);
            
            tvg_animation_set_frame(animation, 0);
            tvg_canvas_push(self.canvas, frame_image);
            tvg_canvas_draw(self.canvas);
            tvg_canvas_sync(self.canvas);
        }
    }
    
    func tick() {
        if (self.paused) {
            return ;
        }
        
        tvg_animation_get_frame(animation, current_frame);

        // todo add direction -1
        if total_frames.pointee > 0 && current_frame.pointee >= total_frames.pointee - 1 {
            current_frame.pointee = 0;
        } else {
            current_frame.pointee += 1;
        }
        
        tvg_animation_set_frame(animation, current_frame.pointee);

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
