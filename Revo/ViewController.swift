//
//  ViewController.swift
//  Revolut
//
//  Created by Kacper Kaliński on 19/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Coconut
import UIKit

public class ViewController: UIViewController {
    private let dataFlowController: DataFlowController
    
    public init(dataFlowController: DataFlowController = .init()) {
        self.dataFlowController = dataFlowController
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }
    
    override public func loadView() {
        let tableView: UITableView = .init()
        tableView.allowsSelection = false
        dataFlowController.tableDataSource.setup(tableView: tableView)
        self.view = tableView
        dataFlowController.initialLoadFuture
            .value { _ in
                self.dataFlowController
                    .baseCurrencySymbol
                    .filterDuplicates()
                    .switch(to: Current.mainWorker)
                    .values { _ in
                        guard tableView.numberOfSections > 0 else { return }
                        guard tableView.numberOfRows(inSection: 0) > 0 else { return }
                        tableView.scrollToRow(at: .init(row: 0, section: 0), at: .bottom, animated: true)
                    }
            }
            .error {
                print("Present error: \($0)")
            }
        dataFlowController.loadInitialData()
    }
}
