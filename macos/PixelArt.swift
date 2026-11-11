import AppKit

// The same literal 5x7 square-cell alphabet as the iPad picker.
private let letters: [[UInt8]] = [[14, 17, 17, 31, 17, 17, 17], [30, 17, 17, 30, 17, 17, 30], [14, 17, 16, 16, 16, 17, 14], [30, 17, 17, 17, 17, 17, 30], [31, 16, 16, 30, 16, 16, 31], [31, 16, 16, 30, 16, 16, 16], [14, 17, 16, 23, 17, 17, 15], [17, 17, 17, 31, 17, 17, 17], [31, 4, 4, 4, 4, 4, 31], [7, 2, 2, 2, 18, 18, 12], [17, 18, 20, 24, 20, 18, 17], [16, 16, 16, 16, 16, 16, 31], [17, 27, 21, 21, 17, 17, 17], [17, 25, 21, 19, 17, 17, 17], [14, 17, 17, 17, 17, 17, 14], [30, 17, 17, 30, 16, 16, 16], [14, 17, 17, 17, 21, 18, 13], [30, 17, 17, 30, 20, 18, 17], [15, 16, 16, 14, 1, 1, 30], [31, 4, 4, 4, 4, 4, 4], [17, 17, 17, 17, 17, 17, 14], [17, 17, 17, 17, 17, 10, 4], [17, 17, 17, 21, 21, 21, 10], [17, 17, 10, 4, 10, 17, 17], [17, 17, 10, 4, 4, 4, 4], [31, 1, 2, 4, 8, 16, 31]]
private let digits: [[UInt8]] = [[14, 17, 19, 21, 25, 17, 14], [4, 12, 4, 4, 4, 4, 14], [14, 17, 1, 2, 4, 8, 31], [30, 1, 1, 14, 1, 1, 30], [2, 6, 10, 18, 31, 2, 2], [31, 16, 16, 30, 1, 1, 30], [14, 16, 16, 30, 17, 17, 14], [31, 1, 2, 4, 8, 8, 8], [14, 17, 17, 14, 17, 17, 14], [14, 17, 17, 15, 1, 1, 14]]

func pixelGlyph(_ character: Character) -> [UInt8] {
    guard let c=String(character).uppercased().utf8.first else { return Array(repeating:0,count:7) }
    if c>=65 && c<=90 { return letters[Int(c-65)] }
    if c>=48 && c<=57 { return digits[Int(c-48)] }
    if c==45 { return [0,0,0,31,0,0,0] }
    if c==33 { return [4,4,4,4,4,0,4] }
    return Array(repeating:0,count:7)
}
func pixelWidth(_ text: String, _ pixel: CGFloat) -> CGFloat { CGFloat(max(0,text.count*6-1))*pixel }
func drawPixels(_ text: String, at origin: CGPoint, pixel: CGFloat, colour: NSColor, in context: CGContext) {
    context.saveGState();context.setShouldAntialias(false);context.setFillColor(colour.cgColor)
    for (i,c) in text.enumerated() {
        let rows=pixelGlyph(c)
        for y in 0..<7 { for x in 0..<5 where rows[y] & UInt8(1 << (4-x)) != 0 {
            context.fill(CGRect(x:origin.x+CGFloat(i*6+x)*pixel,y:origin.y+CGFloat(y)*pixel,width:pixel,height:pixel))
        } }
    }
    context.restoreGState()
}
func spectrum(_ hue: CGFloat, alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedHue:hue-floor(hue),saturation:0.82,brightness:1,alpha:alpha)
}
/// Snap the columns horizontally and blend the first and last display rows
/// of each vertical run. This keeps the square cells solid during a wave.
private func drawMovingGlyph(_ character: Character, at origin: CGPoint, pixel: CGFloat,
                             colour: NSColor, in context: CGContext) {
    let rows = pixelGlyph(character)
    context.saveGState()
    context.setFillColor(colour.cgColor)
    func fill(_ rect: CGRect, coverage: CGFloat) {
        guard rect.width > 0, rect.height > 0, coverage > 0 else { return }
        context.setAlpha(coverage)
        context.fill(context.convertToUserSpace(rect))
    }

    for column in 0..<5 {
        var start: Int?
        for row in 0...7 {
            let lit = row < 7 && rows[row] & UInt8(1 << (4 - column)) != 0
            if lit {
                if start == nil { start = row }
            } else if let first = start {
                let rect = context.convertToDeviceSpace(CGRect(
                    x: origin.x + CGFloat(column) * pixel, y: origin.y + CGFloat(first) * pixel,
                    width: pixel, height: CGFloat(row - first) * pixel))
                let left = round(rect.minX)
                let width = round(rect.maxX) - left
                let low = floor(rect.minY)
                let high = floor(rect.maxY)
                if low == high {
                    fill(CGRect(x: left, y: low, width: width, height: 1), coverage: rect.height)
                } else {
                    fill(CGRect(x: left, y: low, width: width, height: 1), coverage: low + 1 - rect.minY)
                    fill(CGRect(x: left, y: low + 1, width: width, height: high - low - 1), coverage: 1)
                    fill(CGRect(x: left, y: high, width: width, height: 1), coverage: rect.maxY - high)
                }
                start = nil
            }
        }
    }
    context.restoreGState()
}

final class BlingTitle: NSView {
    override var isFlipped: Bool { true }
    private let started=CACurrentMediaTime()
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(false)
        let still=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let t: CGFloat=still ? 2.5 : CGFloat(CACurrentMediaTime()-started)
        let word="MINOTAUR",mid=bounds.midX,pixel=max(4,min(10,floor((bounds.width-80)/47)))
        let wordWidth=pixelWidth(word,pixel),left=round(mid-wordWidth/2)
        for (i,c) in word.enumerated() {
            let n=CGFloat(i),letter=String(c),rows=pixelGlyph(c)
            let x=left+n*6*pixel+(still ? 0 : 3*sin(t*0.75)+2*sin(t*1.5-n*0.35))
            let y: CGFloat=24+(still ? 0 : 16*sin(t*2.7-n*0.82)+4.5*sin(t*4.05+n*0.58)+3.5*sin(t*1.15))
            drawPixels(letter,at:CGPoint(x:x+3,y:y+4),pixel:pixel,colour:NSColor(white:0,alpha:0.88),in:context)
            if !still { for echo in stride(from:2,through:1,by:-1) {
                let lag=t-CGFloat(echo)*0.11
                let tx=left+n*6*pixel+3*sin(lag*0.75)+2*sin(lag*1.5-n*0.35)
                let ty: CGFloat=24+16*sin(lag*2.7-n*0.82)+4.5*sin(lag*4.05+n*0.58)+3.5*sin(lag*1.15)
                drawPixels(letter,at:CGPoint(x:tx,y:ty),pixel:pixel,colour:spectrum(n*0.1+t*0.055+CGFloat(echo)*0.17,alpha:echo==1 ? 0.25 : 0.12),in:context)
            } }
            for row in 0..<7 {
                context.setFillColor(spectrum(CGFloat(row)/8+n*0.025+t*0.055).cgColor)
                for col in 0..<5 where rows[row] & UInt8(1 << (4-col)) != 0 {
                    context.fill(CGRect(x:x+CGFloat(col)*pixel,y:y+CGFloat(row)*pixel,width:pixel,height:pixel))
                }
            }
        }
        let project = "PROJECT"
        let projectPixel = min(5, pixel)
        let projectWidth = CGFloat(project.count * 7 - 2) * projectPixel
        let projectLeft = round(mid - projectWidth / 2)
        for (index, character) in project.enumerated() {
            let i = CGFloat(index)
            let x = projectLeft + i * 7 * projectPixel
            let y = 125 + (still ? 0 : 3 * sin(t * 1.85 - i * 0.52 + 1.5))
            let hue = 0.51 + 0.045 * i + (still ? 0 : 0.04 * sin(t * 1.5))
            let ink = NSColor(calibratedHue: hue, saturation: 0.42, brightness: 1, alpha: 1)
            drawMovingGlyph(character, at: CGPoint(x: x + 2, y: y + 3), pixel: projectPixel,
                            colour: NSColor(white: 0, alpha: 0.88), in: context)
            drawMovingGlyph(character, at: CGPoint(x: x, y: y), pixel: projectPixel,
                            colour: ink, in: context)
        }
        for i in 0..<6 {
            let n=CGFloat(i),side: CGFloat=i<3 ? -1 : 1
            let x=mid+side*(wordWidth/2+22+CGFloat(i%3)*16)+3*sin(t*1.1+n)
            let y: CGFloat=62+15*sin(t*1.8+n*0.9)
            if x<8 || x>bounds.width-8 { continue }
            context.setFillColor(spectrum(n/6+t*0.04,alpha:0.9).cgColor)
            context.fill(CGRect(x:x-2,y:y-6,width:4,height:12));context.fill(CGRect(x:x-6,y:y-2,width:12,height:4))
        }
        let span=min(bounds.width-40,wordWidth+70)
        for band in 0..<3 { for i in 0..<Int(span/3) {
            let n=CGFloat(i),b=CGFloat(band),x=mid-span/2+n*3
            let y: CGFloat=170+2.5*sin(n*0.12-t*(2+b*0.22)+b*2.1)+sin(n*0.06+t*0.8)
            context.setFillColor(spectrum(b/3+n/(span/3)*0.3+t*0.045,alpha:0.8).cgColor)
            context.fill(CGRect(x:x,y:y,width:3,height:1.5))
        } }
    }
}
