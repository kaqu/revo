//
//  Environment.swift
//  Revolut
//
//  Created by Kacper Kaliński on 21/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Foundation
import Futura

internal var Current: Environment = .init()

internal struct Environment {
    internal var date: () -> Date = Date.init
    internal var currencyFormatter: (Double) -> String = {
        return { numberFormatter.string(from: $0 as NSNumber) ?? "N/A" }
    }()
    internal var currencyReader: (String) -> Double? = {
        return { numberFormatter.number(from: $0) as? Double }
    }()
    internal var api: API = .init()
    internal var storage: Storage = .init()
    internal var mainWorker: Worker = OperationQueue.main
    internal var backgroundWorker: Worker = OperationQueue()
}

fileprivate let numberFormatter: NumberFormatter = {
    let formatter: NumberFormatter = .init()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 2
    formatter.maximumFractionDigits = 2
    formatter.locale = Locale.autoupdatingCurrent
    return formatter
}()

internal struct API {
    var getRates: (String) -> Future<CurrencyData> = {
        do {
            let request = try CurrencyEndpoint.makeRequest(baseSymbol: $0)
            return URLSession.shared
                .dataTaskFuture(with: request)
                .map { try CurrencyEndpoint.decode(response: $0.response, body: $0.body) }
        } catch {
            return .init(failedWith: error)
        }
    }
}

internal struct Storage {
    var saveCurrencySymbol: (String) -> Void
        = { UserDefaults.standard.set($0, forKey: "initialCurrencySymbol") }
    var loadCurrencySymbol: () -> String
        = { UserDefaults.standard.string(forKey: "initialCurrencySymbol")
            ?? "USD" }
    var saveCurrencyValue: (Double) -> Void
    = { UserDefaults.standard.set($0, forKey: "initialCurrencyValue") }
    var loadCurrencyValue: () -> Double
        = { UserDefaults.standard.object(forKey: "initialCurrencyValue") != nil
            ? UserDefaults.standard.double(forKey: "initialCurrencyValue")
            : 1.0 }
}
