//
//  CurrencyEndpoint.swift
//  Revolut
//
//  Created by Kacper Kaliński on 21/01/2019.
//  Copyright © 2019 Kacper Kaliński. All rights reserved.
//

import Foundation

fileprivate let jsonDecoder: JSONDecoder = .init()
internal struct CurrencyData: Equatable, Decodable {
    internal let base: String
    internal let rates: [String: Double]
}

internal struct CurrencyRate: Equatable {
    internal let symbol: String
    internal let value: Double
}

internal enum CurrencyEndpoint {
    
    internal static func makeRequest(baseSymbol currencySymbol: String) throws -> URLRequest {
        guard let url = URL(string: "https://revolut.duckdns.org/latest?base=\(currencySymbol)") else {
            throw EndpointError.invalidRequest
        }
        return .init(url: url) // default is GET
    }
    
    internal static func decode(response: URLResponse, body: Data?) throws -> CurrencyData {
        guard let response = response as? HTTPURLResponse else { throw EndpointError.invalidResponse }
        guard response.statusCode == 200 else { throw EndpointError.error(code: response.statusCode) }
        guard let body = body else { throw EndpointError.missingData }
        return try jsonDecoder.decode(CurrencyData.self, from: body)
    }
}

internal enum EndpointError: Error {
    case invalidRequest
    case invalidResponse
    case missingData
    case error(code: Int)
}
