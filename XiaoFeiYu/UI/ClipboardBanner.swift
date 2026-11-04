import SwiftUI

struct ClipboardBanner: View {
    let suggestion: ClipboardSuggestion
    let onParse: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.teal)
                .frame(width: 32, height: 32)
                .background(Color.teal.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("检测到 \(suggestion.platform) 链接")
                    .font(.system(size: 14, weight: .semibold))
                Text(suggestion.url)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button("忽略", action: onDismiss)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button("一键解析", action: onParse)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.teal, in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, 16)
    }
}
