import SwiftUI

struct WeatherScaffold<Content: View>: View {
    let uiState: WeatherUiState
    @Binding var snackbarMessage: String?
    let onRemoveBookmark: (Bookmark) -> Void
    let onLoadBookmark: (Bookmark) -> Void
    let onSettingsClick: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.weatherLiteColorScheme) private var colors
    @Environment(\.weatherLitePreferredColorScheme) private var preferredColorScheme
    @State private var showBookmarks: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            colors.background
                .ignoresSafeArea()

            content()

            if let message = snackbarMessage {
                Text(message)
                    .font(WeatherLiteTypography.bodyMedium)
                    .foregroundStyle(colors.surface)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colors.onSurface.opacity(0.9))
                            .shadow(radius: 4)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Weather App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: onSettingsClick) {
                    Image(systemName: "gearshape")
                        .font(WeatherLiteTypography.bodyMedium)
                        .foregroundStyle(colors.onBackground)
                }
                .accessibilityLabel("Settings")

                Button {
                    showBookmarks = true
                } label: {
                    Image(systemName: "bookmark")
                        .font(WeatherLiteTypography.bodyMedium)
                        .foregroundStyle(colors.onBackground)
                }
                .accessibilityLabel("Bookmarks")
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksSheetView(
                bookmarks: uiState.bookmarks,
                onBookmarkClick: { bookmark in
                    onLoadBookmark(bookmark)
                    showBookmarks = false
                },
                onDeleteClick: onRemoveBookmark,
                onDismiss: {
                    showBookmarks = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
            .presentationBackground(colors.background)
            .preferredColorScheme(preferredColorScheme)
        }
    }
}

private struct BookmarksSheetView: View {
    let bookmarks: [Bookmark]
    let onBookmarkClick: (Bookmark) -> Void
    let onDeleteClick: (Bookmark) -> Void
    let onDismiss: () -> Void

    @Environment(\.weatherLiteColorScheme) private var colors
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 36

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks Yet",
                        systemImage: "bookmark.slash",
                        description: Text("Bookmark a city on the weather screen to quickly jump to it here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(bookmarks) { bookmark in
                                HStack(spacing: 14) {
                                    Button {
                                        onBookmarkClick(bookmark)
                                    } label: {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(colors.primaryContainer)
                                                    .frame(width: badgeSize, height: badgeSize)

                                                Image(systemName: "location.fill")
                                                    .font(WeatherLiteTypography.bodyMedium.weight(.semibold))
                                                    .foregroundStyle(colors.primary)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(bookmark.cityName)
                                                    .font(WeatherLiteTypography.titleMedium)
                                                    .foregroundStyle(colors.onSurface)

                                                Text(bookmark.stateName)
                                                    .font(WeatherLiteTypography.bodySmall)
                                                    .foregroundStyle(colors.onSurfaceVariant)
                                            }

                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        onDeleteClick(bookmark)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(WeatherLiteTypography.titleLarge)
                                            .symbolRenderingMode(.hierarchical)
                                            .foregroundStyle(colors.onSurfaceVariant)
                                            .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Delete bookmark")
                                }
                                .padding(.vertical, 4)
                                .listRowBackground(colors.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        onDeleteClick(bookmark)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(colors.background.ignoresSafeArea())
            .navigationTitle("Bookmarked Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundStyle(colors.primary)
                }
            }
        }
    }
}
