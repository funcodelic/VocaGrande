//
//  LanguageListViewiOS.swift
//  VocaGrande-iOS
//
//  Created by Troy Mulder on 11/3/26.
//

#if os(iOS)
import SwiftData
import SwiftUI

/// The iPhone's first scene: "me and my languages". The person button sets the
/// native language; the plus button adds a language to study, once a native language
/// is set. Tapping a language opens its words.
struct LanguageListViewiOS: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Language.dateAdded) private var languages: [Language]

    @AppStorage(ProfileKeys.nativeLanguage) private var nativeCode = ""
    @AppStorage(ProfileKeys.nativeLanguageColor) private var nativeColorName = ""

    @State private var selection: Language?
    @State private var isEditingNative = false
    @State private var isAddingLanguage = false
    @State private var editingLanguage: Language?
    @State private var languagePendingDelete: Language?

    /// The person button's color: secondary until a native language is set.
    private var personColor: Color {
        nativeCode.isEmpty ? .secondary : (LanguageColor(rawValue: nativeColorName) ?? .blue).color
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("VocaGrande")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("VocaGrande")
                            .font(.title2.weight(.medium))
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isEditingNative = true
                        } label: {
                            Image(systemName: "person.fill")
                                .font(.title3)
                                .foregroundStyle(personColor)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isAddingLanguage = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.orange)
                        }
                        .disabled(nativeCode.isEmpty)
                    }
                }
        } detail: {
            if let selection {
                LexemeListiOS(language: selection)
                    .id(selection.persistentModelID)
            } else {
                Text("Select a language")
                    .foregroundStyle(.tertiary)
            }
        }
        .task {
            Language.adoptOrphans(in: modelContext)
        }
        .sheet(isPresented: $isEditingNative) {
            LanguageDetailViewiOS(mode: .native)
        }
        .sheet(isPresented: $isAddingLanguage) {
            LanguageDetailViewiOS(mode: .new)
        }
        .sheet(item: $editingLanguage) { language in
            LanguageDetailViewiOS(mode: .edit(language))
        }
        .alert(
            "Delete \(languagePendingDelete?.name ?? "Language")?",
            isPresented: Binding(
                get: { languagePendingDelete != nil },
                set: { if !$0 { languagePendingDelete = nil } }
            ),
            presenting: languagePendingDelete
        ) { language in
            Button("Delete", role: .destructive) {
                delete(language)
            }
            Button("Cancel", role: .cancel) {}
        } message: { language in
            let count = language.lexemes.count
            Text("Are you sure you want to delete \(language.name) and its \(count) \(count == 1 ? "word" : "words")?")
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if languages.isEmpty {
            Text(nativeCode.isEmpty ? "Tap the person to set your native language." : "Tap + to add a language.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List(selection: $selection) {
                ForEach(languages) { language in
                    LanguageRowiOS(language: language)
                        .tag(language)
                        .contextMenu {
                            ForEach(LanguageColor.allCases, id: \.self) { option in
                                Button {
                                    language.colorName = option.rawValue
                                } label: {
                                    Label(
                                        option.rawValue.capitalized,
                                        systemImage: option.rawValue == language.colorName ? "checkmark.circle.fill" : "circle.fill"
                                    )
                                }
                                .tint(option.color)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                requestDelete(language)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)

                            Button {
                                editingLanguage = language
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.gray)
                        }
                }
            }
            .listStyle(.plain)
        }
    }

    /// A language with words asks first; an empty one is deleted straight away.
    private func requestDelete(_ language: Language) {
        if language.lexemes.isEmpty {
            delete(language)
        } else {
            languagePendingDelete = language
        }
    }

    private func delete(_ language: Language) {
        if selection == language { selection = nil }
        modelContext.delete(language)
    }
}

#Preview {
    LanguageListViewiOS()
        .modelContainer(for: [Language.self, Lexeme.self, TextSelectionItem.self], inMemory: true)
}
#endif
