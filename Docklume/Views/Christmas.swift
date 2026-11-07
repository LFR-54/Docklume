import SwiftUI

/// The Christmas theme: a winter sky behind the window, snow settled on the drive cards, the sidebar and the
/// surfaces at the top of a page, and a hat on the logo.
///
/// Nothing moves, and nothing is drawn again while the window is resized: the snow on a card keeps its shape until
/// the resize ends. Falling snow kept the window server redrawing the window: 25 % of a core at the screen's rate,
/// 10 % at 30 frames per second.
enum Christmas {
    /// The scrolling content of a page, where a card's place gives its snow a shape of its own.
    static let pageSpace = "christmas.page"
    /// The snow on each drive card, at its thickest.
    static let driveSnow: CGFloat = 13
}

/// Behind the content: the winter sky.
struct WinterBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(colors: scheme == .dark ? [Color(hex: 0x0C1628), Color(hex: 0x1B202B)] : [Color(hex: 0xC5D7EE), Color(hex: 0xE3EBF5)],
                       startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    /// Snow settled on top of a rounded surface, when the Christmas theme is on: in a page, only on the surfaces at
    /// its very top, unless `everywhere`. `depth` is the height of the pile at its thickest, by default from the
    /// width. A `seed` keeps the same snow on the same item wherever it is; without one, the surface's place shapes it.
    func snowCap(radius: CGFloat, depth: CGFloat? = nil, seed: String? = nil, everywhere: Bool = false) -> some View {
        modifier(SnowCapModifier(radius: radius, depth: depth, seed: seed, everywhere: everywhere))
    }
}

private struct SnowCapModifier: ViewModifier {
    let radius: CGFloat
    let depth: CGFloat?
    let seed: String?
    let everywhere: Bool
    @Environment(\.christmas) private var christmas
    @Environment(\.snowOnTopOnly) private var topOnly
    @Environment(\.liveResize) private var resizing
    @Environment(\.colorScheme) private var scheme
    @State private var frame = CGRect.zero
    /// The frame the snow was drawn for, kept while the window is being resized.
    @State private var drawnFor = CGRect.zero

    func body(content: Content) -> some View {
        if christmas {
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Christmas.pageSpace)) } action: { newFrame in
                    frame = newFrame
                    if !resizing { drawnFor = newFrame }
                }
                .onChange(of: resizing) { _, now in if !now { drawnFor = frame } }
                .overlay(alignment: .topLeading) {
                    if drawnFor.width > 0, !topOnly || everywhere || drawnFor.minY < 30 {
                        let cap = SnowCap(width: drawnFor.width, radius: radius, depth: depth ?? min(10, max(4, 3 + drawnFor.width / 110)),
                                          seed: Seed.hash(seed ?? "\((drawnFor.minX / 8).rounded()),\((drawnFor.minY / 8).rounded())") ^ UInt64(drawnFor.width.rounded()),
                                          dark: scheme == .dark)
                        cap.equatable()
                            .frame(width: drawnFor.width, height: cap.height)
                            .offset(y: -cap.depth)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
        } else {
            content
        }
    }
}

/// The pile itself, seen from the front: a lumpy top with round shoulders where it meets a rounded corner, and a
/// lip in shade that bulges over the front edge, casting a soft shadow on the face.
/// Equatable, so a card redrawn every second for its throughput leaves its snow alone.
private struct SnowCap: View, Equatable {
    let width: CGFloat
    let radius: CGFloat
    let depth: CGFloat
    let seed: UInt64
    let dark: Bool

    /// The pile above the edge, the lip below it and its shadow.
    var height: CGFloat { depth + 8 }

    var body: some View {
        Canvas { context, _ in
            var random = SeededRandom(seed: seed)
            let edge = depth
            let phases = (0..<4).map { _ in random.next(in: 0...(2 * Double.pi)) }
            let mounds = (0..<max(1, Int(width / 260))).map { _ in
                (center: random.next(in: 0...width), spread: random.next(in: CGFloat(25)...60), lift: random.next(in: CGFloat(0.2)...0.4))
            }
            // Snow slides off a rounded corner: none where the curve starts, then a round shoulder up to full depth.
            let start = radius * 0.3, rise = min(16, radius + 6)
            func shoulder(_ x: CGFloat) -> CGFloat {
                let t = max(0, min(1, (min(x, width - x) - start) / rise))
                return sqrt(1 - (1 - t) * (1 - t))
            }
            func top(_ x: CGFloat) -> CGFloat {
                let wave = Double(x)
                let lumps = 0.72 + 0.17 * sin(wave / 53 + phases[0]) + 0.09 * sin(wave / 19 + phases[1]) + 0.08 * sin(wave / 127 + phases[2])
                let bumps = mounds.reduce(CGFloat(0)) { sum, mound in
                    sum + mound.lift * CGFloat(exp(-pow(Double((x - mound.center) / mound.spread), 2)))
                }
                return edge - depth * shoulder(x) * (CGFloat(lumps) + bumps)
            }
            func lip(_ x: CGFloat) -> CGFloat {
                edge + shoulder(x) * CGFloat(2.6 + 1.1 * sin(Double(x) / 17 + phases[3]))
            }

            let step: CGFloat = 2
            var pile = Path()
            pile.move(to: CGPoint(x: 0, y: edge))
            for x in stride(from: 0, through: width, by: step) { pile.addLine(to: CGPoint(x: x, y: top(x))) }
            pile.addLine(to: CGPoint(x: width, y: edge))
            pile.closeSubpath()
            var face = Path()
            face.move(to: CGPoint(x: 0, y: edge))
            for x in stride(from: 0, through: width, by: step) { face.addLine(to: CGPoint(x: x, y: edge - 0.5)) }
            for x in stride(from: width, through: 0, by: -step) { face.addLine(to: CGPoint(x: x, y: lip(x))) }
            face.closeSubpath()

            // The shadow falls on the face of the surface only: above the edge it would smudge the background.
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: 0, y: edge, width: width, height: height)))
                layer.addFilter(.blur(radius: 2))
                layer.translateBy(x: 0, y: 2)
                layer.fill(face, with: .color(dark ? .black.opacity(0.5) : Color(hex: 0x2C4466).opacity(0.26)))
            }
            let lit = dark ? [Color(hex: 0xF4F7FB), Color(hex: 0xCBD5E3)] : [.white, Color(hex: 0xE8EEF6)]
            context.fill(pile, with: .linearGradient(Gradient(colors: lit), startPoint: CGPoint(x: 0, y: edge - depth), endPoint: CGPoint(x: 0, y: edge)))
            if !dark {
                // White on a pale background needs its outline.
                context.stroke(pile, with: .color(Color(hex: 0x8EA3C0).opacity(0.3)), lineWidth: 0.6)
            }
            // The front of the lip faces away from the light.
            let shaded = dark ? [Color(hex: 0xC2CDDD), Color(hex: 0x93A2B9)] : [Color(hex: 0xDCE5F0), Color(hex: 0xBCCADD)]
            context.fill(face, with: .linearGradient(Gradient(colors: shaded), startPoint: CGPoint(x: 0, y: edge), endPoint: CGPoint(x: 0, y: edge + 5)))
        }
    }
}

/// A Santa hat for the top left corner of the logo.
struct SantaHat: View {
    var body: some View {
        Canvas { context, size in
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }
            var cone = Path()
            cone.move(to: point(0.06, 0.8))
            cone.addCurve(to: point(0.54, 0.06), control1: point(0.1, 0.4), control2: point(0.28, 0.06))
            cone.addCurve(to: point(0.93, 0.46), control1: point(0.76, 0.06), control2: point(0.92, 0.22))
            cone.addCurve(to: point(0.74, 0.37), control1: point(0.88, 0.41), control2: point(0.8, 0.35))
            cone.addCurve(to: point(0.94, 0.8), control1: point(0.78, 0.52), control2: point(0.9, 0.64))
            cone.closeSubpath()
            context.fill(cone, with: .linearGradient(Gradient(colors: [Color(hex: 0xF0454D), Color(hex: 0xB0141C)]),
                                                     startPoint: point(0.2, 0.1), endPoint: point(0.9, 0.8)))
            let fur = Gradient(colors: [.white, Color(hex: 0xDCE2EA)])
            let band = CGRect(x: 0, y: 0.67 * size.height, width: size.width, height: 0.27 * size.height)
            context.fill(Path(roundedRect: band, cornerRadius: band.height / 2),
                         with: .linearGradient(fur, startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
            let ball = point(0.93, 0.46), radius = 0.13 * size.width
            context.fill(Path(ellipseIn: CGRect(x: ball.x - radius, y: ball.y - radius, width: 2 * radius, height: 2 * radius)),
                         with: .radialGradient(fur, center: CGPoint(x: ball.x - radius * 0.3, y: ball.y - radius * 0.3), startRadius: 0, endRadius: radius * 1.3))
        }
        .shadow(color: .black.opacity(0.28), radius: 1.2, y: 0.8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum Seed {
    /// FNV-1a: the same text gives the same number at every launch, unlike Hasher.
    static func hash(_ text: String) -> UInt64 {
        text.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
    }
}

/// A random sequence that comes out the same at every launch, so the drawings keep their look.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// SplitMix64.
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + next() * (range.upperBound - range.lowerBound)
    }

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        CGFloat(next(in: Double(range.lowerBound)...Double(range.upperBound)))
    }
}
