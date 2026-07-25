import SwiftUI
@available(macOS 13.0, *)
struct TestView: View {
    var body: some View {
        Rectangle()
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 16, bottomTrailingRadius: 16, topTrailingRadius: 0, style: .continuous))
    }
}
