//
//  CurrencyCellView.swift
//  Revolut
//
//  Created by Kacper Kaliński on 21/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Coconut
import UIKit

internal final class CurrencyCellView: UITableViewCell {
    internal let currencyTitle: UILabel = .init()
    internal let currencyValue: UITextField = .init()

    internal init() {
        super.init(style: .default, reuseIdentifier: nil)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    private func setupLayout() {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        currencyValue.textAlignment = .right
        currencyValue.keyboardType = .decimalPad
        contentView.addSubview(currencyTitle)
        contentView.addSubview(currencyValue)

        currencyTitle.translatesAutoresizingMaskIntoConstraints = false
        currencyValue.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            currencyTitle.widthAnchor.constraint(equalToConstant: 80),
            contentView.centerYAnchor.constraint(equalTo: currencyTitle.centerYAnchor),
            contentView.leftAnchor.constraint(equalTo: currencyTitle.leftAnchor, constant: -16),
            contentView.centerYAnchor.constraint(equalTo: currencyValue.centerYAnchor),
            contentView.rightAnchor.constraint(equalTo: currencyValue.rightAnchor, constant: 16),
            currencyValue.leftAnchor.constraint(equalTo: currencyTitle.rightAnchor, constant: 8),
        ])
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard super.hitTest(point, with: event) != nil else { return nil }
        return currencyValue
    }
}

extension SignalProducerAdapter where Subject == CurrencyCellView {
    internal var currencyValue: Signal<Double> {
        return subject.currencyValue.signalOut.textEdit
            .map { Double($0) }
            .filter { $0 != nil }
            .map { $0! }
    }
    
    internal var editing: Signal<Bool> {
        return subject.currencyValue.signalOut.editingChange
    }
    
    internal var activated: Signal<Double> {
        return subject.currencyValue.signalOut.editingChange
            .filter { $0 }
            .map { [unowned subject] _ in Current.currencyReader(subject.currencyValue.text ?? "") }
            .filter { $0 != nil }
            .map { $0! }
    }
}

extension SignalConsumerAdapter where Subject == CurrencyCellView {
    internal var currencyLabelText: Signal<String>? {
        get { fatalError("Unsupported") }
        set {
            subject.currencyTitle.signalIn.text = newValue
        }
    }

    internal var currencyValueText: Signal<String>? {
        get { fatalError("Unsupported") }
        set {
            subject.currencyValue.signalIn.text = newValue
        }
    }
}
