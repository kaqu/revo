//
//  DataFlowController.swift
//  Revolut
//
//  Created by Kacper Kaliński on 21/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Coconut
import Foundation

public final class DataFlowController {
    internal var initialLoadFuture: Future<Void> { return initialLoadPromise.future }
    internal let baseCurrencySymbol: Emitter<String> = .init()
    internal let baseCurrencyValue: Emitter<Double> = .init()
    internal let currentRates: Signal<[CurrencyRate]>
    internal let tableDataSource: TableViewDataSource<Currency>
    private let updatesTimer: Signal<Void>
    private let initialLoadPromise: Promise<Void> = .init()

    public init(updatesTimer: Signal<Void> = TimedEmitter(interval: 1)) {
        self.updatesTimer = updatesTimer
        self.tableDataSource = .init(updatesWorker: Current.backgroundWorker, elementMatch: { $0.symbol == $1.symbol }) { model, _ in
            model.cellView
        }
        self.currentRates =
            baseCurrencySymbol
            .filterDuplicates()
            .flatMapLatest { symbol in
                updatesTimer.map { symbol }
            }
            .flatMapFuture { (currencySymbol) -> Future<CurrencyData> in
                Current.api.getRates(currencySymbol)
            }
            .map { data in
                var rates =
                    data.rates
                    .map { key, value in
                        CurrencyRate(symbol: key, value: value)
                    }
                if !rates.contains { $0.symbol == data.base } {
                    rates.insert(CurrencyRate(symbol: data.base, value: 1), at: 0)
                } else { /* continue */ }
                return rates
            }

        baseCurrencySymbol
            .filterDuplicates()
            .flatMapLatest { [unowned self] baseSymbol in
                self.currentRates
                    .map { [unowned self] rates -> (insert: [Currency], delete: [String]) in
                        let insertCurrencies: [Currency] =
                            rates
                            .filter { rate in
                                !self.tableDataSource.model[0]
                                    .contains { $0.symbol == rate.symbol }
                            }
                            .map { rate -> Currency in
                                let cell = Currency(symbol: rate.symbol)

                                cell.signalIn.baseValue =
                                    cell.signalOut.active.flatMapLatest { active in
                                        guard !active else {
                                            return .never
                                        }
                                        return self.baseCurrencyValue
                                    }
                                cell.signalIn.rate =
                                    cell.signalOut.active.flatMapLatest { active in
                                        guard !active else {
                                            return .never
                                        }
                                        return self.currentRates
                                            .collect(with: cell.collector)
                                            .map { $0.first { $0.symbol == rate.symbol } }
                                            .filter { $0 != nil }
                                            .map { $0!.value }
                                    }
                                cell.signalOut.activated
                                    .values { value in
                                        guard let index = self.tableDataSource.model[0].firstIndex(where: { $0.symbol == rate.symbol }) else { return }
                                        self.baseCurrencySymbol.emit(rate.symbol)
                                        self.baseCurrencyValue.emit(value)
                                        self.tableDataSource.move(from: .init(row: index, section: 0), to: .init(row: 0, section: 0))
                                    }
                                cell.signalOut.value
                                    .values { [unowned self] value in
                                        self.baseCurrencyValue.emit(value)
                                    }
                                cell.setupCompleted()
                                return cell
                            }
                        let deleteCurrenciesSymbols: [String] =
                            self.tableDataSource.model[0]
                            .filter { model in
                                !rates
                                    .contains { $0.symbol == model.symbol }
                                    && model.symbol != baseSymbol
                            }.map {
                                $0.symbol
                            }
                        return (insert: insertCurrencies, delete: deleteCurrenciesSymbols)
                    }
            }
            .values { [unowned self] insert, delete in
                self.tableDataSource.model[0].removeAll { delete.contains($0.symbol) }
                self.tableDataSource.model[0].append(contentsOf: insert)
                self.initialLoadPromise.fulfill(with: ())
            }
            .errors {
                print("Error: \($0)")
            }

        baseCurrencySymbol
            .filterDuplicates()
            .switch(to: Current.backgroundWorker)
            .values { symbol in
                Current.storage.saveCurrencySymbol(symbol)
            }
        baseCurrencyValue
            .filterDuplicates()
            .switch(to: Current.backgroundWorker)
            .values { value in
                Current.storage.saveCurrencyValue(value)
            }
    }

    internal func loadInitialData() {
        let initialCurrencySymbol: String
            = Current.storage.loadCurrencySymbol()
        let initialCurrencyValue: Double
            = Current.storage.loadCurrencyValue()

        baseCurrencySymbol.emit(initialCurrencySymbol)

        initialLoadFuture
            .value { _ in
                self.baseCurrencyValue.emit(initialCurrencyValue)
            }
    }
}
