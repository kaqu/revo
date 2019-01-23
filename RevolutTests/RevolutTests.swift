//
//  RevolutTests.swift
//  RevolutTests
//
//  Created by Kacper Kaliński on 19/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Futura
@testable import Revolut
import XCTest

let testCurrencySymbol: String = "S"
let testCurrencyValue: Double = 1
let testCurrencyData: CurrencyData = .init(base: "S", rates: ["A": 1.5, "B": 0.5])
let testCurrencyRates: [CurrencyRate] = [CurrencyRate(symbol: "A", value: 1.5), CurrencyRate(symbol: "B", value: 0.5)]

class RevolutTests: XCTestCase {
    let setupOnce: Void = {
        Current.storage.loadCurrencySymbol = { testCurrencySymbol }
        Current.storage.loadCurrencyValue = { testCurrencyValue }
        Current.api.getRates = { _ in .init(succeededWith: testCurrencyData) }
    }()

    var testMainWorker: TestWorker = .init()
    var testBackgroundWorker: TestWorker = .init()
    var testTimerEmitter: Emitter<Void> = .init()

    override func setUp() {
        _ = setupOnce
        testMainWorker = .init()
        testBackgroundWorker = .init()
        testTimerEmitter = .init()
        Current.mainWorker = testMainWorker
        Current.backgroundWorker = testBackgroundWorker
    }

    override func tearDown() {
        assert(testMainWorker.isEmpty)
        assert(testBackgroundWorker.isEmpty)
    }

    func test_dataFlow() {
        let dataFlowController: DataFlowController = .init(updatesTimer: testTimerEmitter)
        var initialized: Bool = false
        var recordedCurrencySymbol: String?
        var recordedCurrencyValue: Double?
        var recordedCurrencyRates: [CurrencyRate]?

        dataFlowController.initialLoadFuture
            .always {
                initialized = true
            }
        dataFlowController.currentRates
            .values {
                recordedCurrencyRates = $0
            }
        dataFlowController.baseCurrencySymbol
            .values {
                recordedCurrencySymbol = $0
            }
        dataFlowController.baseCurrencyValue
            .values {
                recordedCurrencyValue = $0
            }

        dataFlowController.loadInitialData()
        testTimerEmitter.emit()

        while !testMainWorker.isEmpty || !testBackgroundWorker.isEmpty {
            testMainWorker.execute()
            testBackgroundWorker.execute()
        }

        XCTAssertTrue(initialized)
        XCTAssertEqual(testCurrencySymbol, recordedCurrencySymbol)
        XCTAssertEqual(testCurrencyValue, recordedCurrencyValue)
        XCTAssertEqual(testCurrencyRates, recordedCurrencyRates)
    }
}

class TestWorker: Worker {
    private let lock: RecursiveLock = .init()
    private var scheduled: [() -> Void] = []

    func schedule(_ work: @escaping () -> Void) {
        lock.synchronized {
            scheduled.append(work)
        }
    }

    @discardableResult
    func execute() -> Int {
        return lock.synchronized {
            var count: Int = 0
            while executeFirst() { count += 1 }
            return count
        }
    }

    @discardableResult
    func executeFirst() -> Bool {
        return lock.synchronized {
            guard scheduled.count > 0 else { return false }
            scheduled.removeFirst()()
            return true
        }
    }

    var isEmpty: Bool {
        return lock.synchronized { scheduled.count == 0 }
    }
}
