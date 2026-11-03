//
//  LanguageDetailViewiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/3/26.
//

#if os(iOS)
import SwiftData
import SwiftUI

/// The sheet for choosing a language and its color. It serves three jobs: setting
/// the native language, adding a new language, and editing one already added. A
/// language that has words can no longer be switched to another; only its color
/// changes.
struct LanguageDetailViewiOS: View {

    enum Mode {
        case native
        case new
        case edit(Language)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Language.dateAdded) private var languages: [Language]

    @AppStorage(ProfileKeys.nativeLanguage) private var nativeCode = ""
    @AppStorage(ProfileKeys.nativeLanguageColor) private var nativeColorName = ""

    let mode: Mode

    /// The chosen language's code. Nil is the blank "none" selection.
    @State private var code: String?
    @State private var color: LanguageColor
    @State private var alertMessage: String?

    init(mode: Mode) {
        self.mode = mode

        switch mode {
        case .native:
            let defaults = UserDefaults.standard
            let saved = defaults.string(forKey: ProfileKeys.nativeLanguage) ?? ""
            _code = State(initialValue: saved.isEmpty ? nil : saved)
            _color = State(initialValue: LanguageColor(rawValue: defaults.string(forKey: ProfileKeys.nativeLanguageColor) ?? "") ?? .blue)
        case .new:
            _code = State(initialValue: nil)
            _color = State(initialValue: .blue)
        case .edit(let language):
            _code = State(initialValue: language.code)
            _color = State(initialValue: LanguageColor(rawValue: language.colorName) ?? .blue)
        }
    }

    private var title: String {
        switch mode {
        case .native: "Native Language"
        case .new: "New Language"
        case .edit: "Language"
        }
    }

    /// The language being edited, once it has words and can't be switched.
    private var lockedLanguage: Language? {
        if case .edit(let language) = mode, !language.lexemes.isEmpty { language } else { nil }
    }

    /// Spanish, in the color just picked; blank until something is chosen.
    private var selectedName: String {
        code.map { AppLanguage.name(forCode: $0) } ?? ""
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(selectedName.isEmpty ? "None" : selectedName)
                    .font(.title2)
                    .foregroundStyle(selectedName.isEmpty ? Color.secondary : color.color)

                colorRow

                if let lockedLanguage {
                    let count = lockedLanguage.lexemes.count
                    Text("\(lockedLanguage.name) has \(count) \(count == 1 ? "word" : "words"), so it can't be changed to a different language. You can still change its color.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    languageList
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .clipShape(Circle())
                    .disabled(code == nil)
                }
            }
            .onAppear {
                if case .new = mode {
                    let used = Set(languages.map(\.colorName) + [nativeColorName])
                    color = LanguageColor.defaultOrder.first { !used.contains($0.rawValue) } ?? .blue
                }
            }
            .alert(alertMessage ?? "", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var colorRow: some View {
        HStack(spacing: 12) {
            ForEach(LanguageColor.allCases, id: \.self) { option in
                Button {
                    color = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 26, height: 26)
                        .overlay {
                            if option == color {
                                Circle().strokeBorder(Color.primary, lineWidth: 3)
                                    .frame(width: 34, height: 34)
                            }
                        }
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var languageList: some View {
        List(AppLanguage.all) { language in
            Button {
                select(language)
            } label: {
                Text(label(for: language))
                    .font(.title3)
                    .fontWeight(language.code == code ? .semibold : .regular)
                    .foregroundStyle(isUnavailable(language) ? Color.secondary : (language.code == code ? color.color : Color.primary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }

    /// The native language reads "English - EN" while adding other languages, so it
    /// is clearly the one that's taken.
    private func label(for language: AppLanguage) -> String {
        if language.code == nativeCode, !isNativeMode {
            return "\(language.name) - \(language.code.uppercased())"
        }
        return language.name
    }

    private var isNativeMode: Bool {
        if case .native = mode { true } else { false }
    }

    /// A language that can't be picked right now: the native one, or one already added.
    private func isUnavailable(_ language: AppLanguage) -> Bool {
        conflict(for: language) != nil
    }

    /// Why `language` can't be picked, or nil when it can.
    private func conflict(for language: AppLanguage) -> String? {
        let editing: Language? = if case .edit(let existing) = mode { existing } else { nil }
        let added = languages.contains { $0.code == language.code && $0 !== editing }

        switch mode {
        case .native:
            return added ? "\(language.name) is already one of your languages." : nil
        case .new, .edit:
            if language.code == nativeCode { return "\(language.name) is your native language." }
            return added ? "\(language.name) already exists." : nil
        }
    }

    private func select(_ language: AppLanguage) {
        if let message = conflict(for: language) {
            alertMessage = message
        } else {
            code = language.code
        }
    }

    private func save() {
        guard let code else { return }

        switch mode {
        case .native:
            nativeCode = code
            nativeColorName = color.rawValue
        case .new:
            modelContext.insert(Language(code: code, color: color))
        case .edit(let language):
            if lockedLanguage == nil { language.code = code }
            language.colorName = color.rawValue
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    LanguageDetailViewiOS(mode: .new)
        .modelContainer(for: [Language.self, Lexeme.self, TextSelectionItem.self], inMemory: true)
}
#endif
