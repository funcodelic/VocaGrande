//
//  BookPdfView.swift
//  VocaGrande
//
//  Created by Troy Mulder on 8/31/26.
//

import AppKit
import PDFKit
import SwiftData
import SwiftUI

/// Zoom commands and the current page number, shared between `BookPdfView`
/// and the app's View menu.
@Observable
final class BookPdfController {

    /// 1-based page number shown in the overlay at the bottom of the reader.
    var currentPage = 1

    /// Where captures are saved. `BookPdfView` hands over the environment's context
    /// when it appears.
    @ObservationIgnored var modelContext: ModelContext?

    /// Images dragged out of the book this session, by the item they were saved as.
    /// Never persisted: after a relaunch an image capture has only whatever text was
    /// read out of it.
    var sessionImages: [PersistentIdentifier: NSImage] = [:]

    /// What the API is doing for each capture right now, or how its last job ended.
    /// Session-only, like `sessionImages`. An entry appears when a read, clean,
    /// translation or parse starts, goes away when it succeeds, and stays as
    /// `.failed` until the next try.
    var activities: [PersistentIdentifier: CaptureActivity] = [:]

    private let imageReader = ImageReader()
    private let textCleaner = TextCleaner()
    private let textTranslator = TextTranslator()
    private let wordParser = WordParser(languageCode: "es")

    /// The text highlighted in the book right now, or nil when nothing is selected.
    /// Only drives the sidebar's `+` button being enabled; captures read the live
    /// selection instead.
    var selectedText: String?

    /// While on, the cursor is a crosshair and dragging marks off a rectangle to
    /// capture as an image rather than selecting text.
    var isAreaSelectionMode = false

    @ObservationIgnored private weak var pdfView: BookPDFView?

    fileprivate func attach(_ view: BookPDFView) {
        pdfView = view
        view.onAreaCaptured = { [weak self] image in
            self?.captureImage(image)
        }
        syncCurrentPage()
    }

    func toggleAreaSelectionMode() {
        isAreaSelectionMode.toggle()
        pdfView?.isAreaSelecting = isAreaSelectionMode
    }

    func zoomIn() {
        guard let pdfView, pdfView.canZoomIn else { return }
        pdfView.autoScales = false
        pdfView.zoomIn(nil)
    }

    func zoomOut() {
        guard let pdfView, pdfView.canZoomOut else { return }
        pdfView.autoScales = false
        pdfView.zoomOut(nil)
    }

    /// Scales the page to the window width, and keeps re-fitting as the window resizes.
    func fitToWindow() {
        pdfView?.autoScales = true
    }

    /// Saves whatever is highlighted in the book, then clears the highlight so the
    /// sidebar's `+` goes back to its resting state.
    func captureSelection() {
        guard let text = liveSelectionText() else { return }
        save(TextSelectionItem(selectionText: text))
        pdfView?.currentSelection = nil
        selectedText = nil
    }

    /// Saves an image dragged out of the book, then starts reading its text. Captures
    /// made this way have no text of their own until that read lands.
    private func captureImage(_ image: NSImage) {
        let item = TextSelectionItem()
        save(item)
        // Keyed after saving, when the id is permanent and matches what the sidebar's
        // query hands back.
        sessionImages[item.persistentModelID] = image
        read(item)
    }

    /// Reads the text printed in a capture's image into `selectionText`. Does
    /// nothing for a capture whose image is gone, which after a relaunch is all of
    /// them, or one the API is already working on.
    func read(_ item: TextSelectionItem) {
        let id = item.persistentModelID
        guard let image = sessionImages[id], !isBusy(id) else { return }
        run(.reading, for: item, or: "read the image") {
            try await self.imageReader.read(image)
        } store: { item, text in
            item.selectionText = text
        }
    }

    /// Cleans a capture's text into `cleanedText`, as `TextCleaner.instructions` asks.
    /// Does nothing when there is no text yet, or the API is already working on it.
    func clean(_ item: TextSelectionItem) {
        let id = item.persistentModelID
        guard let text = item.selectionText, !text.isEmpty, !isBusy(id) else { return }
        run(.cleaning, for: item, or: "clean the text") {
            try await self.textCleaner.clean(text)
        } store: { item, cleaned in
            item.cleanedText = cleaned
        }
    }

    /// Translates a capture's cleaned text into `translatedText`, as
    /// `TextTranslator.instructions` asks. Does nothing when the text hasn't been
    /// cleaned yet, or the API is already working on it.
    func translate(_ item: TextSelectionItem) {
        let id = item.persistentModelID
        guard let text = item.cleanedText, !text.isEmpty, !isBusy(id) else { return }
        run(.translating, for: item, or: "translate the text") {
            try await self.textTranslator.translate(text)
        } store: { item, translated in
            item.translatedText = translated
        }
    }

    /// Parses a capture's cleaned text into its Spanish words, as
    /// `WordParser.instructions` asks, and links the capture to one lexeme per
    /// word: an existing one when the word has been seen before, a new one
    /// otherwise. Does nothing when the text hasn't been cleaned yet, or the API is
    /// already working on it.
    func parse(_ item: TextSelectionItem) {
        let id = item.persistentModelID
        guard let modelContext, let text = item.cleanedText, !text.isEmpty, !isBusy(id) else { return }
        run(.parsing, for: item, or: "parse the words") {
            try await self.wordParser.parse(text)
        } store: { item, words in
            item.lexemes = self.lexemes(for: words, in: modelContext)
        }
    }

    /// The lexemes for parsed words: those already in the store, found by lemma,
    /// plus new ones inserted for words not seen before. An existing word keeps
    /// the meaning it has, unless it had none. Should the lookup fail, the
    /// uniqueness of `Lexeme.lemma` still stops the save from duplicating a word.
    private func lexemes(for words: [WordParser.Word], in modelContext: ModelContext) -> [Lexeme] {
        let lemmas = words.map(\.lemma)
        let existing = (try? modelContext.fetch(
            FetchDescriptor<Lexeme>(predicate: #Predicate { lemmas.contains($0.lemma) })
        )) ?? []
        var byLemma = Dictionary(existing.map { ($0.lemma, $0) }, uniquingKeysWith: { first, _ in first })

        for word in words {
            if let lexeme = byLemma[word.lemma] {
                if lexeme.englishMeaning?.isEmpty ?? true {
                    lexeme.englishMeaning = word.meaning
                }
            } else {
                let lexeme = Lexeme(
                    lemma: word.lemma,
                    englishMeaning: word.meaning,
                    languageCode: wordParser.languageCode
                )
                modelContext.insert(lexeme)
                byLemma[word.lemma] = lexeme
            }
        }
        return Array(byLemma.values)
    }

    /// Runs one API job for a capture and records how it went: what the job
    /// returns is stored on the item and saved, or the failure is kept for the row
    /// to show. A capture deleted while the job ran is left alone.
    private func run<Output>(
        _ activity: CaptureActivity,
        for item: TextSelectionItem,
        or action: String,
        job: @escaping () async throws -> Output,
        store: @escaping (TextSelectionItem, Output) -> Void
    ) {
        let id = item.persistentModelID
        activities[id] = activity
        Task {
            do {
                let result = try await job()
                guard !item.isDeleted else { return }
                store(item, result)
                activities[id] = nil
                if let modelContext {
                    saveChanges(modelContext, or: action)
                }
            } catch {
                print("Couldn't \(action): \(error)")
                activities[id] = .failed(error.localizedDescription)
            }
        }
    }

    private func isBusy(_ id: PersistentIdentifier) -> Bool {
        switch activities[id] {
        case .reading, .cleaning, .translating, .parsing: true
        case .failed, nil: false
        }
    }

    /// Removes a capture from the store, and forgets its session image and any
    /// activity it had.
    func delete(_ item: TextSelectionItem) {
        guard let modelContext else { return }
        sessionImages[item.persistentModelID] = nil
        activities[item.persistentModelID] = nil
        modelContext.delete(item)
        saveChanges(modelContext, or: "delete the capture")
    }

    private func save(_ item: TextSelectionItem) {
        guard let modelContext else { return }
        modelContext.insert(item)
        saveChanges(modelContext, or: "save the capture")
    }

    private func saveChanges(_ modelContext: ModelContext, or action: String) {
        do {
            try modelContext.save()
        } catch {
            print("Couldn't \(action): \(error)")
        }
    }

    fileprivate func syncCurrentPage() {
        guard let document = pdfView?.document, let page = pdfView?.currentPage else { return }
        currentPage = document.index(for: page) + 1
    }

    fileprivate func syncSelectedText() {
        selectedText = liveSelectionText()
    }

    private func liveSelectionText() -> String? {
        let text = pdfView?.currentSelection?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (text?.isEmpty ?? true) ? nil : text
    }
}

struct BookPdfView: View {

    private static let bookName = "Repase y Escriba"

    private enum LoadState {
        case loading
        case loaded(PDFDocument)
        case failed(String)
    }

    let controller: BookPdfController

    @Environment(\.modelContext) private var modelContext

    @State private var state: LoadState = .loading

    /// The sidebar starts hidden; the title-bar button reveals it.
    @State private var isSidebarVisible = false

    /// The vocabulary pane on the left starts hidden too; its own title-bar
    /// button, at the leading edge, reveals it.
    @State private var isLexemeListVisible = false

    var body: some View {
        HSplitView {
            if isLexemeListVisible {
                LexemeList()
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 400)
            }

            content
                .overlay(alignment: .bottom) { pageIndicator }
                .frame(minWidth: 400)

            if isSidebarVisible {
                SidebarView(controller: controller)
                    .frame(minWidth: 200, idealWidth: 200, maxWidth: 400)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    isLexemeListVisible.toggle()
                } label: {
                    Label("Toggle Vocabulary", systemImage: "sidebar.left")
                }
                .help(isLexemeListVisible ? "Hide Vocabulary" : "Show Vocabulary")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.right")
                }
                .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
            }
        }
        .task {
            controller.modelContext = modelContext
            load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let document):
            PdfKitView(document: document, controller: controller)
        case .failed(let message):
            ContentUnavailableView(
                "Couldn’t open \(Self.bookName).pdf",
                systemImage: "doc.questionmark",
                description: Text(message)
            )
        }
    }

    private var pageIndicator: some View {
        Text("Page \(controller.currentPage)")
            .font(.callout.monospacedDigit())
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator))
            .padding(.bottom, 16)
    }

    private func load() {
        guard case .loading = state else { return }
        guard let url = Bundle.main.url(forResource: Self.bookName, withExtension: "pdf") else {
            state = .failed("It isn’t in the app bundle.")
            return
        }
        guard let document = PDFDocument(url: url) else {
            state = .failed("The file at \(url.path) couldn’t be read as a PDF.")
            return
        }
        state = .loaded(document)
    }
}

/// Wraps PDFKit's `PDFView`, which already provides scrolling and zooming.
private struct PdfKitView: NSViewRepresentable {

    let document: PDFDocument
    let controller: BookPdfController

    func makeNSView(context: Context) -> PDFView {
        let view = BookPDFView()
        view.document = document
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.minScaleFactor = 0.25
        view.maxScaleFactor = 5
        view.autoScales = true
        controller.attach(view)
        context.coordinator.observe(view, controller: controller)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var observers: [NSObjectProtocol] = []

        func observe(_ view: PDFView, controller: BookPdfController) {
            let center = NotificationCenter.default

            observers.append(center.addObserver(
                forName: .PDFViewPageChanged, object: view, queue: .main
            ) { _ in
                MainActor.assumeIsolated { controller.syncCurrentPage() }
            })

            observers.append(center.addObserver(
                forName: .PDFViewSelectionChanged, object: view, queue: .main
            ) { _ in
                MainActor.assumeIsolated { controller.syncSelectedText() }
            })
        }

        deinit {
            let center = NotificationCenter.default
            for observer in observers { center.removeObserver(observer) }
        }
    }
}

/// The reader's `PDFView`: an I-beam cursor for reading, and a crosshair plus a
/// screenshot-style marquee while dragging out an image area.
private final class BookPDFView: PDFView {

    /// Called with the rendered image once a drag finishes.
    var onAreaCaptured: ((NSImage) -> Void)?

    var isAreaSelecting = false {
        didSet {
            marquee.rect = nil
            (isAreaSelecting ? NSCursor.crosshair : NSCursor.iBeam).set()
        }
    }

    private let marquee = MarqueeOverlay()
    private var dragOrigin: NSPoint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        addMarquee()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addMarquee()
    }

    private func addMarquee() {
        marquee.frame = bounds
        marquee.autoresizingMask = [.width, .height]
        addSubview(marquee, positioned: .above, relativeTo: nil)
    }

    override func setCursorFor(_ area: PDFAreaOfInterest) {
        (isAreaSelecting ? NSCursor.crosshair : NSCursor.iBeam).set()
    }

    // MARK: - Dragging out an area

    override func mouseDown(with event: NSEvent) {
        guard isAreaSelecting else { return super.mouseDown(with: event) }
        dragOrigin = convert(event.locationInWindow, from: nil)
        marquee.rect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard isAreaSelecting, let origin = dragOrigin else {
            return super.mouseDragged(with: event)
        }
        let dragged = NSRect(corner: origin, opposite: convert(event.locationInWindow, from: nil))
        marquee.rect = marquee.convert(dragged, from: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard isAreaSelecting, let origin = dragOrigin else {
            return super.mouseUp(with: event)
        }
        let dragged = NSRect(corner: origin, opposite: convert(event.locationInWindow, from: nil))
        dragOrigin = nil
        marquee.rect = nil

        guard dragged.width > 4, dragged.height > 4,
              let image = renderPageArea(dragged) else { return }
        onAreaCaptured?(image)
    }

    /// Renders the document under `rect` (in this view's coordinates) straight from
    /// the page rather than off the screen, so the result carries no UI chrome and
    /// stays sharp when the API reads it.
    private func renderPageArea(_ rect: NSRect) -> NSImage? {
        guard let page = page(for: rect.origin, nearest: true) else { return nil }

        let box = displayBox
        let pageBounds = page.bounds(for: box)
        let area = convert(rect, to: page).intersection(pageBounds)
        guard !area.isNull, area.width > 1, area.height > 1 else { return nil }

        let scale: CGFloat = 2
        let pixels = NSSize(width: area.width * scale, height: area.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixels.width.rounded()),
            pixelsHigh: Int(pixels.height.rounded()),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cg = context.cgContext
        cg.setFillColor(NSColor.white.cgColor)
        cg.fill(CGRect(origin: .zero, size: pixels))
        cg.scaleBy(x: scale, y: scale)
        // `draw(with:to:)` puts the box's origin at (0, 0), so shift the wanted area there.
        cg.translateBy(x: -(area.minX - pageBounds.minX), y: -(area.minY - pageBounds.minY))
        page.draw(with: box, to: cg)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: area.size)
        image.addRepresentation(rep)
        return image
    }
}

/// The translucent rectangle drawn while dragging, styled after the macOS
/// screenshot marquee.
private final class MarqueeOverlay: NSView {

    var rect: NSRect? {
        didSet { needsDisplay = true }
    }

    /// Never take the mouse; the PDF view underneath runs the drag.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let rect, rect.width > 0, rect.height > 0 else { return }

        NSColor.systemGray.withAlphaComponent(0.25).setFill()
        rect.fill()

        NSColor.systemGray.setStroke()
        let border = NSBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()
    }
}

private extension NSRect {
    /// The rectangle between two dragged corners, whichever way the drag went.
    init(corner: NSPoint, opposite: NSPoint) {
        self.init(
            x: min(corner.x, opposite.x),
            y: min(corner.y, opposite.y),
            width: abs(corner.x - opposite.x),
            height: abs(corner.y - opposite.y)
        )
    }
}

#Preview {
    BookPdfView(controller: BookPdfController())
        .frame(width: 1200, height: 800)
        .modelContainer(for: [TextSelectionItem.self, Lexeme.self], inMemory: true)
}
