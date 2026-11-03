import SwiftUI

struct ThockMark: Shape {
    static let aspect: CGFloat = 3350 / 3123

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 3350
        let sy = rect.height / 3123
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + (y - 61) * sy)
        }
        var path = Path()

        path.move(to: p(2576, 61))
        path.addLine(to: p(1460, 1177))
        path.addLine(to: p(0, 1177))
        path.addLine(to: p(0, 621))
        path.addArc(tangent1End: p(0, 61), tangent2End: p(560, 61), radius: 560 * sx)
        path.closeSubpath()

        path.move(to: p(2766, 509))
        path.addLine(to: p(3350, 509))
        path.addLine(to: p(3350, 1504))
        path.addArc(tangent1End: p(3350, 1844), tangent2End: p(3010, 1844), radius: 340 * sx)
        path.addLine(to: p(2233, 1844))
        path.addLine(to: p(2233, 2844))
        path.addArc(tangent1End: p(2233, 3184), tangent2End: p(1893, 3184), radius: 340 * sx)
        path.addLine(to: p(1117, 3184))
        path.addLine(to: p(1117, 1628))
        path.addLine(to: p(1647, 1628))
        path.closeSubpath()
        return path
    }
}
