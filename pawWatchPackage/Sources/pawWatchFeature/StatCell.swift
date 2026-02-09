#if os(iOS)
import SwiftUI

/// Reusable stat cell for displaying key-value pairs in session stats
@MainActor
struct StatCell: View {
    let title: String
    let value: String

    var body: some View {
        if #available(iOS 26, *) {
            modernStatCell
        } else {
            legacyStatCell
        }
    }

    @available(iOS 26, *)
    private var modernStatCell: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: CornerRadius.sm))
    }

    private var legacyStatCell: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.callout.weight(.semibold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

#endif
