import MetalKit
import QuartzCore
import SwiftUI

struct BlackHoleOverlayView: View {
    private static let sharedDevice = MTLCreateSystemDefaultDevice()

    let overlay: MySkyBlackHoleCoordinator.OverlayParameters

    var body: some View {
        if let device = Self.sharedDevice {
            BlackHoleOverlayMetalView(device: device)
                .opacity(Double(max(0, min(1, overlay.opacity * 0.82))))
                .overlay {
                    if overlay.flashProgress > 0 {
                        Color.white.opacity(Double(max(0, min(1, overlay.flashProgress))))
                    }
                }
                .allowsHitTesting(false)
        } else {
            EmptyView()
        }
    }
}

private struct BlackHoleOverlayMetalView: UIViewRepresentable {
    let device: MTLDevice

    func makeCoordinator() -> Coordinator {
        Coordinator(device: device)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: device)
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.autoResizeDrawable = true
        view.isPaused = false
        view.preferredFramesPerSecond = 24
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.delegate = context.coordinator.renderer
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    final class Coordinator {
        let renderer: BlackHoleOverlayRenderer

        init(device: MTLDevice) {
            renderer = BlackHoleOverlayRenderer(device: device)
        }
    }
}

private struct SingularityUniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var padding: Float = 0
}

private final class BlackHoleOverlayRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let startTime: CFTimeInterval

    init(device: MTLDevice) {
        guard
            let commandQueue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let vertex = library.makeFunction(name: "singularityFullscreenVertex"),
            let fragment = library.makeFunction(name: "singularityFragment")
        else {
            fatalError("Failed to create black hole overlay shader resources")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "BlackHoleOverlayPipeline"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].alphaBlendOperation = .add

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            fatalError("Failed to create black hole overlay pipeline state")
        }

        self.commandQueue = commandQueue
        self.pipeline = pipeline
        self.startTime = CACurrentMediaTime()

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        var uniforms = SingularityUniforms(
            resolution: SIMD2(
                Float(max(view.drawableSize.width, 1)),
                Float(max(view.drawableSize.height, 1))
            ),
            time: Float(CACurrentMediaTime() - startTime)
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SingularityUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
