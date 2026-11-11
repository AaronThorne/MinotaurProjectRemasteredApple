import AppKit

let games=[("Gridrunner","Gridrunner"),("SuperOxWars","Super Ox Wars"),("Minotron2112","Minotron 2112"),("MinotaurRescue","Minotaur Rescue"),("FiveADay","Five A Day"),("Deflex","Deflex"),("CavernsOfMinos","Caverns of Minos"),("GoatUp","Goat Up"),("GoatUp2","Goat Up 2")]

final class GameTile: NSButton {
    var artwork: NSImage?
    var gameName=""
    var hue: CGFloat=0
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let shape=NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:16,yRadius:16)
        NSColor(calibratedRed:0.035,green:0.025,blue:0.09,alpha:cell?.isHighlighted == true ? 0.95 : 0.76).setFill();shape.fill()
        NSColor(calibratedHue:hue,saturation:0.75,brightness:1,alpha:isEnabled ? 0.38 : 0.12).setStroke();shape.lineWidth=1;shape.stroke()
        let size=min(88,max(24,bounds.height-52)),top=(bounds.height-size-24)/2
        artwork?.draw(in:NSRect(x:bounds.midX-size/2,y:top,width:size,height:size),from:.zero,operation:.sourceOver,fraction:isEnabled ? 1 : 0.4,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.none])
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        let pixel=min(2,(bounds.width-24)/pixelWidth(gameName,1))
        drawPixels(gameName,at:CGPoint(x:round(bounds.midX-pixelWidth(gameName,pixel)/2),y:top+size+10),pixel:pixel,colour:isEnabled ? .white : .gray,in:context)
    }
    override func drawFocusRingMask() { NSBezierPath(roundedRect:bounds,xRadius:16,yRadius:16).fill() }
    override var focusRingMaskBounds: NSRect { bounds }
}

final class PickerView: NSView {
    let backdrop=TrippyBackground(frame:.zero)
    let bling=BlingTitle(frame:.zero)
    var tiles=[GameTile]()
    let infoButton = NSButton(title: "Info", target: nil, action: nil)
    let footer=NSTextField(wrappingLabelWithString:"Llamasoft classics · Apple Silicon\nGames by Llamasoft · touchHLE compatibility layer")
    private var clock: Timer?
    var running=false { didSet { updateAnimation() } }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) {
        super.init(frame:frame)
        wantsLayer=true;layer?.backgroundColor=NSColor(calibratedRed:0.025,green:0.01,blue:0.065,alpha:1).cgColor
        addSubview(backdrop);addSubview(bling)
        bling.setAccessibilityElement(true);bling.setAccessibilityLabel("Minotaur Project")
        footer.alignment = .center;footer.textColor = .lightGray;footer.font = .systemFont(ofSize:13)
        footer.isSelectable=false;addSubview(footer)
        infoButton.bezelStyle = .rounded
        infoButton.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        infoButton.imagePosition = .imageLeading
        infoButton.setAccessibilityIdentifier("MinotaurInfo")
        addSubview(infoButton)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(accessibilityChanged),name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
    }
    required init?(coder: NSCoder) { nil }
    deinit { clock?.invalidate();NSWorkspace.shared.notificationCenter.removeObserver(self) }
    @objc private func accessibilityChanged() { updateAnimation() }
    func updateAnimation() {
        backdrop.running=running
        clock?.invalidate();clock=nil
        if running && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let timer=Timer(timeInterval:1/60,repeats:true) { [weak self] _ in self?.bling.needsDisplay=true }
            RunLoop.main.add(timer,forMode:.common);clock=timer
        }
        bling.needsDisplay=true
    }
    override func layout() {
        super.layout();backdrop.frame=bounds
        let width=min(840,bounds.width*0.86),height=min(760,bounds.height-48)
        let x=(bounds.width-width)/2,y=(bounds.height-height)/2
        bling.frame=NSRect(x:x,y:y,width:width,height:176)
        let gap: CGFloat=36,columnGap: CGFloat=48,gridHeight=height-268
        let tileWidth=(width-columnGap*2)/3,tileHeight=(gridHeight-gap*2)/3
        for (i,tile) in tiles.enumerated() {
            tile.frame=NSRect(x:x+CGFloat(i%3)*(tileWidth+columnGap),y:y+202+CGFloat(i/3)*(tileHeight+gap),width:tileWidth,height:tileHeight)
        }
        footer.frame=NSRect(x:x,y:y+height-40,width:width,height:40)
        infoButton.frame = NSRect(x: bounds.width - 104, y: 12, width: 88, height: 34)
    }
}

final class Launcher: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var picker: PickerView!
    private var children=[pid_t:NSRunningApplication]()
    private var launching=false
    private var goatControlItems=[NSMenuItem]()
    private lazy var info = PickerInfo()
    private var base: URL {
        let embedded=Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers")
        return FileManager.default.fileExists(atPath:embedded.path) ? embedded : Bundle.main.bundleURL.deletingLastPathComponent()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        UserDefaults.standard.register(defaults:["GoatUpGamepad":true])
        let main=NSMenu(),item=NSMenuItem(),menu=NSMenu();main.addItem(item);item.submenu=menu
        let about=menu.addItem(withTitle:"About Minotaur Project",action:#selector(showAbout),keyEquivalent:"");about.target=self
        menu.addItem(.separator());menu.addItem(withTitle:"Quit Minotaur Project",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        let controlsItem=NSMenuItem(title:"Controls",action:nil,keyEquivalent:"")
        let controls=NSMenu(title:"Controls"),goatItem=NSMenuItem(title:"GoatUp",action:nil,keyEquivalent:"")
        let goatMenu=NSMenu(title:"GoatUp")
        for (title,tag) in [("Gamepad — left stick / D-pad + A",1),("Mouse — original controls",0)] {
            let option=NSMenuItem(title:title,action:#selector(selectGoatControls(_:)),keyEquivalent:"")
            option.tag=tag;option.target=self;option.toolTip="Applied when you next launch GoatUp."
            goatMenu.addItem(option);goatControlItems.append(option)
        }
        goatMenu.addItem(.separator())
        let help=goatMenu.addItem(withTitle:"Gamepad controls…",action:#selector(showGoatControls),keyEquivalent:"");help.target=self
        goatItem.submenu=goatMenu;controls.addItem(goatItem);controls.addItem(.separator())
        let guide=controls.addItem(withTitle:"Controller guide…",action:#selector(showControllerGuide),keyEquivalent:"");guide.target=self
        controlsItem.submenu=controls;main.addItem(controlsItem)
        updateGoatControls();NSApp.mainMenu=main
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1080,height:900),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Minotaur Project";window.appearance=NSAppearance(named:.darkAqua)
        window.contentMinSize=NSSize(width:840,height:760)
        picker=PickerView(frame:window.contentView!.bounds);window.contentView=picker
        picker.backdrop.shuffleSprites()
        picker.infoButton.target = self
        picker.infoButton.action = #selector(showAbout)
        for (i,game) in games.enumerated() {
            let tile=GameTile(frame:.zero);tile.tag=i;tile.gameName=game.1.uppercased();tile.hue=CGFloat(i)/9
            tile.artwork=NSImage(contentsOf:Bundle.main.resourceURL!.appendingPathComponent("Icons/\(game.0).png"))
            tile.target=self;tile.action=#selector(play(_:));tile.isBordered=false;tile.title=""
            tile.setAccessibilityLabel(game.1);tile.setAccessibilityIdentifier(game.0)
            tile.keyEquivalent=String(i+1)
            tile.isEnabled=FileManager.default.fileExists(atPath:appPath(i).path)
            picker.addSubview(tile);picker.tiles.append(tile)
        }
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(gameTerminated(_:)),name:NSWorkspace.didTerminateApplicationNotification,object:nil)
        picker.needsLayout=true;window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        updateAnimation()
    }
    private func appPath(_ index: Int) -> URL { base.appendingPathComponent("\(games[index].1).app") }
    private func updateAnimation() { picker?.running=NSApp.isActive && children.isEmpty && !launching }
    func applicationDidBecomeActive(_ notification: Notification) { updateAnimation() }
    func applicationDidResignActive(_ notification: Notification) { updateAnimation() }
    @objc func showAbout() {
        info.show(.about, from: window)
    }
    @objc func play(_ sender: NSButton) {
        guard !launching else { return };launching=true;updateAnimation()
        let configuration=NSWorkspace.OpenConfiguration()
        if games[sender.tag].0=="GoatUp" { configuration.environment=["MPR_GOAT_GAMEPAD":UserDefaults.standard.bool(forKey:"GoatUpGamepad") ? "1" : "0"] }
        NSWorkspace.shared.openApplication(at:appPath(sender.tag),configuration:configuration) { [weak self] application,error in
            DispatchQueue.main.async {
                guard let self=self else { return };self.launching=false
                if let application=application,!application.isTerminated { self.children[application.processIdentifier]=application }
                if let error=error { NSAlert(error:error).runModal() }
                self.updateAnimation()
            }
        }
    }
    private func updateGoatControls() {
        let gamepad=UserDefaults.standard.bool(forKey:"GoatUpGamepad")
        for item in goatControlItems { item.state=(item.tag==1)==gamepad ? .on : .off }
    }
    @objc private func selectGoatControls(_ sender:NSMenuItem) {
        UserDefaults.standard.set(sender.tag==1,forKey:"GoatUpGamepad");updateGoatControls()
    }
    @objc private func showGoatControls() {
        let alert=NSAlert();alert.messageText="GoatUp gamepad controls"
        alert.informativeText="Left stick or D-pad: move left / right\nA: jump (hold for a higher jump)\nStart: pause / resume\nBack: quit from the pause menu\n\nGamepad mode selects the game's tilt controls automatically. Control changes apply the next time you launch GoatUp."
        alert.runModal()
    }
    @objc private func showControllerGuide() {
        info.show(.joystick, from: window)
    }
    @objc private func gameTerminated(_ notification: Notification) {
        guard let application=notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              children.removeValue(forKey:application.processIdentifier) != nil else { return }
        if children.isEmpty {
            picker.backdrop.shuffleSprites()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps:true)
        }
        updateAnimation()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication,hasVisibleWindows: Bool) -> Bool { window.makeKeyAndOrderFront(nil);return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main struct MinotaurMain {
    static func main() {
        let app=NSApplication.shared,delegate=Launcher();app.delegate=delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
