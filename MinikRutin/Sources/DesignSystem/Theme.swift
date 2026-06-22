import SwiftUI
import UIKit

/// Central design tokens for MinikRutin.
/// Calm, parent-friendly pastel palette with a teal-green brand colour, large
/// tap targets and generous spacing for one-handed, sleep-deprived use.
enum Theme {

    // MARK: Brand
    static let brand = Color(hex: 0x3DAE8E)
    static let brandDark = Color(hex: 0x2E8C71)
    static let brandSoft = Color(hex: 0xE8F5F0)

    // MARK: Soft tints used on cards / chips
    static let mint = Color(hex: 0xE8F5F0)
    static let peach = Color(hex: 0xFBE9E1)
    static let cream = Color(hex: 0xFBF3DA)
    static let lilac = Color(hex: 0xEDEAFB)
    static let sky = Color(hex: 0xE4F1FB)
    static let blush = Color(hex: 0xF4C9BC)

    // MARK: Adaptive surfaces (light + dark)
    static let background = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.07, alpha: 1) : UIColor(red: 0.957, green: 0.965, blue: 0.972, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.13, alpha: 1) : .white
    })
    static let surfaceAlt = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.18, alpha: 1) : UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
    })

    // MARK: Text
    static let ink = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.96, alpha: 1) : UIColor(red: 0.17, green: 0.24, blue: 0.29, alpha: 1)
    })
    static let inkSecondary = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(white: 0.66, alpha: 1) : UIColor(red: 0.54, green: 0.59, blue: 0.63, alpha: 1)
    })

    // MARK: Semantic accents
    static let warn = Color(hex: 0xE5944B)
    static let danger = Color(hex: 0xD9534F)

    // MARK: Layout
    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 16
    static let pad: CGFloat = 16
    static let gap: CGFloat = 12
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
