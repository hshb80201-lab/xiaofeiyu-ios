import SwiftUI

@MainActor
struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLogin = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.78, green: 0.86, blue: 0.95),
                         Color(red: 0.95, green: 0.90, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VisualEffectBlur(style: .systemUltraThinMaterial)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    if let suggestion = vm.suggestion {
                        ClipboardBanner(
                            suggestion: suggestion,
                            onParse: { vm.acceptSuggestion() },
                            onDismiss: { vm.dismissSuggestion() }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    inputCard

                    if let error = vm.error {
                        errorCard(error)
                    }

                    if vm.parsing {
                        GlassCard {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("正在解析…")
                            }
                        }
                    }

                    if let media = vm.media {
                        mediaCard(media)
                    }

                    tipCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: vm.suggestion?.url)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { vm.checkClipboard() }
        }
        .sheet(isPresented: $showLogin) {
            BiliLoginSheet { _ in }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "fish.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("小肥鱼下载器").font(.title2.bold())
                Text("抖音 · 快手 · 小红书 · B站").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showLogin = true
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 24))
            }
        }
        .padding(.top, 8)
    }

    private var inputCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                TextField("粘贴分享链接或文案…", text: $vm.input, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.plain)

                HStack(spacing: 10) {
                    Button {
                        if let text = UIPasteboard.general.string {
                            vm.input = text
                        }
                    } label: {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await vm.parseNow() }
                    } label: {
                        Label("解析", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(vm.parsing)
                }
            }
        }
    }

    private func errorCard(_ text: String) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                Text(text).font(.footnote)
                Spacer()
            }
        }
    }

    private func mediaCard(_ media: ParsedMedia) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(media.platformName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.teal, in: Capsule())
                        .foregroundStyle(.white)
                    Text(media.quality).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }

                Text(media.title).font(.headline).lineLimit(2)
                if !media.author.isEmpty {
                    Text(media.author).font(.caption).foregroundStyle(.secondary)
                }

                if let cover = media.coverURL {
                    AsyncImage(url: cover) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                if media.type == "image" {
                    if !media.imageURLs.isEmpty {
                        Button {
                            vm.saveImage(index: 0)
                        } label: {
                            Label("保存第一张图片", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    if media.liveVideoURLs.indices.contains(0),
                       media.liveVideoURLs[0] != nil {
                        Button {
                            vm.saveLivePhoto(index: 0)
                        } label: {
                            Label("保存实况照片", systemImage: "livephoto")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    }
                }

                if media.isVideo {
                    Button {
                        vm.saveVideo()
                    } label: {
                        Label("保存视频", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)

                    Button {
                        vm.saveAudio()
                    } label: {
                        Label("仅下载音频", systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let message = vm.saveMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var tipCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("怎么用").font(.headline)
                Text("1. 在抖音 / 快手 / 小红书 / B站复制分享链接")
                Text("2. 回到这里，检测到链接会弹出提示条，点“一键解析”")
                Text("3. 视频、图片、音频按原清晰度保存")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}
