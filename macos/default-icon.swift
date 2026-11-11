import AppKit
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
NSColor.black.setFill();NSRect(x:0,y:0,width:1024,height:1024).fill()
let rows=[17,27,21,21,17,17,17]
for y in 0..<7 { NSColor(calibratedHue:CGFloat(y)/7,saturation:0.9,brightness:1,alpha:1).setFill()
    for x in 0..<5 where rows[y] & (1 << (4-x)) != 0 { NSRect(x:182+x*132,y:908-(y+1)*116,width:132,height:116).fill() }
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
