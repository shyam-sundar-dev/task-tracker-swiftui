import SwiftUI

// Shimmer placeholder shown while a layout is compiling for the first time.
// After first compile the LayoutCache is warm — subsequent launches render
// immediately from disk and never show this skeleton.
struct CardSkeletonView: View {
    @State private var shimmerOpacity: Double = 0.3

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.quaternarySystemFill))
            .frame(height: 180)
            .opacity(shimmerOpacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
                ) {
                    shimmerOpacity = 0.9
                }
            }
    }
}

#Preview {
    CardSkeletonView()
        .padding()
}
