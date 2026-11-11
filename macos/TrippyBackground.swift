import AppKit
import MetalKit

private struct BackgroundUniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var motion: Float
    var sprites: SIMD4<UInt32>
}
final class TrippyBackground: MTKView, MTKViewDelegate {
    private var queue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var spriteSheets: [MTLTexture] = []
    private var sprites = SIMD4<UInt32>(1, 9, 11, 7)
    private let started=CACurrentMediaTime()
    var running=false { didSet { updateAnimation() } }
    init(frame: NSRect) {
        let gpu=MTLCreateSystemDefaultDevice()
        super.init(frame:frame,device:gpu)
        colorPixelFormat = .bgra8Unorm
        preferredFramesPerSecond=30;autoResizeDrawable=false
        clearColor=MTLClearColorMake(0.025,0.01,0.065,1)
        isPaused=true;delegate=self
        guard let gpu=gpu else { return };queue=gpu.makeCommandQueue()
        let loader = MTKTextureLoader(device: gpu)
        let fallbackDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false
        )
        guard let fallback = gpu.makeTexture(descriptor: fallbackDescriptor) else { return }
        spriteSheets = ["PickerCamels", "PickerFighter", "PickerInvader", "PickerWhiteCamel", "PickerGoat"].map { name in
            let url = Bundle.main.resourceURL!.appendingPathComponent("Icons/\(name).png")
            return (try? loader.newTexture(URL: url, options: [.origin: MTKTextureLoader.Origin.topLeft, .SRGB: false])) ?? fallback
        }
        do {
            let library=try gpu.makeLibrary(URL:Bundle.main.resourceURL!.appendingPathComponent("Background.metallib"))
            let descriptor=MTLRenderPipelineDescriptor()
            descriptor.vertexFunction=library.makeFunction(name:"minotaurBackgroundVertex")
            descriptor.fragmentFunction=library.makeFunction(name:"minotaurBackgroundFragment")
            descriptor.colorAttachments[0].pixelFormat=colorPixelFormat
            pipeline=try gpu.makeRenderPipelineState(descriptor:descriptor)
        } catch { NSLog("Picker background: %@",error.localizedDescription) }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func shuffleSprites() {
        let choices: [UInt32] = [1, 2, 3, 6, 7, 9, 11]
        var next: SIMD4<UInt32>
        repeat {
            let shuffled = choices.shuffled()
            next = SIMD4(shuffled[0], shuffled[1], shuffled[2], shuffled[3])
        } while next == sprites
        sprites = next
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func layout() {
        super.layout();drawableSize=CGSize(width:max(1,bounds.width*0.85),height:max(1,bounds.height*0.85))
        if running { draw() }
    }
    func updateAnimation() {
        isPaused = !running || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if running { draw() }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard let pipeline=pipeline,let pass=currentRenderPassDescriptor,
              let drawable=currentDrawable,let command=queue?.makeCommandBuffer(),
              let encoder=command.makeRenderCommandEncoder(descriptor:pass) else { return }
        var uniforms = BackgroundUniforms(
            resolution: SIMD2(Float(drawableSize.width), Float(drawableSize.height)),
            time: Float(CACurrentMediaTime() - started),
            motion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 1,
            sprites: sprites
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms,length:MemoryLayout<BackgroundUniforms>.size,index:0)
        for (index, sheet) in spriteSheets.enumerated() {
            encoder.setFragmentTexture(sheet, index: index)
        }
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        encoder.endEncoding();command.present(drawable);command.commit()
    }
}
