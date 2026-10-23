import SwiftUI

struct DropDownSection<T: Hashable & Sendable>: Identifiable, Sendable {
    let id: String
    let title: String?
    let options: [T]

    init(id: String? = nil, title: String? = nil, options: [T]) {
        self.id = id ?? title ?? UUID().uuidString
        self.title = title
        self.options = options
    }
}

struct SearchableDropDown<T: Hashable & Sendable>: View {
    let label: String
    let testTag: String
    let options: [T]
    let searchQuery: String
    let onSearchQueryChanged: (String) -> Void
    let onOptionSelected: (String) -> Void
    let onClear: () -> Void
    var isSelected: Bool = false
    var selectedValue: String? = nil
    var sections: [DropDownSection<T>]? = nil
    var initiallyExpanded: Bool = false
    var initiallySearchMode: Bool = false
    var optionToString: (T) -> String

    @Environment(\.weatherLiteColorScheme) private var colors
    @Environment(\.weatherLitePreferredColorScheme) private var preferredColorScheme
    @State private var expanded: Bool
    @State private var sheetSearchText: String = ""
    @State private var selectedDetent: PresentationDetent = .large

    init(
        label: String,
        testTag: String,
        options: [T],
        searchQuery: String,
        onSearchQueryChanged: @escaping (String) -> Void,
        onOptionSelected: @escaping (String) -> Void,
        onClear: @escaping () -> Void,
        isSelected: Bool = false,
        selectedValue: String? = nil,
        sections: [DropDownSection<T>]? = nil,
        initiallyExpanded: Bool = false,
        initiallySearchMode: Bool = false,
        optionToString: @escaping (T) -> String = { "\($0)" }
    ) {
        self.label = label
        self.testTag = testTag
        self.options = options
        self.searchQuery = searchQuery
        self.onSearchQueryChanged = onSearchQueryChanged
        self.onOptionSelected = onOptionSelected
        self.onClear = onClear
        self.isSelected = isSelected
        self.selectedValue = selectedValue
        self.sections = sections
        self.initiallyExpanded = initiallyExpanded
        self.initiallySearchMode = initiallySearchMode
        self.optionToString = optionToString
        self._expanded = State(initialValue: initiallyExpanded)
    }

    private var currentSelectionText: String? {
        if let selectedValue, !selectedValue.isEmpty {
            return selectedValue
        }
        if isSelected, !searchQuery.isEmpty {
            return searchQuery
        }
        return nil
    }

    private var isSearching: Bool {
        !sheetSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var validSections: [DropDownSection<T>]? {
        guard let sections else { return nil }
        let filtered = sections.filter { !$0.options.isEmpty }
        return filtered.isEmpty ? nil : filtered
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                sheetSearchText = ""
                selectedDetent = .large
                expanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(WeatherLiteTypography.labelSmall)
                            .foregroundStyle(expanded ? colors.primary : colors.onSurfaceVariant)

                        Text(currentSelectionText ?? "Select \(label)")
                            .font(WeatherLiteTypography.bodyLarge)
                            .foregroundStyle(
                                currentSelectionText != nil
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant.opacity(0.7)
                            )
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if !isSelected {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(WeatherLiteTypography.labelMedium.weight(.semibold))
                            .foregroundStyle(colors.onSurfaceVariant)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(testTag)

            if isSelected {
                Button {
                    sheetSearchText = ""
                    expanded = false
                    onClear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WeatherLiteTypography.titleMedium)
                        .foregroundStyle(colors.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear selection")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    expanded ? colors.primary : colors.outline.opacity(0.4),
                    lineWidth: expanded ? 2 : 1
                )
        )
        .sheet(isPresented: $expanded) {
            pickerSheet
                .presentationDetents([.large, .medium], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .preferredColorScheme(preferredColorScheme)
        }
        .onChange(of: expanded) { _, isPresented in
            if !isPresented && !sheetSearchText.isEmpty {
                sheetSearchText = ""
                onSearchQueryChanged(currentSelectionText ?? "")
            }
        }
    }

    private var pickerSheet: some View {
        NavigationStack {
            ZStack {
                colors.background
                    .ignoresSafeArea()

                if isSearching {
                    if options.isEmpty {
                        ContentUnavailableView.search(text: sheetSearchText)
                    } else {
                        flatScrollView(options: options)
                    }
                } else if let validSections, !validSections.isEmpty {
                    sectionedScrollView(sections: validSections)
                } else if options.isEmpty {
                    ContentUnavailableView.search(text: sheetSearchText)
                } else {
                    flatScrollView(options: options)
                }
            }
            .navigationTitle("Select \(label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        expanded = false
                    }
                    .foregroundStyle(colors.primary)
                }
            }
            .searchable(
                text: $sheetSearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search \(label)"
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .onChange(of: sheetSearchText) { _, newValue in
                guard expanded else { return }
                onSearchQueryChanged(newValue)
            }
        }
    }

    private func flatScrollView(options: [T]) -> some View {
        ScrollView {
            optionsCard(options: options)
                .padding(.vertical, 12)
        }
    }

    private func sectionedScrollView(sections: [DropDownSection<T>]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                ForEach(sections) { section in
                    Section {
                        optionsCard(options: section.options)
                    } header: {
                        if let title = section.title, !title.isEmpty {
                            sectionHeaderView(title: title)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func sectionHeaderView(title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(WeatherLiteTypography.labelMedium.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(colors.onSurfaceVariant)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.background)
    }

    private func optionsCard(options: [T]) -> some View {
        let lastOption = options.last
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(options, id: \.self) { option in
                let text = optionToString(option)
                let isOptionSelected = isSelected && text == currentSelectionText

                Button {
                    expanded = false
                    sheetSearchText = ""
                    onOptionSelected(text)
                } label: {
                    HStack(spacing: 12) {
                        Text(text)
                            .font(WeatherLiteTypography.bodyLarge)
                            .foregroundStyle(colors.onSurface)

                        Spacer()

                        if isOptionSelected {
                            Image(systemName: "checkmark")
                                .font(WeatherLiteTypography.bodySmall.weight(.semibold))
                                .foregroundStyle(colors.primary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if option != lastOption {
                    Divider()
                        .overlay(colors.outline.opacity(0.2))
                        .padding(.leading, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colors.surface)
        )
        .padding(.horizontal, 16)
    }
}
