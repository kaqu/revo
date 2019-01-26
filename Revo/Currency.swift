//
//  Currency.swift
//  Revolut
//
//  Created by Kacper Kaliński on 19/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Coconut
import Foundation

internal final class Currency: SignalConsumer, SignalProducer {
    internal private(set) lazy var signalIn: SignalConsumerAdapter<Currency> = .init(subject: self)
    internal private(set) lazy var signalOut: SignalProducerAdapter<Currency> = .init(subject: self)

    internal let symbol: String
    internal let cellView: CurrencyCellView
    internal let collector: SubscriptionCollector = .init()

    fileprivate let setupCompleteEmitter: Emitter<Void> = .init()
    fileprivate let rateEmitter: Emitter<Double> = .init()
    fileprivate var rateEmitterCollector: SubscriptionCollector = .init()
    fileprivate let baseValueEmitter: Emitter<Double> = .init()
    fileprivate var baseValueEmitterCollector: SubscriptionCollector = .init()

    internal init(symbol: String) {
        let cellView: CurrencyCellView = .init()
        cellView.currencyTitle.text = symbol

        self.symbol = symbol
        self.cellView = cellView
        cellView.signalIn.currencyValueText =
            merge(rateEmitter
                .flatMapLatest { [unowned self] (rate) -> Signal<String> in
                    self.baseValueEmitter
                        .map { Current.currencyFormatter(rate * $0) }
                },
                  baseValueEmitter
                    .flatMapLatest { [unowned self] (value) -> Signal<String> in
                        self.rateEmitter
                            .map { Current.currencyFormatter(value * $0) }
            })
            .switch(to: Current.mainWorker)
    }

    internal func setupCompleted() {
        setupCompleteEmitter.emit()
    }
}

extension SignalProducerAdapter where Subject == Currency {
    internal var value: Signal<Double> {
        return subject.cellView.signalOut.currencyValue
    }

    internal var active: Signal<Bool> {
        return merge(subject.cellView.signalOut.editing, subject.setupCompleteEmitter.map { _ in false })
    }

    internal var activated: Signal<Double> {
        return subject.cellView.signalOut.activated
    }
}

extension SignalConsumerAdapter where Subject == Currency {
    internal var rate: Signal<Double> {
        get { fatalError("Unsupported") }
        set {
            subject.rateEmitterCollector = .init()
            newValue.collect(with: subject.rateEmitterCollector)
                .values { [weak subject] value in
                    subject?.rateEmitter.emit(value)
                }
        }
    }

    internal var baseValue: Signal<Double> {
        get { fatalError("Unsupported") }
        set {
            subject.baseValueEmitterCollector = .init()
            newValue
                .collect(with: subject.baseValueEmitterCollector)
                .values { [weak subject] value in
                    subject?.baseValueEmitter.emit(value)
                }
        }
    }
}
