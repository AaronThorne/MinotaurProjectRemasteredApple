import AppKit

final class PickerInfo: NSObject {
    enum Section: Int {
        case about, joystick
    }

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 640, height: 590),
        styleMask: [.titled], backing: .buffered, defer: false
    )
    private let tabs = NSSegmentedControl(
        labels: ["About", "Joystick"], trackingMode: .selectOne,
        target: nil, action: nil
    )
    private let scroll = NSTextView.scrollableTextView()
    private var text: NSTextView { scroll.documentView as! NSTextView }

    override init() {
        super.init()
        window.title = "Minotaur Project"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)

        let container = NSView()
        window.contentView = container
        tabs.target = self
        tabs.action = #selector(changeSection)
        let done = NSButton(title: "Done", target: self, action: #selector(close))
        done.keyEquivalent = "\r"

        for view in [tabs, done, scroll] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        NSLayoutConstraint.activate([
            tabs.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            tabs.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            done.centerYAnchor.constraint(equalTo: tabs.centerYAnchor),
            done.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        text.isEditable = false
        text.isSelectable = true
        text.textContainerInset = NSSize(width: 13, height: 8)
        text.backgroundColor = .textBackgroundColor
    }

    func show(_ section: Section, from parent: NSWindow) {
        tabs.selectedSegment = section.rawValue
        changeSection()
        if window.sheetParent == nil { parent.beginSheet(window) }
    }

    @objc private func close() {
        window.sheetParent?.endSheet(window)
    }

    @objc private func changeSection() {
        let content = NSMutableAttributedString()
        func append(_ line: String, font: NSFont, color: NSColor,
                    before: CGFloat = 0, after: CGFloat = 0, link: URL? = nil) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.paragraphSpacingBefore = before
            paragraph.paragraphSpacing = after
            paragraph.lineSpacing = 2
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph
            ]
            if let link { attributes[.link] = link }
            content.append(NSAttributedString(string: line + "\n", attributes: attributes))
        }
        func heading(_ title: String) {
            append(title, font: .systemFont(ofSize: 17, weight: .semibold),
                   color: .labelColor, before: 11, after: 8)
        }
        func entry(_ title: String, _ detail: String, link: URL? = nil) {
            append(title, font: .systemFont(ofSize: 14, weight: .semibold),
                   color: .labelColor, after: 2, link: link)
            append(detail, font: .systemFont(ofSize: 13), color: .secondaryLabelColor, after: 10)
        }

        if tabs.selectedSegment == Section.joystick.rawValue {
            heading("Mouse and keyboard")
            entry("Mouse and trackpad",
                  "Click to tap. Hold the primary button and drag to swipe. In tilt games, hold the secondary button and drag to simulate tilt.")
            entry("Shortcuts",
                  "Press 1–9 in the picker to open a game. In a game, Command–Q returns to the picker. F11 or Option–Return toggles full screen.")
            heading("Controller setup")
            entry("Pair before playing",
                  "Pair a wireless controller in System Settings → Bluetooth. The mappings below use Xbox button names.")
            entry("GoatUp control mode",
                  "Before launching, choose Controls → GoatUp → Gamepad for stick movement, or Mouse — original controls for mouse play.")
            heading("Game mappings")
            entry("Gridrunner", "Left stick moves. A selects or starts, Start pauses, and right shoulder cycles orientations.")
            entry("Super Ox Wars", "Left stick moves, A starts, and Start pauses.")
            entry("Minotron: 2112", "Left stick moves and right stick aims. In menus, left stick moves the pointer and A selects. Start pauses.")
            entry("Minotaur Rescue", "Left stick steers. In menus, left stick moves the pointer and A selects. Start plays or pauses.")
            entry("Five A Day", "Left stick moves, A starts, and Start pauses.")
            entry("Deflex", "D-pad or stick left and right operate the paddles. A selects, X plays, and Start pauses.")
            entry("Caverns of Minos", "Left stick steers and right stick tilts. A or right trigger thrusts, and Start pauses.")
            entry("GoatUp", "Left stick or D-pad moves, A jumps, and Start pauses. Choose Gamepad in the Controls menu first.")
            entry("GoatUp 2", "Select tilt mode in the game. Left stick tilts, A jumps, and Start pauses. X changes control mode while paused.")
        } else {
            heading("Original games")
            entry("Llamasoft", "Games by Jeff Minter and Ivan Zorzin. Games and artwork © Llamasoft and their respective owners.",
                  link: URL(string: "https://store.steampowered.com/search/?developer=Llamasoft+Ltd."))
            heading("Remastered collection")
            entry("Minotaur Project Remastered", "Windows collection, controller mappings and runtime fork by jedeyesniv-art.",
                  link: URL(string: "https://github.com/jedeyesniv-art/MinotaurProjectRemastered"))
            entry("Minotaur Project Remastered for Apple", "An unofficial fan adaptation for Mac, iPhone and iPad, developed with Codex assistance.")
            heading("Open source")
            entry("touchHLE", "Compatibility runtime by hikari_no_yume and contributors.",
                  link: URL(string: "https://github.com/touchHLE/touchHLE"))
            entry("Dynarmic", "Tools for translating and checking the original ARM code.",
                  link: URL(string: "https://github.com/touchHLE/dynarmic"))
            entry("SDL", "Windowing and controller input.", link: URL(string: "https://github.com/libsdl-org/SDL"))
        }
        text.textStorage?.setAttributedString(content)
        text.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
}
