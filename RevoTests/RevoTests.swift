//
//  RevoTests.swift
//  RevoTests
//
//  Created by Kacper Kaliński on 26/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Futura
import XCTest
import SnapshotTesting
@testable import Revo

let testCurrencySymbol: String = "S1"
let testCurrencyValue: Double = 1.0
let testCurrencyData: CurrencyData = .init(base: "S1", rates: ["S2": 1.5])
let testCurrencyRates: [CurrencyRate] = [CurrencyRate(symbol: "S2", value: 1.5)]
let testMergedCurrencyRates: [CurrencyRate] = [CurrencyRate(symbol: "S1", value: 1.0), CurrencyRate(symbol: "S2", value: 1.5)]

class RevoTests: XCTestCase {
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
        XCTAssertEqual(testMergedCurrencyRates, recordedCurrencyRates)
    }
    
    func test_viewSnapshot() {
        let dataFlowController: DataFlowController = .init(updatesTimer: testTimerEmitter)
        let viewController: ViewController = .init(dataFlowController: dataFlowController)
        
        viewController.loadView()
        
        dataFlowController.loadInitialData()
        testTimerEmitter.emit()
        
        while !testMainWorker.isEmpty || !testBackgroundWorker.isEmpty {
            testMainWorker.execute()
            testBackgroundWorker.execute()
        }
        
        // you may think about this as a bug - time emitter must emmit twice to update value labels
        // it might be fixed in future
        testTimerEmitter.emit()

        while !testMainWorker.isEmpty || !testBackgroundWorker.isEmpty {
            testMainWorker.execute()
            testBackgroundWorker.execute()
        }
        
        assertSnapshot(matching: viewController, as: .image(on: .iPhoneX))
        assertSnapshot(matching: viewController, as: .image(on: .iPhone8))
        assertSnapshot(matching: viewController, as: .image(on: .iPhoneSe))
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

