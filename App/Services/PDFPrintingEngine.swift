import Foundation
import UIKit

struct RamsPDFDocument {
    var brandName: String
    var title: String
    var subtitle: String
    var projectName: String
    var referenceCode: String
    var generatedAt: Date
    var sections: [RamsPDFSection]
}

struct RamsPDFSection {
    var title: String
    var forcePageBreakBefore: Bool
    var blocks: [RamsPDFBlock]
}

struct RamsPDFBlock {
    var keepTogether: Bool = false
    var forcePageBreakBefore: Bool = false
    var content: RamsPDFBlockContent
}

indirect enum RamsPDFBlockContent {
    case heading(text: String, level: Int)
    case paragraph(text: String, style: RamsPDFTextStyle)
    case keyValueRows([(String, String)])
    case bulletList([String])
    case table(title: String?, headers: [String], rows: [[String]])
    case signatureCard(name: String, role: String, signedAt: String, imageData: Data)
    case image(data: Data, caption: String?)
    case group(title: String?, children: [RamsPDFBlock])
    case spacer(height: CGFloat)
}

enum RamsPDFTextStyle {
    case title
    case heading
    case subheading
    case body
    case caption

    var font: UIFont {
        switch self {
        case .title:
            return .boldSystemFont(ofSize: 22)
        case .heading:
            return .boldSystemFont(ofSize: 16)
        case .subheading:
            return .boldSystemFont(ofSize: 12.5)
        case .body:
            return .systemFont(ofSize: 10.5)
        case .caption:
            return .systemFont(ofSize: 8.8)
        }
    }
}

final class RamsPDFPrintEngine {
    // A4 at 72 DPI equivalent points (kept as *_PX for parity with DOM-export language)
    private let PAGE_WIDTH_PX: CGFloat = 595
    private let PAGE_HEIGHT_PX: CGFloat = 842
    private let PAGE_PADDING = UIEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
    private let headerReservedHeight: CGFloat = 42
    private let footerReservedHeight: CGFloat = 26

    private let minSplitHeight: CGFloat = 30
    private let blockSpacing: CGFloat = 8
    private let innerGroupSpacing: CGFloat = 4
    private let tableCellPadding: CGFloat = 5
    private let bulletIndent: CGFloat = 14

    private let brandColor = UIColor(red: 20 / 255, green: 68 / 255, blue: 116 / 255, alpha: 1)
    private let brandColorDark = UIColor(red: 13 / 255, green: 45 / 255, blue: 78 / 255, alpha: 1)
    private let mutedTextColor = UIColor(white: 0.33, alpha: 1)
    private let gridStrokeColor = UIColor(white: 0.78, alpha: 1)
    private let sectionBackgroundColor = UIColor(red: 232 / 255, green: 240 / 255, blue: 249 / 255, alpha: 1)
    private let zebraRowColor = UIColor(white: 0.97, alpha: 1)

    func export(document: RamsPDFDocument, fileNameStem: String) throws -> URL {
        let shell = createPageShell()
        let rootBlocks = prepareRootClone(from: document)
        let pages = paginateRoot(rootBlocks, shell: shell)
        let totalPages = pages.count + 1 // Cover page + content pages

        let renderer = UIGraphicsPDFRenderer(bounds: shell.pageRect)
        let fileName = "RAMS-\(fileNameStem)-\(Int(Date().timeIntervalSince1970)).pdf"
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try renderer.writePDF(to: outputURL) { context in
                context.beginPage()
                drawCoverPage(document: document, shell: shell, context: context, pageNumber: 1, totalPages: totalPages)

                for (index, page) in pages.enumerated() where !page.blocks.isEmpty {
                    let pageNumber = index + 2
                    context.beginPage()
                    var cursorY = shell.contentRect.minY
                    drawPageHeader(document: document, shell: shell, context: context, pageNumber: pageNumber, totalPages: totalPages)

                    for block in page.blocks {
                        cursorY = draw(block: block, at: cursorY, shell: shell, context: context)
                    }

                    drawPageFooter(document: document, shell: shell, context: context, pageNumber: pageNumber, totalPages: totalPages)
                }
            }
            return outputURL
        } catch {
            throw PDFExportError.exportFailed
        }
    }

    // MARK: - Root preparation

    private func prepareRootClone(from document: RamsPDFDocument) -> [RamsPDFBlock] {
        var root: [RamsPDFBlock] = []
        for section in document.sections {
            root.append(
                RamsPDFBlock(
                    keepTogether: true,
                    forcePageBreakBefore: section.forcePageBreakBefore,
                    content: .heading(text: section.title, level: 1)
                )
            )
            root.append(contentsOf: section.blocks.map(applyNoSplitHints))
            root.append(RamsPDFBlock(content: .spacer(height: 4)))
        }
        return root
    }

    private func applyNoSplitHints(_ block: RamsPDFBlock) -> RamsPDFBlock {
        switch block.content {
        case .group(let title, let children):
            return RamsPDFBlock(
                keepTogether: block.keepTogether,
                forcePageBreakBefore: block.forcePageBreakBefore,
                content: .group(
                    title: title,
                    children: children.map(applyNoSplitHints)
                )
            )
        case .table, .heading, .signatureCard:
            var updated = block
            // "Don't split inside" hint equivalent for key structural elements.
            updated.keepTogether = true
            return updated
        default:
            return block
        }
    }

    // MARK: - Pagination

    private struct PageShell {
        var pageRect: CGRect
        var contentRect: CGRect
    }

    private struct PageLayout {
        var blocks: [RamsPDFBlock] = []
        var usedHeight: CGFloat = 0
    }

    private func createPageShell() -> PageShell {
        let pageRect = CGRect(x: 0, y: 0, width: PAGE_WIDTH_PX, height: PAGE_HEIGHT_PX)
        let contentRect = CGRect(
            x: PAGE_PADDING.left,
            y: PAGE_PADDING.top + headerReservedHeight,
            width: PAGE_WIDTH_PX - PAGE_PADDING.left - PAGE_PADDING.right,
            height: PAGE_HEIGHT_PX - PAGE_PADDING.top - PAGE_PADDING.bottom - headerReservedHeight - footerReservedHeight
        )
        return PageShell(pageRect: pageRect, contentRect: contentRect)
    }

    private func paginateRoot(_ blocks: [RamsPDFBlock], shell: PageShell) -> [PageLayout] {
        var pending = blocks
        var pages: [PageLayout] = [PageLayout()]
        let pageContentHeight = shell.contentRect.height

        while !pending.isEmpty {
            let block = pending.removeFirst()
            var page = pages.removeLast()

            if block.forcePageBreakBefore, !page.blocks.isEmpty {
                pages.append(page)
                page = PageLayout()
            }

            let blockHeight = measure(block: block, width: shell.contentRect.width)
            let remaining = max(0, pageContentHeight - page.usedHeight)

            if blockHeight <= remaining {
                page.blocks.append(block)
                page.usedHeight += blockHeight
                pages.append(page)
                continue
            }

            if let split = splitBlock(
                block,
                availableHeight: remaining,
                fullPageHeight: pageContentHeight,
                contentWidth: shell.contentRect.width
            ) {
                if hasMeaningfulContent(split.head),
                   measure(block: split.head, width: shell.contentRect.width) <= remaining {
                    let consumed = measure(block: split.head, width: shell.contentRect.width)
                    page.blocks.append(split.head)
                    page.usedHeight += consumed
                }
                pages.append(page)
                pages.append(PageLayout())
                if hasMeaningfulContent(split.tail) {
                    pending.insert(split.tail, at: 0)
                }
                continue
            }

            if page.blocks.isEmpty {
                // Last-resort overflow page if no splitting strategy can safely cut the block.
                page.blocks.append(block)
                page.usedHeight += min(blockHeight, pageContentHeight)
                pages.append(page)
                pages.append(PageLayout())
            } else {
                pages.append(page)
                pages.append(PageLayout())
                pending.insert(block, at: 0)
            }
        }

        return pages.filter { !$0.blocks.isEmpty }
    }

    private func splitBlock(
        _ block: RamsPDFBlock,
        availableHeight: CGFloat,
        fullPageHeight: CGFloat,
        contentWidth: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        guard availableHeight >= minSplitHeight else { return nil }
        let fullHeight = measure(block: block, width: contentWidth)
        guard fullHeight > availableHeight else { return nil }

        if block.keepTogether, fullHeight <= fullPageHeight {
            return nil
        }

        switch block.content {
        case .table(let title, let headers, let rows):
            return splitTableBlock(
                original: block,
                title: title,
                headers: headers,
                rows: rows,
                availableHeight: availableHeight,
                width: contentWidth
            )
        case .group(let title, let children):
            if let descendant = splitGroupByDescendantGroups(
                original: block,
                title: title,
                children: children,
                availableHeight: availableHeight,
                width: contentWidth
            ) {
                return descendant
            }
            if let immediate = splitGroupByImmediateChildren(
                original: block,
                title: title,
                children: children,
                availableHeight: availableHeight,
                width: contentWidth
            ) {
                return immediate
            }
            return nil
        case .paragraph(let text, let style):
            return splitParagraphBlock(
                original: block,
                text: text,
                style: style,
                availableHeight: availableHeight,
                width: contentWidth
            )
        case .bulletList(let items):
            return splitBulletListBlock(
                original: block,
                items: items,
                availableHeight: availableHeight,
                width: contentWidth
            )
        case .keyValueRows(let pairs):
            return splitKeyValueRowsBlock(
                original: block,
                pairs: pairs,
                availableHeight: availableHeight,
                width: contentWidth
            )
        case .image(let data, let caption):
            return splitImageBlock(
                original: block,
                data: data,
                caption: caption,
                availableHeight: availableHeight,
                width: contentWidth
            )
        case .heading, .spacer, .signatureCard:
            return nil
        }
    }

    private func splitTableBlock(
        original: RamsPDFBlock,
        title: String?,
        headers: [String],
        rows: [[String]],
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        guard rows.count > 1 else { return nil }

        let titleHeight = title.map { measureText($0, style: .subheading, width: width) + innerGroupSpacing } ?? 0
        let columnWidths = tableColumnWidths(headers: headers, totalWidth: width)
        let headerHeight = measureTableHeader(headers: headers, columnWidths: columnWidths)
        var consumed = titleHeight + headerHeight
        var splitIndex = 0

        for (index, row) in rows.enumerated() {
            let rowHeight = measureTableRow(cells: row, columnWidths: columnWidths)
            if consumed + rowHeight > availableHeight {
                break
            }
            consumed += rowHeight
            splitIndex = index + 1
        }

        guard splitIndex > 0, splitIndex < rows.count else { return nil }

        let headRows = Array(rows.prefix(splitIndex))
        let tailRows = Array(rows.dropFirst(splitIndex))

        let head = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: original.forcePageBreakBefore,
            content: .table(title: title, headers: headers, rows: headRows)
        )
        let tail = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: false,
            content: .table(title: title.map { "\($0) (cont.)" }, headers: headers, rows: tailRows)
        )
        return (head, tail)
    }

    private func splitGroupByDescendantGroups(
        original: RamsPDFBlock,
        title: String?,
        children: [RamsPDFBlock],
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        guard children.count > 1 else { return nil }
        let candidateIndices = children.indices.filter { idx in
            if case .group = children[idx].content { return true }
            return false
        }
        guard !candidateIndices.isEmpty else { return nil }

        var bestSplit: Int?
        for index in candidateIndices where index > 0 {
            let headChildren = Array(children.prefix(index))
            let headBlock = RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: original.forcePageBreakBefore,
                content: .group(title: title, children: headChildren)
            )
            let headHeight = measure(block: headBlock, width: width)
            if headHeight <= availableHeight {
                bestSplit = index
            }
        }

        guard let splitIndex = bestSplit else { return nil }

        let head = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: original.forcePageBreakBefore,
            content: .group(title: title, children: Array(children.prefix(splitIndex)))
        )
        let tail = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: false,
            content: .group(title: title.map { "\($0) (cont.)" }, children: Array(children.dropFirst(splitIndex)))
        )
        return (head, tail)
    }

    private func splitGroupByImmediateChildren(
        original: RamsPDFBlock,
        title: String?,
        children: [RamsPDFBlock],
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        guard !children.isEmpty else { return nil }

        let titleHeight = title.map { measureText($0, style: .subheading, width: width) + innerGroupSpacing } ?? 0
        var consumed = titleHeight
        var splitIndex = 0

        for (index, child) in children.enumerated() {
            let childHeight = measure(block: child, width: width)
            if consumed + childHeight > availableHeight {
                break
            }
            consumed += childHeight
            splitIndex = index + 1
        }

        if splitIndex > 0, splitIndex < children.count {
            let head = RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: original.forcePageBreakBefore,
                content: .group(title: title, children: Array(children.prefix(splitIndex)))
            )
            let tail = RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: false,
                content: .group(title: title.map { "\($0) (cont.)" }, children: Array(children.dropFirst(splitIndex)))
            )
            return (head, tail)
        }

        guard splitIndex == 0 else { return nil }
        let firstChild = children[0]
        let remainingForFirst = max(0, availableHeight - titleHeight)

        guard let splitFirst = splitBlock(
            firstChild,
            availableHeight: remainingForFirst,
            fullPageHeight: createPageShell().contentRect.height - 14,
            contentWidth: width
        ) else {
            return nil
        }

        var headChildren = [splitFirst.head]
        var tailChildren = [splitFirst.tail]
        tailChildren.append(contentsOf: children.dropFirst())

        let head = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: original.forcePageBreakBefore,
            content: .group(title: title, children: headChildren)
        )
        let tail = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: false,
            content: .group(title: title.map { "\($0) (cont.)" }, children: tailChildren)
        )
        return (head, tail)
    }

    private func splitParagraphBlock(
        original: RamsPDFBlock,
        text: String,
        style: RamsPDFTextStyle,
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        let wrappedLines = wrapText(text, width: width, style: style)
        guard wrappedLines.count > 1 else {
            return splitParagraphByWords(original: original, text: text, style: style, availableHeight: availableHeight, width: width)
        }

        let lineHeight = style.font.lineHeight + 2
        let maxLines = Int(max(0, floor((availableHeight - blockSpacing) / lineHeight)))
        guard maxLines >= 1, maxLines < wrappedLines.count else { return nil }

        let headLines = wrappedLines.prefix(maxLines).joined(separator: "\n")
        let tailLines = wrappedLines.dropFirst(maxLines).joined(separator: "\n")
        let head = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: original.forcePageBreakBefore,
            content: .paragraph(text: headLines, style: style)
        )
        let tail = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: false,
            content: .paragraph(text: tailLines, style: style)
        )
        return (head, tail)
    }

    private func splitParagraphByWords(
        original: RamsPDFBlock,
        text: String,
        style: RamsPDFTextStyle,
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > 1 else { return nil }

        var bestPrefix = 0
        for index in 1..<words.count {
            let candidate = words.prefix(index).joined(separator: " ")
            let candidateHeight = measure(
                block: RamsPDFBlock(content: .paragraph(text: candidate, style: style)),
                width: width
            )
            if candidateHeight <= availableHeight {
                bestPrefix = index
            } else {
                break
            }
        }

        guard bestPrefix > 0, bestPrefix < words.count else { return nil }
        let headText = words.prefix(bestPrefix).joined(separator: " ")
        let tailText = words.dropFirst(bestPrefix).joined(separator: " ")

        return (
            RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: original.forcePageBreakBefore,
                content: .paragraph(text: headText, style: style)
            ),
            RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: false,
                content: .paragraph(text: tailText, style: style)
            )
        )
    }

    private func splitBulletListBlock(
        original: RamsPDFBlock,
        items: [String],
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        guard items.count > 1 else { return nil }
        var consumed: CGFloat = blockSpacing
        var splitIndex = 0

        for (index, item) in items.enumerated() {
            let lineHeight = measureText("• \(item)", style: .body, width: width - bulletIndent) + 2
            if consumed + lineHeight > availableHeight { break }
            consumed += lineHeight
            splitIndex = index + 1
        }

        guard splitIndex > 0, splitIndex < items.count else { return nil }
        return (
            RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: original.forcePageBreakBefore,
                content: .bulletList(Array(items.prefix(splitIndex)))
            ),
            RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: false,
                content: .bulletList(Array(items.dropFirst(splitIndex)))
            )
        )
    }

    private func splitKeyValueRowsBlock(
        original: RamsPDFBlock,
        pairs: [(String, String)],
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        guard pairs.count > 1 else { return nil }
        var consumed: CGFloat = 8
        var splitIndex = 0
        for (index, pair) in pairs.enumerated() {
            let text = "\(pair.0): \(pair.1)"
            let rowHeight = measureText(text, style: .body, width: width) + 3
            if consumed + rowHeight > availableHeight { break }
            consumed += rowHeight
            splitIndex = index + 1
        }

        guard splitIndex > 0, splitIndex < pairs.count else { return nil }
        return (
            RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: original.forcePageBreakBefore,
                content: .keyValueRows(Array(pairs.prefix(splitIndex)))
            ),
            RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: false,
                content: .keyValueRows(Array(pairs.dropFirst(splitIndex)))
            )
        )
    }

    private func splitImageBlock(
        original: RamsPDFBlock,
        data: Data,
        caption: String?,
        availableHeight: CGFloat,
        width: CGFloat
    ) -> (head: RamsPDFBlock, tail: RamsPDFBlock)? {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard imageSize.width > 0 else { return nil }

        let scale = width / imageSize.width
        let captionHeight = caption.map { measureText($0, style: .caption, width: width) + 2 } ?? 0
        let scaledHeight = imageSize.height * scale + captionHeight + blockSpacing
        guard scaledHeight > availableHeight else { return nil }

        let idealVisibleImageHeight = max(20, availableHeight - captionHeight - blockSpacing)
        let idealSliceSourceHeight = max(1, Int(idealVisibleImageHeight / scale))
        guard idealSliceSourceHeight < cgImage.height else { return nil }

        let breakRow = bestImageBreakRow(in: cgImage, near: idealSliceSourceHeight)
        guard breakRow > 2, breakRow < cgImage.height - 2 else { return nil }

        guard let topSlice = cgImage.cropping(to: CGRect(x: 0, y: 0, width: cgImage.width, height: breakRow)),
              let bottomSlice = cgImage.cropping(
                to: CGRect(x: 0, y: breakRow, width: cgImage.width, height: cgImage.height - breakRow)
              ) else {
            return nil
        }

        let topData = UIImage(cgImage: topSlice).pngData()
        let bottomData = UIImage(cgImage: bottomSlice).pngData()
        guard let topData, let bottomData else { return nil }

        let topMeaningful = imageHasMeaningfulContent(topSlice)
        let bottomMeaningful = imageHasMeaningfulContent(bottomSlice)
        guard topMeaningful || bottomMeaningful else { return nil }

        let headData = topMeaningful ? topData : bottomData
        let headBlock = RamsPDFBlock(
            keepTogether: false,
            forcePageBreakBefore: original.forcePageBreakBefore,
            content: .image(data: headData, caption: caption)
        )
        let tailBlock = topMeaningful && bottomMeaningful
            ? RamsPDFBlock(
                keepTogether: false,
                forcePageBreakBefore: false,
                content: .image(
                    data: bottomData,
                    caption: caption.map { "\($0) (cont.)" }
                )
            )
            : RamsPDFBlock(content: .spacer(height: 0))
        return (headBlock, tailBlock)
    }

    // MARK: - Measurement

    private func measure(block: RamsPDFBlock, width: CGFloat) -> CGFloat {
        switch block.content {
        case .heading(let text, let level):
            let style: RamsPDFTextStyle = level == 1 ? .heading : .subheading
            if level == 1 {
                return measureText(text, style: style, width: width - 18) + 14 + blockSpacing
            }
            return measureText(text, style: style, width: width) + blockSpacing
        case .paragraph(let text, let style):
            return measureText(text, style: style, width: width) + blockSpacing
        case .keyValueRows(let pairs):
            let totalRows = pairs.reduce(CGFloat.zero) { partial, pair in
                let text = "\(pair.0): \(pair.1)"
                return partial + measureText(text, style: .body, width: width) + 3
            }
            return totalRows + 8 + blockSpacing
        case .bulletList(let items):
            let rows = items.reduce(CGFloat.zero) { partial, item in
                partial + measureText("• \(item)", style: .body, width: width - bulletIndent) + 2
            }
            return rows + blockSpacing
        case .table(let title, let headers, let rows):
            let titleHeight = title.map { measureText($0, style: .subheading, width: width) + innerGroupSpacing } ?? 0
            let columnWidths = tableColumnWidths(headers: headers, totalWidth: width)
            let headerHeight = measureTableHeader(headers: headers, columnWidths: columnWidths)
            let rowHeights = rows.reduce(CGFloat.zero) { partial, row in
                partial + measureTableRow(cells: row, columnWidths: columnWidths)
            }
            return titleHeight + headerHeight + rowHeights + blockSpacing
        case .signatureCard:
            return 102 + blockSpacing
        case .image(let data, let caption):
            guard let image = UIImage(data: data), image.size.width > 0 else { return 0 }
            let scale = width / image.size.width
            let imageHeight = image.size.height * scale
            let captionHeight = caption.map { measureText($0, style: .caption, width: width) + 2 } ?? 0
            return imageHeight + captionHeight + blockSpacing
        case .group(let title, let children):
            let titleHeight = title.map { measureText($0, style: .subheading, width: width) + innerGroupSpacing } ?? 0
            let childHeight = children.reduce(CGFloat.zero) { partial, child in
                partial + measure(block: child, width: width)
            }
            return titleHeight + childHeight + blockSpacing
        case .spacer(let height):
            return height
        }
    }

    private func measureTableHeader(headers: [String], columnWidths: [CGFloat]) -> CGFloat {
        guard !headers.isEmpty, headers.count == columnWidths.count else { return 0 }
        let headerTextHeight = zip(headers, columnWidths).map { header, width in
            measureText(header, style: .subheading, width: width - (tableCellPadding * 2))
        }.max() ?? 0
        return headerTextHeight + (tableCellPadding * 2)
    }

    private func measureTableRow(cells: [String], columnWidths: [CGFloat]) -> CGFloat {
        guard !columnWidths.isEmpty else { return 0 }
        var maxText: CGFloat = 0
        for index in columnWidths.indices {
            let value = index < cells.count ? cells[index] : ""
            let paddedWidth = max(20, columnWidths[index] - (tableCellPadding * 2))
            maxText = max(maxText, measureText(value, style: .body, width: paddedWidth))
        }
        return maxText + (tableCellPadding * 2)
    }

    private func tableColumnWidths(headers: [String], totalWidth: CGFloat) -> [CGFloat] {
        guard !headers.isEmpty else { return [] }
        let lowered = headers.map { $0.lowercased() }

        let fractions: [CGFloat]
        if lowered == ["hazard", "risk to", "initial", "residual", "review"] {
            fractions = [0.28, 0.32, 0.12, 0.12, 0.16]
        } else if lowered == ["signer", "role", "signed at"] {
            fractions = [0.3, 0.38, 0.32]
        } else if lowered == ["name", "role", "phone"] {
            fractions = [0.34, 0.38, 0.28]
        } else {
            let equal = 1 / CGFloat(headers.count)
            fractions = Array(repeating: equal, count: headers.count)
        }

        let normalized = fractions.map { max(0, $0) }
        let sum = max(0.0001, normalized.reduce(0, +))
        return normalized.map { ($0 / sum) * totalWidth }
    }

    private func measureText(_ text: String, style: RamsPDFTextStyle, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: style.font]
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(rect.height)
    }

    private func wrapText(_ text: String, width: CGFloat, style: RamsPDFTextStyle) -> [String] {
        let paragraphs = text.components(separatedBy: .newlines)
        var lines: [String] = []
        for paragraph in paragraphs {
            let words = paragraph.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !words.isEmpty else {
                lines.append("")
                continue
            }

            var currentLine = words[0]
            for word in words.dropFirst() {
                let candidate = "\(currentLine) \(word)"
                if measureText(candidate, style: style, width: width) <= style.font.lineHeight + 6 {
                    currentLine = candidate
                } else {
                    lines.append(currentLine)
                    currentLine = word
                }
            }
            lines.append(currentLine)
        }
        return lines
    }

    // MARK: - Drawing

    @discardableResult
    private func draw(
        block: RamsPDFBlock,
        at y: CGFloat,
        shell: PageShell,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        switch block.content {
        case .heading(let text, let level):
            let style: RamsPDFTextStyle = level == 1 ? .heading : .subheading
            if level == 1 {
                let textHeight = measureText(text, style: style, width: shell.contentRect.width - 18)
                let bannerHeight = textHeight + 14
                let bannerRect = CGRect(
                    x: shell.contentRect.minX,
                    y: y,
                    width: shell.contentRect.width,
                    height: bannerHeight
                )
                context.cgContext.setFillColor(sectionBackgroundColor.cgColor)
                let path = UIBezierPath(roundedRect: bannerRect, cornerRadius: 6)
                context.cgContext.addPath(path.cgPath)
                context.cgContext.fillPath()

                let stripeRect = CGRect(x: bannerRect.minX, y: bannerRect.minY, width: 5, height: bannerRect.height)
                context.cgContext.setFillColor(brandColor.cgColor)
                context.cgContext.fill(stripeRect)

                let nextY = drawText(
                    text,
                    style: style,
                    at: CGPoint(x: shell.contentRect.minX + 10, y: y + 7),
                    width: shell.contentRect.width - 14
                )
                return max(nextY, bannerRect.maxY) + blockSpacing
            } else {
                let nextY = drawText(
                    text,
                    style: style,
                    at: CGPoint(x: shell.contentRect.minX, y: y),
                    width: shell.contentRect.width
                )
                return nextY + blockSpacing
            }

        case .paragraph(let text, let style):
            let nextY = drawText(
                text,
                style: style,
                at: CGPoint(x: shell.contentRect.minX, y: y),
                width: shell.contentRect.width
            )
            return nextY + blockSpacing

        case .keyValueRows(let pairs):
            var cursor = y
            let measuredBlock = measure(block: RamsPDFBlock(content: .keyValueRows(pairs)), width: shell.contentRect.width)
            let cardHeight = max(0, measuredBlock - blockSpacing)
            let cardRect = CGRect(x: shell.contentRect.minX, y: y, width: shell.contentRect.width, height: cardHeight)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 6)
            context.cgContext.setFillColor(UIColor(white: 0.985, alpha: 1).cgColor)
            context.cgContext.addPath(cardPath.cgPath)
            context.cgContext.fillPath()
            context.cgContext.setStrokeColor(gridStrokeColor.cgColor)
            context.cgContext.addPath(cardPath.cgPath)
            context.cgContext.strokePath()

            cursor += 8
            for pair in pairs {
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10.5),
                    .foregroundColor: brandColorDark
                ]
                let valueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10.5),
                    .foregroundColor: UIColor.black
                ]
                let label = "\(pair.0): "
                let labelWidth = ceil((label as NSString).size(withAttributes: labelAttributes).width)
                let point = CGPoint(x: shell.contentRect.minX + 8, y: cursor)
                (label as NSString).draw(at: point, withAttributes: labelAttributes)
                let valueRect = CGRect(
                    x: shell.contentRect.minX + 8 + labelWidth,
                    y: cursor,
                    width: shell.contentRect.width - labelWidth - 16,
                    height: .greatestFiniteMagnitude
                )
                let valueHeight = ceil((pair.1 as NSString).boundingRect(
                    with: CGSize(width: valueRect.width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: valueAttributes,
                    context: nil
                ).height)
                (pair.1 as NSString).draw(
                    with: CGRect(x: valueRect.minX, y: cursor, width: valueRect.width, height: valueHeight),
                    options: [.usesLineFragmentOrigin],
                    attributes: valueAttributes,
                    context: nil
                )
                cursor += valueHeight + 3
            }
            return max(cursor, cardRect.maxY) + blockSpacing

        case .bulletList(let items):
            var cursor = y
            for item in items {
                let textRect = CGRect(
                    x: shell.contentRect.minX + bulletIndent,
                    y: cursor,
                    width: shell.contentRect.width - bulletIndent,
                    height: .greatestFiniteMagnitude
                )
                let bulletPoint = CGPoint(x: shell.contentRect.minX, y: cursor)
                ("•" as NSString).draw(at: bulletPoint, withAttributes: [.font: RamsPDFTextStyle.body.font])
                let nextY = drawText(item, style: .body, in: textRect)
                cursor = nextY + 2
            }
            return cursor + blockSpacing

        case .table(let title, let headers, let rows):
            var cursor = y
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cursor = drawText(
                    title,
                    style: .subheading,
                    at: CGPoint(x: shell.contentRect.minX, y: cursor),
                    width: shell.contentRect.width
                ) + innerGroupSpacing
            }

            cursor = drawTable(
                headers: headers,
                rows: rows,
                at: CGPoint(x: shell.contentRect.minX, y: cursor),
                width: shell.contentRect.width,
                context: context
            )
            return cursor + blockSpacing

        case .signatureCard(let name, let role, let signedAt, let imageData):
            let cardRect = CGRect(x: shell.contentRect.minX, y: y, width: shell.contentRect.width, height: 102)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
            context.cgContext.setFillColor(UIColor(white: 0.985, alpha: 1).cgColor)
            context.cgContext.addPath(cardPath.cgPath)
            context.cgContext.fillPath()
            context.cgContext.setStrokeColor(gridStrokeColor.cgColor)
            context.cgContext.addPath(cardPath.cgPath)
            context.cgContext.strokePath()

            let imageWidth: CGFloat = 190
            let imageHeight: CGFloat = 62
            let imageX = cardRect.maxX - imageWidth - 10
            let imageY = cardRect.minY + 20
            let imageRect = CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(imageRect)
            context.cgContext.setStrokeColor(gridStrokeColor.cgColor)
            context.cgContext.stroke(imageRect)

            if let signatureImage = UIImage(data: imageData), signatureImage.size.width > 0 {
                signatureImage.draw(in: imageRect.insetBy(dx: 2, dy: 2))
            }

            let textWidth = max(90, shell.contentRect.width - imageWidth - 28)
            var textCursor = cardRect.minY + 12
            textCursor = drawText(name, style: .subheading, at: CGPoint(x: cardRect.minX + 10, y: textCursor), width: textWidth)
            textCursor = drawText(role, style: .body, at: CGPoint(x: cardRect.minX + 10, y: textCursor + 2), width: textWidth)
            _ = drawText("Signed: \(signedAt)", style: .caption, at: CGPoint(x: cardRect.minX + 10, y: textCursor + 3), width: textWidth)

            let stampRect = CGRect(x: cardRect.minX + 10, y: cardRect.maxY - 19, width: 94, height: 14)
            let stampPath = UIBezierPath(roundedRect: stampRect, cornerRadius: 2)
            context.cgContext.setFillColor(brandColor.cgColor)
            context.cgContext.addPath(stampPath.cgPath)
            context.cgContext.fillPath()
            _ = drawText(
                "DIGITAL SIGNED",
                style: .caption,
                at: CGPoint(x: stampRect.minX + 5, y: stampRect.minY + 2),
                width: stampRect.width - 6,
                color: .white
            )

            return cardRect.maxY + blockSpacing

        case .image(let data, let caption):
            guard let image = UIImage(data: data), image.size.width > 0 else {
                return y
            }
            var cursor = y
            let ratio = shell.contentRect.width / image.size.width
            let renderSize = CGSize(width: shell.contentRect.width, height: image.size.height * ratio)
            let rect = CGRect(x: shell.contentRect.minX, y: cursor, width: renderSize.width, height: renderSize.height)
            image.draw(in: rect)
            cursor += renderSize.height + 2
            if let caption {
                cursor = drawText(
                    caption,
                    style: .caption,
                    at: CGPoint(x: shell.contentRect.minX, y: cursor),
                    width: shell.contentRect.width
                )
            }
            return cursor + blockSpacing

        case .group(let title, let children):
            var cursor = y
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cursor = drawText(
                    title,
                    style: .subheading,
                    at: CGPoint(x: shell.contentRect.minX, y: cursor),
                    width: shell.contentRect.width
                ) + innerGroupSpacing
            }
            for child in children {
                cursor = draw(block: child, at: cursor, shell: shell, context: context)
            }
            return cursor + blockSpacing

        case .spacer(let height):
            return y + height
        }
    }

    @discardableResult
    private func drawText(
        _ text: String,
        style: RamsPDFTextStyle,
        at point: CGPoint,
        width: CGFloat,
        color: UIColor = .black
    ) -> CGFloat {
        drawText(
            text,
            style: style,
            in: CGRect(x: point.x, y: point.y, width: width, height: .greatestFiniteMagnitude),
            color: color
        )
    }

    @discardableResult
    private func drawText(_ text: String, style: RamsPDFTextStyle, in rect: CGRect, color: UIColor = .black) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: style.font,
            .foregroundColor: color
        ]
        let measured = NSString(string: text).boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let drawRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(measured.height))
        NSString(string: text).draw(with: drawRect, options: [.usesLineFragmentOrigin], attributes: attributes, context: nil)
        return drawRect.maxY
    }

    private func drawTable(
        headers: [String],
        rows: [[String]],
        at point: CGPoint,
        width: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        guard !headers.isEmpty else { return point.y }
        let columns = headers.count
        let columnWidths = tableColumnWidths(headers: headers, totalWidth: width)
        var cursorY = point.y
        let cg = context.cgContext

        let headerHeight = measureTableHeader(headers: headers, columnWidths: columnWidths)
        let headerRect = CGRect(x: point.x, y: cursorY, width: width, height: headerHeight)
        brandColor.setFill()
        cg.fill(headerRect)

        var columnX = point.x
        for (columnIndex, header) in headers.enumerated() {
            let cellRect = CGRect(
                x: columnX,
                y: cursorY,
                width: columnWidths[columnIndex],
                height: headerHeight
            )
            gridStrokeColor.setStroke()
            cg.stroke(cellRect)
            _ = drawText(
                header,
                style: .subheading,
                in: cellRect.insetBy(dx: tableCellPadding, dy: tableCellPadding),
                color: .white
            )
            columnX += columnWidths[columnIndex]
        }
        cursorY += headerHeight

        for (rowIndex, row) in rows.enumerated() {
            let rowHeight = measureTableRow(cells: row, columnWidths: columnWidths)
            if rowIndex.isMultiple(of: 2) {
                zebraRowColor.setFill()
                cg.fill(CGRect(x: point.x, y: cursorY, width: width, height: rowHeight))
            }

            var rowColumnX = point.x
            for columnIndex in 0..<columns {
                let value = columnIndex < row.count ? row[columnIndex] : ""
                let cellRect = CGRect(
                    x: rowColumnX,
                    y: cursorY,
                    width: columnWidths[columnIndex],
                    height: rowHeight
                )
                gridStrokeColor.setStroke()
                cg.stroke(cellRect)
                _ = drawText(
                    value,
                    style: .body,
                    in: cellRect.insetBy(dx: tableCellPadding, dy: tableCellPadding),
                    color: .black
                )
                rowColumnX += columnWidths[columnIndex]
            }
            cursorY += rowHeight
        }

        return cursorY
    }

    private func drawCoverPage(
        document: RamsPDFDocument,
        shell: PageShell,
        context: UIGraphicsPDFRendererContext,
        pageNumber: Int,
        totalPages: Int
    ) {
        let cg = context.cgContext
        let bannerHeight: CGFloat = 170
        let bannerRect = CGRect(x: 0, y: 0, width: shell.pageRect.width, height: bannerHeight)
        cg.setFillColor(brandColor.cgColor)
        cg.fill(bannerRect)

        _ = drawText(
            document.brandName,
            style: .caption,
            at: CGPoint(x: shell.contentRect.minX, y: 42),
            width: shell.contentRect.width,
            color: .white
        )
        _ = drawText(
            document.title,
            style: .title,
            at: CGPoint(x: shell.contentRect.minX, y: 68),
            width: shell.contentRect.width,
            color: .white
        )
        _ = drawText(
            document.subtitle,
            style: .subheading,
            at: CGPoint(x: shell.contentRect.minX, y: 102),
            width: shell.contentRect.width,
            color: UIColor(white: 0.93, alpha: 1)
        )

        let infoStartY = bannerRect.maxY + 42
        let infoRows = [
            ("Project", document.projectName),
            ("Reference", document.referenceCode),
            ("Issued", DateFormatter.shortDateTime.string(from: document.generatedAt))
        ]
        var y = infoStartY
        for (label, value) in infoRows {
            _ = drawText(
                "\(label):",
                style: .subheading,
                at: CGPoint(x: shell.contentRect.minX, y: y),
                width: 120,
                color: brandColorDark
            )
            y = drawText(
                value,
                style: .body,
                at: CGPoint(x: shell.contentRect.minX + 124, y: y + 1),
                width: shell.contentRect.width - 124
            ) + 9
        }

        let declarationText = """
        This document contains the project master information, RAMS methodology, hazard/risk controls, and sign-off evidence.
        Distribute only to authorized personnel and ensure all revisions are approved before site use.
        """
        _ = drawText(
            declarationText,
            style: .body,
            at: CGPoint(x: shell.contentRect.minX, y: y + 20),
            width: shell.contentRect.width,
            color: mutedTextColor
        )

        drawPageFooter(document: document, shell: shell, context: context, pageNumber: pageNumber, totalPages: totalPages)
    }

    private func drawPageHeader(
        document: RamsPDFDocument,
        shell: PageShell,
        context: UIGraphicsPDFRendererContext,
        pageNumber: Int,
        totalPages: Int
    ) {
        let topRect = CGRect(
            x: shell.contentRect.minX,
            y: PAGE_PADDING.top,
            width: shell.contentRect.width,
            height: headerReservedHeight - 8
        )
        context.cgContext.setFillColor(UIColor(white: 0.98, alpha: 1).cgColor)
        context.cgContext.fill(topRect)

        _ = drawText(
            document.brandName,
            style: .caption,
            at: CGPoint(x: topRect.minX + 8, y: topRect.minY + 6),
            width: topRect.width * 0.45,
            color: brandColorDark
        )

        _ = drawText(
            document.referenceCode.ifBlank("RAMS"),
            style: .caption,
            at: CGPoint(x: topRect.minX + 8, y: topRect.minY + 18),
            width: topRect.width * 0.45,
            color: mutedTextColor
        )

        let pageLabel = "Page \(pageNumber) of \(totalPages)"
        _ = drawText(
            pageLabel,
            style: .caption,
            at: CGPoint(x: topRect.maxX - 130, y: topRect.minY + 6),
            width: 122,
            color: mutedTextColor
        )

        _ = drawText(
            document.projectName.ifBlank("Project"),
            style: .caption,
            at: CGPoint(x: topRect.maxX - 220, y: topRect.minY + 18),
            width: 212,
            color: mutedTextColor
        )

        let lineRect = CGRect(
            x: shell.contentRect.minX,
            y: shell.contentRect.minY - 8,
            width: shell.contentRect.width,
            height: 1
        )
        context.cgContext.setFillColor(gridStrokeColor.cgColor)
        context.cgContext.fill(lineRect)
    }

    private func drawPageFooter(
        document: RamsPDFDocument,
        shell: PageShell,
        context: UIGraphicsPDFRendererContext,
        pageNumber: Int,
        totalPages: Int
    ) {
        let footerY = shell.contentRect.maxY + 7
        let lineRect = CGRect(x: shell.contentRect.minX, y: footerY, width: shell.contentRect.width, height: 0.8)
        context.cgContext.setFillColor(gridStrokeColor.cgColor)
        context.cgContext.fill(lineRect)

        _ = drawText(
            "Generated \(DateFormatter.shortDateTime.string(from: document.generatedAt))",
            style: .caption,
            at: CGPoint(x: shell.contentRect.minX, y: footerY + 3),
            width: 220,
            color: mutedTextColor
        )
        _ = drawText(
            document.title,
            style: .caption,
            at: CGPoint(x: shell.contentRect.midX - 100, y: footerY + 3),
            width: 200,
            color: mutedTextColor
        )
        _ = drawText(
            "Page \(pageNumber)/\(totalPages)",
            style: .caption,
            at: CGPoint(x: shell.contentRect.maxX - 90, y: footerY + 3),
            width: 90,
            color: mutedTextColor
        )
    }

    // MARK: - "Smart slicing" helpers for large image blocks

    private func bestImageBreakRow(in image: CGImage, near preferredRow: Int) -> Int {
        let sampleWidth = max(16, min(128, image.width))
        let sampleHeight = max(8, min(1024, image.height))
        guard let sampled = downsample(image: image, width: sampleWidth, height: sampleHeight) else {
            return preferredRow
        }

        let preferredSampleRow = Int(
            (CGFloat(preferredRow) / CGFloat(max(1, image.height - 1))) * CGFloat(max(0, sampleHeight - 1))
        )
        let searchRadius = min(120, max(20, sampleHeight / 15))
        let minRow = max(1, preferredSampleRow - searchRadius)
        let maxRow = min(sampleHeight - 1, preferredSampleRow + searchRadius)

        var bestRow = preferredSampleRow
        var lowestInkRatio = CGFloat.greatestFiniteMagnitude

        for row in minRow...maxRow {
            let inkRatio = rowInkRatio(in: sampled, sampleWidth: sampleWidth, row: row)
            if inkRatio < lowestInkRatio {
                lowestInkRatio = inkRatio
                bestRow = row
            }
        }

        return Int((CGFloat(bestRow) / CGFloat(max(1, sampleHeight - 1))) * CGFloat(max(1, image.height - 1)))
    }

    private func imageHasMeaningfulContent(_ image: CGImage) -> Bool {
        let sampleWidth = max(16, min(96, image.width))
        let sampleHeight = max(16, min(512, image.height))
        guard let sampled = downsample(image: image, width: sampleWidth, height: sampleHeight) else {
            return true
        }

        let data = sampled.data
        let bytesPerRow = sampled.bytesPerRow
        let threshold: UInt8 = 244
        var nonWhiteCount = 0
        let totalPixels = sampleWidth * sampleHeight

        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for y in 0..<sampleHeight {
                for x in 0..<sampleWidth {
                    let offset = y * bytesPerRow + x * 4
                    let r = ptr[offset]
                    let g = ptr[offset + 1]
                    let b = ptr[offset + 2]
                    if r < threshold || g < threshold || b < threshold {
                        nonWhiteCount += 1
                    }
                }
            }
        }
        return (CGFloat(nonWhiteCount) / CGFloat(totalPixels)) > 0.006
    }

    private func rowInkRatio(in sampled: SampledImage, sampleWidth: Int, row: Int) -> CGFloat {
        let clampedRow = max(0, min(sampled.height - 1, row))
        let data = sampled.data
        let bytesPerRow = sampled.bytesPerRow
        let threshold: UInt8 = 244
        var inkPixels = 0

        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for x in 0..<sampleWidth {
                let offset = clampedRow * bytesPerRow + x * 4
                let r = ptr[offset]
                let g = ptr[offset + 1]
                let b = ptr[offset + 2]
                if r < threshold || g < threshold || b < threshold {
                    inkPixels += 1
                }
            }
        }
        return CGFloat(inkPixels) / CGFloat(sampleWidth)
    }

    private struct SampledImage {
        let data: Data
        let bytesPerRow: Int
        let height: Int
    }

    private func downsample(image: CGImage, width: Int, height: Int) -> SampledImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rawData = Data(count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        let rendered = rawData.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard rendered else { return nil }
        return SampledImage(data: rawData, bytesPerRow: bytesPerRow, height: height)
    }

    private func hasMeaningfulContent(_ block: RamsPDFBlock) -> Bool {
        switch block.content {
        case .heading(let text, _):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .paragraph(let text, _):
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .keyValueRows(let pairs):
            return !pairs.isEmpty
        case .bulletList(let items):
            return items.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .table(_, _, let rows):
            return !rows.isEmpty
        case .signatureCard(let name, let role, _, let imageData):
            let hasMeta = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasImage = UIImage(data: imageData)?.cgImage != nil
            return hasMeta || hasImage
        case .image(let data, _):
            guard let image = UIImage(data: data)?.cgImage else { return false }
            return imageHasMeaningfulContent(image)
        case .group(_, let children):
            return children.contains(where: hasMeaningfulContent)
        case .spacer(let height):
            return height > 0
        }
    }
}

enum RamsPDFDocumentBuilder {
    static func build(
        master: MasterDocument,
        rams: RamsDocument,
        liftPlan: LiftPlan?,
        signatures: [SignatureRecord]
    ) -> RamsPDFDocument {
        let contentsSection = RamsPDFSection(
            title: "Contents",
            forcePageBreakBefore: false,
            blocks: [
                RamsPDFBlock(content: .bulletList(contentsEntries(includeLiftPlan: liftPlan != nil)))
            ]
        )

        let masterSection = RamsPDFSection(
            title: "Master Document",
            forcePageBreakBefore: true,
            blocks: buildMasterBlocks(master: master)
        )

        let methodSection = RamsPDFSection(
            title: "RAMS Method Statement",
            forcePageBreakBefore: true,
            blocks: buildMethodBlocks(rams: rams)
        )

        let riskSection = RamsPDFSection(
            title: "Risk Assessment Register",
            forcePageBreakBefore: true,
            blocks: buildRiskBlocks(rams: rams)
        )

        var sections = [contentsSection, masterSection, methodSection, riskSection]

        if let liftPlan {
            sections.append(
                RamsPDFSection(
                    title: "Lift Plan",
                    forcePageBreakBefore: true,
                    blocks: buildLiftPlanBlocks(liftPlan: liftPlan)
                )
            )
        }

        let appendixBlocks = buildAppendixBlocks(master: master, liftPlan: liftPlan)
        if !appendixBlocks.isEmpty {
            sections.append(
                RamsPDFSection(
                    title: "Appendices",
                    forcePageBreakBefore: true,
                    blocks: appendixBlocks
                )
            )
        }

        sections.append(
            RamsPDFSection(
                title: "Sign-off",
                forcePageBreakBefore: true,
                blocks: buildSignatureBlocks(signatures: signatures)
            )
        )

        let generatedAt = Date()
        let projectName = master.projectName.ifBlank("Project")
        let reference = rams.referenceCode.ifBlank("RAMS")

        return RamsPDFDocument(
            brandName: "Construction RAMS Builder",
            title: "RAMS Export: \(rams.title.ifBlank("Untitled RAMS"))",
            subtitle: "\(projectName) | \(reference) | Overall risk \(rams.overallRiskReview.rawValue)",
            projectName: projectName,
            referenceCode: reference,
            generatedAt: generatedAt,
            sections: sections
        )
    }

    private static func contentsEntries(includeLiftPlan: Bool) -> [String] {
        var entries = [
            "1. Master Document",
            "2. RAMS Method Statement",
            "3. Risk Assessment Register"
        ]
        if includeLiftPlan {
            entries.append("4. Lift Plan")
            entries.append("5. Appendices")
            entries.append("6. Sign-off")
        } else {
            entries.append("4. Appendices")
            entries.append("5. Sign-off")
        }
        return entries
    }

    private static func buildMasterBlocks(master: MasterDocument) -> [RamsPDFBlock] {
        var blocks: [RamsPDFBlock] = []
        blocks.append(
            RamsPDFBlock(
                content: .keyValueRows([
                    ("Project", master.projectName.ifBlank("-")),
                    ("Site address", master.siteAddress.ifBlank("-")),
                    ("Client", master.clientName.ifBlank("-")),
                    ("Principal contractor", master.principalContractor.ifBlank("-")),
                    ("Emergency contact", "\(master.emergencyContactName.ifBlank("-")) (\(master.emergencyContactPhone.ifBlank("-")))")
                ])
            )
        )

        blocks.append(
            RamsPDFBlock(
                content: .group(
                    title: "Hospital and emergency route",
                    children: [
                        RamsPDFBlock(
                            content: .keyValueRows([
                                ("Nearest hospital", master.nearestHospitalName.ifBlank("-")),
                                ("Hospital address", master.nearestHospitalAddress.ifBlank("-"))
                            ])
                        ),
                        RamsPDFBlock(
                            content: .paragraph(
                                text: master.hospitalDirections.ifBlank("-"),
                                style: .body
                            )
                        )
                    ]
                )
            )
        )

        if !master.keyContacts.isEmpty {
            let rows = master.keyContacts.map { contact in
                [contact.name.ifBlank("-"), contact.role.ifBlank("-"), contact.phone.ifBlank("-")]
            }
            blocks.append(
                RamsPDFBlock(
                    keepTogether: true,
                    content: .table(
                        title: "Key contacts",
                        headers: ["Name", "Role", "Phone"],
                        rows: rows
                    )
                )
            )
        }
        return blocks
    }

    private static func buildMethodBlocks(rams: RamsDocument) -> [RamsPDFBlock] {
        var blocks: [RamsPDFBlock] = [
            RamsPDFBlock(
                content: .keyValueRows([
                    ("RAMS title", rams.title.ifBlank("-")),
                    ("Reference", rams.referenceCode.ifBlank("-")),
                    ("Prepared by", rams.preparedBy.ifBlank("-")),
                    ("Approved by", rams.approvedBy.ifBlank("-")),
                    ("Scope of works", rams.scopeOfWorks.ifBlank("-"))
                ])
            )
        ]

        let methodChildren = rams.methodStatements
            .sorted(by: { $0.sequence < $1.sequence })
            .map { step in
                RamsPDFBlock(
                    keepTogether: true,
                    content: .group(
                        title: "Step \(step.sequence): \(step.title.ifBlank("Untitled"))",
                        children: [
                            RamsPDFBlock(content: .paragraph(text: step.details.ifBlank("-"), style: .body))
                        ]
                    )
                )
            }

        blocks.append(
            RamsPDFBlock(
                content: .group(
                    title: "Method sequence",
                    children: methodChildren
                )
            )
        )
        return blocks
    }

    private static func buildRiskBlocks(rams: RamsDocument) -> [RamsPDFBlock] {
        let registerRows = rams.riskAssessments.map { risk in
            [
                risk.hazardTitle.ifBlank("-"),
                risk.riskTo.ifBlank("-"),
                "\(risk.initialScore)",
                "\(risk.residualScore)",
                "\(risk.overallReview.rawValue) \(risk.overallReview.title)"
            ]
        }

        var blocks: [RamsPDFBlock] = [
            RamsPDFBlock(
                content: .table(
                    title: "Risk register",
                    headers: ["Hazard", "Risk to", "Initial", "Residual", "Review"],
                    rows: registerRows
                )
            ),
            RamsPDFBlock(
                content: .paragraph(
                    text: "Overall Risk Review: \(rams.overallRiskReview.rawValue) \(rams.overallRiskReview.title)",
                    style: .subheading
                )
            )
        ]

        let assessmentGroups = rams.riskAssessments.map { assessment in
            let controlText = assessment.controlMeasures.isEmpty
                ? "-"
                : assessment.controlMeasures.joined(separator: "\n• ")
            return RamsPDFBlock(
                content: .group(
                    title: assessment.hazardTitle.ifBlank("Unnamed hazard"),
                    children: [
                        RamsPDFBlock(
                            content: .keyValueRows([
                                ("Risk to", assessment.riskTo.ifBlank("-")),
                                ("Initial score", "\(assessment.initialScore)"),
                                ("Residual score", "\(assessment.residualScore)"),
                                ("Review", "\(assessment.overallReview.rawValue) \(assessment.overallReview.title)")
                            ])
                        ),
                        RamsPDFBlock(
                            content: .paragraph(
                                text: "Control measures:\n• \(controlText)",
                                style: .body
                            )
                        )
                    ]
                )
            )
        }

        blocks.append(
            RamsPDFBlock(
                content: .group(
                    title: "Detailed hazard breakdown",
                    children: assessmentGroups
                )
            )
        )

        return blocks
    }

    private static func buildLiftPlanBlocks(liftPlan: LiftPlan) -> [RamsPDFBlock] {
        var blocks: [RamsPDFBlock] = []
        blocks.append(
            RamsPDFBlock(
                content: .keyValueRows([
                    ("Title", liftPlan.title.ifBlank("-")),
                    ("Category", liftPlan.category.rawValue),
                    ("Crane / plant", liftPlan.craneOrPlant.ifBlank("-")),
                    ("Load", liftPlan.loadDescription.ifBlank("-")),
                    ("Load weight (kg)", String(format: "%.1f", liftPlan.loadWeightKg)),
                    ("Lift radius (m)", String(format: "%.1f", liftPlan.liftRadiusMeters)),
                    ("Boom length (m)", String(format: "%.1f", liftPlan.boomLengthMeters)),
                    ("Appointed person", liftPlan.appointedPerson.ifBlank("-")),
                    ("Crane supervisor", liftPlan.craneSupervisor.ifBlank("-")),
                    ("Lift operator", liftPlan.liftOperator.ifBlank("-")),
                    ("Slinger/signaller", liftPlan.slingerSignaller.ifBlank("-")),
                    ("Communication", liftPlan.communicationMethod.ifBlank("-"))
                ])
            )
        )

        let liftingAccessories = liftPlan.liftingAccessories.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !liftingAccessories.isEmpty {
            blocks.append(RamsPDFBlock(content: .group(title: "Lifting accessories", children: [
                RamsPDFBlock(content: .bulletList(liftingAccessories))
            ])))
        }

        let sequence = liftPlan.methodSequence.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !sequence.isEmpty {
            blocks.append(RamsPDFBlock(content: .group(title: "Lift sequence", children: [
                RamsPDFBlock(content: .bulletList(sequence))
            ])))
        }

        blocks.append(
            RamsPDFBlock(
                content: .group(
                    title: "Controls and emergency planning",
                    children: [
                        RamsPDFBlock(
                            content: .keyValueRows([
                                ("Setup location", liftPlan.setupLocation.ifBlank("-")),
                                ("Landing location", liftPlan.landingLocation.ifBlank("-")),
                                ("Ground bearing", liftPlan.groundBearingCapacity.ifBlank("-")),
                                ("Weather / wind limits", liftPlan.windLimit.ifBlank("-")),
                                ("Exclusion zone", liftPlan.exclusionZoneDetails.ifBlank("-")),
                                ("Emergency rescue", liftPlan.emergencyRescuePlan.ifBlank("-")),
                                ("Permit refs", liftPlan.permitReferences.ifBlank("-"))
                            ])
                        )
                    ]
                )
            )
        )

        return blocks
    }

    private static func buildAppendixBlocks(master: MasterDocument, liftPlan: LiftPlan?) -> [RamsPDFBlock] {
        var blocks: [RamsPDFBlock] = []

        if let mapData = master.mapImageData {
            blocks.append(
                RamsPDFBlock(
                    keepTogether: false,
                    content: .image(data: mapData, caption: "Appendix A: Site / hospital map")
                )
            )
        }

        if let drawingData = liftPlan?.drawingImageData {
            blocks.append(
                RamsPDFBlock(
                    keepTogether: false,
                    content: .image(data: drawingData, caption: "Appendix B: Lift plan drawing")
                )
            )
        }

        return blocks
    }

    private static func buildSignatureBlocks(signatures: [SignatureRecord]) -> [RamsPDFBlock] {
        if signatures.isEmpty {
            return [RamsPDFBlock(content: .paragraph(text: "No signatures captured.", style: .body))]
        }

        let tableRows = signatures.map {
            [
                $0.signerName.ifBlank("-"),
                $0.signerRole.ifBlank("-"),
                DateFormatter.shortDateTime.string(from: $0.signedAt)
            ]
        }

        var blocks: [RamsPDFBlock] = [
            RamsPDFBlock(
                content: .paragraph(
                    text: "Sign-off confirms RAMS briefing has been completed and controls are understood before work starts.",
                    style: .body
                )
            ),
            RamsPDFBlock(
                keepTogether: true,
                content: .table(
                    title: "Signature register",
                    headers: ["Signer", "Role", "Signed at"],
                    rows: tableRows
                )
            )
        ]

        for signature in signatures {
            blocks.append(
                RamsPDFBlock(
                    keepTogether: true,
                    content: .signatureCard(
                        name: signature.signerName.ifBlank("-"),
                        role: signature.signerRole.ifBlank("-"),
                        signedAt: DateFormatter.shortDateTime.string(from: signature.signedAt),
                        imageData: signature.signatureImageData
                    )
                )
            )
        }
        return blocks
    }
}

private extension String {
    func ifBlank(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
