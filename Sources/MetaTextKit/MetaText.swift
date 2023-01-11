//
//  MetaText.swift
//
//
//  Created by MainasuK Cirno on 2021-6-7.
//

import UIKit
import Meta
import AVFoundation
public protocol MetaTextDelegate: AnyObject {
    func metaText(_ metaText: MetaText, processEditing textStorage: MetaTextStorage) -> MetaContent?
}

public class MetaText: NSObject {

    public weak var delegate: MetaTextDelegate?

    public let textStorage: MetaTextStorage
    public let textView: MetaTextView

    static var fontSize: CGFloat = 17

    public var paragraphStyle: NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = 8
        return style
    }()

    public var textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: MetaText.fontSize, weight: .regular)),
        .foregroundColor: UIColor.label,
    ]

    public var linkAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: MetaText.fontSize, weight: .semibold)),
        .foregroundColor: UIColor.link,
    ]
    
    public override init() {
        let textStorage = MetaTextStorage()
        self.textStorage = textStorage
        
        let textContentStorage = NSTextContentStorage()
        textContentStorage.textStorage = textStorage

        let textLayoutManager = NSTextLayoutManager()
        textContentStorage.addTextLayoutManager(textLayoutManager)
        
        let textContainer = NSTextContainer(size: .zero)
        textLayoutManager.textContainer = textContainer

        textView = MetaTextView(frame: .zero, textContainer: textContainer)

        super.init()

        textStorage.processDelegate = self
    }
    
}

extension MetaText {

    public var backedString: String {
        let string = textStorage.string
        let nsString = NSMutableString(string: string)
        textStorage.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: textStorage.length),
            options: [.reverse])
        { value, range, _ in
            guard let attachment = value as? MetaAttachment else { return }
            nsString.replaceCharacters(in: range, with: attachment.string)
        }
        return nsString as String
    }

}

extension MetaText {

    public func configure(content: MetaContent) {
        let attributedString = NSMutableAttributedString(string: content.string)

        MetaText.setAttributes(
            for: attributedString,
            textAttributes: textAttributes,
            linkAttributes: linkAttributes,
            paragraphStyle: paragraphStyle,
            content: content
        )

        textView.linkTextAttributes = linkAttributes
        textView.attributedText = attributedString
    }

    public func reset() {
        let attributedString = NSAttributedString(string: "")
        textView.attributedText = attributedString
    }

}

// MARK: - MetaTextStorageDelegate
extension MetaText: MetaTextStorageDelegate {
    public func processEditing(_ textStorage: MetaTextStorage) -> MetaContent? {
        guard let content = delegate?.metaText(self, processEditing: textStorage) else { return nil }

        // configure meta
        textStorage.beginEditing()
        MetaText.setAttributes(
            for: textStorage,
            textAttributes: textAttributes,
            linkAttributes: linkAttributes,
            paragraphStyle: paragraphStyle,
            content: content
        )
        textStorage.endEditing()

        return content
    }
}

extension MetaText {

    @discardableResult
    public static func setAttributes(
        for attributedString: NSMutableAttributedString,
        textAttributes: [NSAttributedString.Key: Any],
        linkAttributes: [NSAttributedString.Key: Any],
        paragraphStyle: NSMutableParagraphStyle,
        content: MetaContent
    ) -> [MetaAttachment] {

        // clean up
        var allRange = NSRange(location: 0, length: attributedString.length)
        for key in textAttributes.keys {
            attributedString.removeAttribute(key, range: allRange)
        }
        for key in linkAttributes.keys {
            attributedString.removeAttribute(key, range: allRange)
        }
        attributedString.removeAttribute(.meta, range: allRange)
        attributedString.removeAttribute(.paragraphStyle, range: allRange)

        // text
        attributedString.addAttributes(
            textAttributes,
            range: NSRange(location: 0, length: attributedString.length)
        )

        // meta
        let stringRange = NSRange(location: 0, length: attributedString.length)
        for entity in content.entities {
            var linkAttributes = linkAttributes
            linkAttributes[.meta] = entity.meta
            // FIXME: the emoji make cause wrong entity range out of bounds
            // workaround: use intersection range temporary
            let range = NSIntersectionRange(stringRange, entity.range)
            attributedString.addAttributes(linkAttributes, range: range)
        }

        // attachment
        var replacedAttachments: [MetaAttachment] = []
        for entity in content.entities.reversed() {
            guard let attachment = content.metaAttachment(for: entity) else { continue }
            replacedAttachments.append(attachment)

            let font = attributedString.attribute(.font, at: entity.range.location, effectiveRange: nil) as? UIFont
            let fontSize = font?.pointSize ?? MetaText.fontSize
            if #available(iOS 16, *) {
                attachment.contentFrame = CGRect(
                    origin: .zero,
                    size: CGSize(width: fontSize, height: fontSize)
                )
            } else {
                attachment.bounds = CGRect(
                    origin: .zero,
                    size: CGSize(width: fontSize, height: fontSize)
                )
            }
            attributedString.replaceCharacters(in: entity.range, with: NSAttributedString(attachment: attachment))
        }
        allRange = NSRange(location: 0, length: attributedString.length)
        
        // paragraph
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: allRange)

        return replacedAttachments
    }

}
