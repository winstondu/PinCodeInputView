//
//  PinCodeInputView.swift
//  PinCodeInputView
//
//  Created by Jinsei Shima on 2018/11/06.
//  Copyright © 2018 Jinsei Shima. All rights reserved.
//

import UIKit

@IBDesignable
public class PinCodeInputView<T: UIView & ItemType>: UIControl, UITextInputTraits {
    
    // MARK: - Properties
    
    private(set) public var text: String = "" {
        didSet {
            if let handler = changeTextHandler {
                handler(text)
            }
            updateText()
        }
    }
    
    public var isEmpty: Bool {
        return text.isEmpty
    }
    
    public var isFilled: Bool {
        return text.count == digit
    }

    override public var intrinsicContentSize: CGSize {
        return stackView.bounds.size
    }

    private let digit: Int
    private let itemSpacing: CGFloat
    private var changeTextHandler: ((String) -> Void)? = nil
    private let stackView: UIStackView = .init()
    private var items: [ContainerItemView<T>] = []
    private let itemFactory: () -> UIView
    private var appearance: ItemAppearance?
	private let autoResizes: Bool

    // MARK: - UITextInputTraits
    
    private lazy var _textField = UITextField(frame: bounds)

    public var autocapitalizationType = UITextAutocapitalizationType.none
    public var autocorrectionType = UITextAutocorrectionType.no
    public var spellCheckingType = UITextSpellCheckingType.no
    public var keyboardType = UIKeyboardType.numberPad
    public var keyboardAppearance = UIKeyboardAppearance.default
    public var returnKeyType = UIReturnKeyType.done
    public var enablesReturnKeyAutomatically = true
    public var textContentType: UITextContentType! = { () -> UITextContentType? in
        if #available(iOS 12, *) {
            return UITextContentType.oneTimeCode
        } else {
            return nil
        }
    }()

    // MARK: - Initializers
    
    public init(
        digit: Int,
        itemSpacing: CGFloat,
        itemFactory: @escaping (() -> T),
		autoresizes: Bool = false) {
        
        self.digit = digit
        self.itemSpacing = itemSpacing
        self.itemFactory = itemFactory
        self.autoResizes = autoresizes
        super.init(frame: .zero)
        
        self.items = (0..<digit).map { _ in
            let item = ContainerItemView(itemView: itemFactory())
            item.setHandler {
                self.showCursor()
                self.becomeFirstResponder()
            }
            return item
        }
        self.stackView.frame = self.bounds
        addSubview(stackView)
        setupTextField()
        
        items.forEach { stackView.addArrangedSubview($0) }
        stackView.spacing = itemSpacing
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
    }
    
    private func setupTextField() {
        
        _textField.keyboardType = keyboardType
        _textField.autocapitalizationType = autocapitalizationType
        _textField.keyboardAppearance = keyboardAppearance
        _textField.isHidden = true
        _textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        _textField.addTarget(self, action: #selector(self.onTextChanged(_:)), for: .editingChanged)
        
        if #available(iOS 12.0, *) { _textField.textContentType = .oneTimeCode }
        
        addSubview(_textField)
        _textField.alpha = 0
    }
    
    @objc private func onTextChanged(_ sender: UITextField) {
        self.text = sender.text ?? ""
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Functions

    override public func layoutSubviews() {
        super.layoutSubviews()
        
        guard let appearance = appearance else {
            stackView.frame = bounds
            return
        }
        
        stackView.bounds = CGRect(
            x: 0,
            y: 0,
            width: (appearance.itemSize.width * CGFloat(digit)) + (itemSpacing * CGFloat(digit - 1)),
            height: appearance.itemSize.height
        )
        stackView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    }

    public func set(text: String, shouldValidate: Bool = true) {
        guard shouldValidate else {
            self.text = text
            return
        }
        if Validator.isPinCode(text: text, digit: digit) {
            self.text = text
        }
    }

    public func set(changeTextHandler: @escaping (String) -> ()) {
        self.changeTextHandler = changeTextHandler
    }
    
    public func set(appearance: ItemAppearance) {
        self.appearance = appearance
		if autoResizes {
			self.appearance = ItemAppearance(itemSize: CGSize(width: (self.bounds.width - (self.itemSpacing * CGFloat(self.digit))) / CGFloat(self.digit), height: appearance.itemSize.height), font: appearance.font, textColor: appearance.textColor, backgroundColor: appearance.backgroundColor, cursorColor: appearance.cursorColor, cornerRadius: appearance.cornerRadius, borderColor: appearance.borderColor)
		}
        items.forEach { $0.itemView.set(appearance: appearance) }
    }
    
    private func updateText() {
        
        items.enumerated().forEach { (index, item) in
            if (0..<text.count).contains(index) {
                let _index = text.index(text.startIndex, offsetBy: index)
                item.itemView.text = text[_index]
            } else {
                item.itemView.text = nil
            }
        }
        
        showCursor()
    }
    
    private func showCursor() {
        
        let cursorPosition = text.count
        
        items.enumerated().forEach { (arg) in
            
            let (index, item) = arg
            item.itemView.isHiddenCursor = (index == cursorPosition) ? false : true
        }
    }
    
    private func hiddenCursor() {
        
        items.forEach { $0.itemView.isHiddenCursor = true }
    }
    
//    // MARK: - UIKeyInput
//
//    public func insertText(_ textToInsert: String) {
//        if isEnabled && text.count + textToInsert.count <= digit && Validator.isOnlyNumeric(text: textToInsert) {
//            text.append(textToInsert)
//            sendActions(for: .editingChanged)
//        }
//    }
//
//    public func deleteBackward() {
//        if isEnabled && !text.isEmpty {
//            text.removeLast()
//            sendActions(for: .editingChanged)
//        }
//    }

    // MARK: - UIResponder
    
    @discardableResult
    override public func becomeFirstResponder() -> Bool {
        showCursor()
        return _textField.becomeFirstResponder()
    }
    
    override public var canBecomeFirstResponder: Bool {
        return true
    }

    @discardableResult
    override public func resignFirstResponder() -> Bool {
        hiddenCursor()
        return _textField.resignFirstResponder()
    }
 
    // MARK: - private class

    private class ContainerItemView<T: UIView & ItemType>: UIView {
        
        var itemView: T
        private let surfaceView: UIView = .init()
        private var didTapHandler: (() -> ())?
        
        init(itemView: T) {
            
            self.itemView = itemView
            
            super.init(frame: .zero)
            
            addSubview(itemView)
            addSubview(surfaceView)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
            surfaceView.addGestureRecognizer(tapGesture)
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            itemView.frame = bounds
            surfaceView.frame = bounds
        }
        
        func setHandler(handler: @escaping () -> ()) {
            didTapHandler = handler
        }
        
        @objc private func didTap() {
            if let handler = didTapHandler {
                handler()
            }
        }
    }
    
}
