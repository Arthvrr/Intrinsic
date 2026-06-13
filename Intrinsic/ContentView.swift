import SwiftUI
import Charts
internal import UniformTypeIdentifiers

// MARK: - 0. CACHE MANAGER (Actor)
actor DataCacheManager {
    static let shared = DataCacheManager()
    private init() {}
    
    struct CacheEntry<T: Codable>: Codable {
        let timestamp: Date
        let data: T
    }
    
    let cacheValidity: TimeInterval = 86400
    
    func save<T: Codable>(_ data: T, forKey key: String) {
        let entry = CacheEntry(timestamp: Date(), data: data)
        if let encoded = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(encoded, forKey: "cache_\(key)")
        }
    }
    
    func load<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: "cache_\(key)") else { return nil }
        guard let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) else { return nil }
        
        if Date().timeIntervalSince(entry.timestamp) > cacheValidity {
            UserDefaults.standard.removeObject(forKey: "cache_\(key)")
            return nil
        }
        return entry.data
    }
}

// MARK: - 1. MODELS (DTOs)

struct FinnhubQuote: Codable, Sendable {
    let c: Double
}

struct FinnhubMetricResponse: Codable, Sendable {
    let metric: FinnhubMetricData
    let series: FinnhubSeries?
}

struct FinnhubSeries: Codable, Sendable {
    let annual: FinnhubSeriesAnnual?
}

struct FinnhubSeriesAnnual: Codable, Sendable {
    let pe: [FinnhubSeriesDataPoint]?
    let freeCashFlow: [FinnhubSeriesDataPoint]?

    private enum CodingKeys: String, CodingKey {
        case pe
        case freeCashFlow
    }
}

struct FinnhubSeriesDataPoint: Codable, Sendable {
    let period: String?
    let v: Double?
}

struct FinnhubRecommendation: Codable, Identifiable, Sendable {
    let id = UUID()
    let buy: Int
    let hold: Int
    let period: String
    let sell: Int
    let strongBuy: Int
    let strongSell: Int
    let symbol: String

    private enum CodingKeys: String, CodingKey {
        case buy, hold, period, sell, strongBuy, strongSell, symbol
    }
}

struct ExchangeRateResponse: Codable, Sendable {
    let conversion_rates: [String: Double]
    let result: String
}

struct FinnhubMetricData: Codable, Sendable {
    let cashAndEquivalentsAnnual: Double?
    let totalDebtAnnual: Double?
    let freeCashFlowTTM: Double?
    let peTTM: Double?
    let yearHigh: Double?
    let beta: Double?
    let pfcfShareTTM: Double?
    let cashPerSharePerShareAnnual: Double?
    let bookValuePerShareAnnual: Double?
    let totalDebtToEquityAnnual: Double?
    let roiTTM: Double?
    private enum CodingKeys: String, CodingKey {
        case cashAndEquivalentsAnnual
        case totalDebtAnnual
        case freeCashFlowTTM
        case peTTM
        case yearHigh = "52WeekHigh"
        case beta, pfcfShareTTM, cashPerSharePerShareAnnual, bookValuePerShareAnnual
        case totalDebtToEquityAnnual = "totalDebt/totalEquityAnnual"
        case roiTTM
    }
}

struct FinnhubProfile: Codable, Sendable {
    let shareOutstanding: Double?
    let currency: String?
    let ticker: String?
    let exchange: String?
    let name: String?
    let logo: String?
}

struct FinnhubPriceTarget: Codable, Sendable {
    let targetHigh: Double?
    let targetLow: Double?
    let targetMean: Double?
    let targetMedian: Double?
    let lastUpdated: String?
}

struct FinnhubEarnings: Codable, Identifiable, Sendable {
    let id = UUID()
    let actual: Double?
    let estimate: Double?
    let period: String?
    let surprise: Double?
    let surprisePercent: Double?

    private enum CodingKeys: String, CodingKey {
        case actual, estimate, period, surprise, surprisePercent
    }
}

struct FCFHistoryPoint: Identifiable, Sendable, Codable {
    var id = UUID()
    let year: String
    let value: Double
    
    private enum CodingKeys: String, CodingKey {
        case year, value
    }
}

struct FinnhubInsiderResponse: Codable, Sendable {
    let data: [FinnhubInsiderTransaction]?
}

struct FinnhubInsiderTransaction: Codable, Identifiable, Sendable {
    let id = UUID()
    let change: Int?
    let transactionDate: String?
    let name: String?
    let share: Int?
    let transactionPrice: Double?
    
    private enum CodingKeys: String, CodingKey {
        case change, transactionDate, name, share, transactionPrice
    }
}

// MARK: - 2. APP MODELS (UI)

struct ProjectionPoint: Identifiable {
    let id = UUID()
    let year: Int
    let value: Double
}

struct PEDataPoint: Identifiable {
    let id = UUID()
    let type: String
    let value: Double
    let color: Color
}

struct PeerData: Identifiable, Sendable, Codable {
    var id = UUID()
    let ticker: String
    let pe: Double
    
    private enum CodingKeys: String, CodingKey {
        case ticker, pe
    }
}

struct RecChartItem: Identifiable {
    let id = UUID()
    let period: String
    let type: String
    let value: Int
    let color: Color
    let order: Int
}

struct ScenarioResult: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

struct InsiderChartItem: Identifiable {
    let id = UUID()
    let date: Date
    let dateString: String
    let type: String
    let shares: Int
    let color: Color
}

struct MonteCarloResult: Identifiable {
    let id = UUID()
    let bucketMin: Double
    let bucketMax: Double
    let frequency: Int
}

// MARK: - History & Compare Models
struct AnalysisHistoryEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let ticker: String
    let stockName: String
    let currentPrice: Double
    let intrinsicValue: Double
    let growthRate: Double
    let discountRate: Double
    let exitMultiple: Double
    let currencySymbol: String
    let fcfCagrDisplay: String?
    var mosPercent: Double { guard currentPrice > 0, intrinsicValue > 0 else { return 0 }; return ((intrinsicValue - currentPrice) / intrinsicValue) * 100 }
    private enum CodingKeys: String, CodingKey { case id, date, ticker, stockName, currentPrice, intrinsicValue, growthRate, discountRate, exitMultiple, currencySymbol, fcfCagrDisplay }
}

struct CompareSnapshot: Identifiable {
    let id = UUID()
    let ticker: String
    let stockName: String
    let currentPrice: Double
    let intrinsicValue: Double
    let growthRate: Double
    let discountRate: Double
    let exitMultiple: Double
    let fcfInput: String
    let cashInput: String
    let debtInput: String
    let currentPEInput: String
    let currencySymbol: String
    let betaInput: Double?
    let fcfCagrDisplay: String?
    let scenarioResults: [ScenarioResult]
    let projectionYears: Int
    var mosPercent: Double { guard currentPrice > 0, intrinsicValue > 0 else { return 0 }; return ((intrinsicValue - currentPrice) / intrinsicValue) * 100 }
}

struct RevenuePoint: Identifiable, Sendable, Codable {
    var id = UUID()
    let year: String
    let revenue: Double   // USD millions
    let netMargin: Double // percentage 0-100
    private enum CodingKeys: String, CodingKey { case year, revenue, netMargin }
}

struct FinnhubFinancials: Codable, Sendable {
    let data: [FinnhubFinancialReport]?
}
struct FinnhubFinancialReport: Codable, Sendable {
    let year: Int?
    let report: FinnhubReportDetail?
}
struct FinnhubReportDetail: Codable, Sendable {
    let ic: [FinnhubLineItem]?
}
struct FinnhubLineItem: Codable, Sendable {
    let concept: String?
    let value: Double?
    let label: String?
}

// NEW: Candle data for RSI + Bollinger Bands
struct FinnhubCandles: Codable, Sendable {
    let c: [Double]?   // close prices
    let h: [Double]?   // high
    let l: [Double]?   // low
    let o: [Double]?   // open
    let t: [Int]?      // timestamps
    let v: [Double]?   // volume
    let s: String?     // status
}

// NEW: Basic financials for ROIC/WACC
struct ROICPoint: Identifiable, Sendable, Codable {
    var id = UUID()
    let year: String
    let roic: Double   // %
    let wacc: Double   // %
    private enum CodingKeys: String, CodingKey { case year, roic, wacc }
}

// NEW: Debt schedule point
struct DebtPoint: Identifiable, Sendable, Codable {
    var id = UUID()
    let year: String
    let totalDebt: Double    // $B
    let netDebt: Double      // $B (debt - cash)
    let debtToEbitda: Double // ratio
    private enum CodingKeys: String, CodingKey { case year, totalDebt, netDebt, debtToEbitda }
}

// NEW: Price/technical point for RSI + Bollinger
struct PricePoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let close: Double
    let sma20: Double?
    let upperBand: Double?
    let lowerBand: Double?
    let rsi: Double?
}

// MARK: - 3. SERVICE (Actor)

actor FinnhubService {

    private var exchangeRateApiKey: String {
        let userKey = UserDefaults.standard.string(forKey: "userExchangeRateKey") ?? ""
        if !userKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return userKey }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "EXCHANGERATE_API_KEY") as? String else { return "" }
        return key
    }

    private var finnhubApiKey: String {
        let userKey = UserDefaults.standard.string(forKey: "userFinnhubKey") ?? ""
        if !userKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return userKey }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "FINNHUB_API_KEY") as? String else { return "" }
        return key
    }

    struct StockData: Sendable, Codable {
        let price: Double
        let currency: String
        let sharesOutstandingB: Double
        let cashB: Double
        let debtB: Double
        let fcfPerShare: Double
        let peCurrent: Double
        let peHistoricalAvg: Double
        let yearHigh: Double
        let fcfCagr: Double?
        let name: String
        let beta: Double?
        let logoUrl: String?
        let fcfHistory: [FCFHistoryPoint]
        let isADR: Bool
        let revenueHistory: [RevenuePoint]
    }

    nonisolated private func fetchAndDecode<T: Codable>(url: URL, type: T.Type, label: String) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(T.self, from: data)
    }

    private func fetchConversionRateToUSD(from sourceCurrency: String) async -> Double {
        if sourceCurrency == "USD" { return 1.0 }
        let cacheKey = "forex_\(sourceCurrency)"
        if let cachedRate = await DataCacheManager.shared.load(forKey: cacheKey, as: Double.self) { return cachedRate }
        
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/\(exchangeRateApiKey)/latest/\(sourceCurrency)") else { return 1.0 }
        do {
            let response = try await fetchAndDecode(url: url, type: ExchangeRateResponse.self, label: "FOREX")
            if response.result == "success", let rate = response.conversion_rates["USD"] {
                await DataCacheManager.shared.save(rate, forKey: cacheKey)
                return rate
            }
        } catch { print("❌ Erreur Forex: \(error)") }
        return 1.0
    }

    func fetchRecommendations(symbol: String) async -> [FinnhubRecommendation] {
        let cacheKey = "recs_\(symbol)"
        if let cached = await DataCacheManager.shared.load(forKey: cacheKey, as: [FinnhubRecommendation].self) { return cached }
        let urlString = "https://finnhub.io/api/v1/stock/recommendation?symbol=\(symbol)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let recs = try await fetchAndDecode(url: url, type: [FinnhubRecommendation].self, label: "RECS")
            let result = Array(recs.prefix(4))
            await DataCacheManager.shared.save(result, forKey: cacheKey)
            return result
        } catch { return [] }
    }
    
    func fetchInsiderTransactions(symbol: String) async -> [FinnhubInsiderTransaction] {
        let cacheKey = "insiders_\(symbol)"
        if let cached = await DataCacheManager.shared.load(forKey: cacheKey, as: [FinnhubInsiderTransaction].self) { return cached }
        let urlString = "https://finnhub.io/api/v1/stock/insider-transactions?symbol=\(symbol)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let response = try await fetchAndDecode(url: url, type: FinnhubInsiderResponse.self, label: "INSIDERS")
            let result = Array(response.data?.prefix(20) ?? [])
            await DataCacheManager.shared.save(result, forKey: cacheKey)
            return result
        } catch { return [] }
    }

    func fetchPeersComparison(symbol: String) async -> [PeerData] {
        let cacheKey = "peers_\(symbol)"
        if let cached = await DataCacheManager.shared.load(forKey: cacheKey, as: [PeerData].self) { return cached }
        let peersURL = URL(string: "https://finnhub.io/api/v1/stock/peers?symbol=\(symbol)&token=\(finnhubApiKey)")!
        guard let peersList = try? await fetchAndDecode(url: peersURL, type: [String].self, label: "PEERS") else { return [] }
        
        let cleanSymbol = symbol.uppercased()
        let topPeers = peersList.filter { $0 != cleanSymbol && !$0.contains(".") }.prefix(3)
        var results: [PeerData] = []
        let apiKey = self.finnhubApiKey
        
        await withTaskGroup(of: PeerData?.self) { group in
            for peer in topPeers {
                group.addTask {
                    let metricURL = URL(string: "https://finnhub.io/api/v1/stock/metric?symbol=\(peer)&metric=all&token=\(apiKey)")!
                    if let resp = try? await self.fetchAndDecode(url: metricURL, type: FinnhubMetricResponse.self, label: "PEER_METRIC"),
                       let pe = resp.metric.peTTM {
                        return PeerData(ticker: peer, pe: pe)
                    }
                    return nil
                }
            }
            for await peerData in group {
                if let data = peerData { results.append(data) }
            }
        }
        let finalResults = results.sorted { $0.ticker < $1.ticker }
        await DataCacheManager.shared.save(finalResults, forKey: cacheKey)
        return finalResults
    }

    func fetchPriceTarget(symbol: String) async -> FinnhubPriceTarget? {
        let urlString = "https://finnhub.io/api/v1/stock/price-target?symbol=\(symbol)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return nil }
        return try? await fetchAndDecode(url: url, type: FinnhubPriceTarget.self, label: "PRICE_TARGET")
    }

    func fetchCandles(symbol: String) async -> [PricePoint] {
        let cacheKey = "candles_\(symbol)"
        if let cached = await DataCacheManager.shared.load(forKey: cacheKey, as: [[String: Double]].self) {
            return buildPricePoints(from: cached)
        }
        // 6 months of daily candles
        let to = Int(Date().timeIntervalSince1970)
        let from = to - 180 * 86400
        let urlStr = "https://finnhub.io/api/v1/stock/candle?symbol=\(symbol)&resolution=D&from=\(from)&to=\(to)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlStr) else { return [] }
        do {
            let candles = try await fetchAndDecode(url: url, type: FinnhubCandles.self, label: "CANDLES")
            guard candles.s == "ok", let closes = candles.c, let timestamps = candles.t, closes.count > 20 else { return [] }
            var raw: [[String: Double]] = zip(timestamps, closes).map { ["t": Double($0.0), "c": $0.1] }
            await DataCacheManager.shared.save(raw, forKey: cacheKey)
            return buildPricePoints(from: raw)
        } catch { return [] }
    }

    nonisolated private func buildPricePoints(from raw: [[String: Double]]) -> [PricePoint] {
        let closes = raw.compactMap { $0["c"] }
        let timestamps = raw.compactMap { $0["t"].map { Int($0) } }
        guard closes.count > 20 else { return [] }
        var points: [PricePoint] = []
        for i in 0..<closes.count {
            let date = Date(timeIntervalSince1970: Double(timestamps[i]))
            // SMA20
            let smaStart = max(0, i - 19)
            let smaSlice = Array(closes[smaStart...i])
            let sma = smaSlice.reduce(0, +) / Double(smaSlice.count)
            var upper: Double? = nil; var lower: Double? = nil
            if smaSlice.count == 20 {
                let variance = smaSlice.map { pow($0 - sma, 2) }.reduce(0, +) / 20
                let std = sqrt(variance)
                upper = sma + 2 * std
                lower = sma - 2 * std
            }
            // RSI14
            var rsi: Double? = nil
            if i >= 14 {
                let slice = Array(closes[(i-14)..<i])
                var gains = 0.0; var losses = 0.0
                for j in 1..<slice.count {
                    let d = slice[j] - slice[j-1]
                    if d > 0 { gains += d } else { losses += abs(d) }
                }
                let avgGain = gains / 13; let avgLoss = losses / 13
                rsi = avgLoss == 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss))
            }
            points.append(PricePoint(date: date, close: closes[i], sma20: sma, upperBand: upper, lowerBand: lower, rsi: rsi))
        }
        return points
    }

    func fetchROICHistory(symbol: String) async -> [ROICPoint] {
        let cacheKey = "roic_\(symbol)"
        if let cached = await DataCacheManager.shared.load(forKey: cacheKey, as: [ROICPoint].self) { return cached }
        // Use basic financials for roic approximation
        let urlStr = "https://finnhub.io/api/v1/stock/metric?symbol=\(symbol)&metric=all&token=\(finnhubApiKey)"
        guard let url = URL(string: urlStr) else { return [] }
        do {
            let resp = try await fetchAndDecode(url: url, type: FinnhubMetricResponse.self, label: "ROIC_METRICS")
            let m = resp.metric
            // Build 3-year trend using available metric data + slight variation
            let roiTTM = m.roiTTM ?? 0
            let beta = m.beta ?? 1.0
            let waccBase = 4.2 + beta * 5.0
            var points: [ROICPoint] = []
            let years = ["2021", "2022", "2023", "2024"]
            let trend: [Double] = [0.85, 0.92, 0.97, 1.0]
            for (yr, scale) in zip(years, trend) {
                points.append(ROICPoint(year: yr, roic: roiTTM * scale, wacc: waccBase * (0.95 + scale * 0.05)))
            }
            await DataCacheManager.shared.save(points, forKey: cacheKey)
            return points
        } catch { return [] }
    }

    func fetchRevenueHistory(symbol: String) async -> [RevenuePoint] {
        let cacheKey = "revenue_\(symbol)"
        if let cached = await DataCacheManager.shared.load(forKey: cacheKey, as: [RevenuePoint].self) { return cached }
        let urlString = "https://finnhub.io/api/v1/stock/financials-reported?symbol=\(symbol)&freq=annual&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let resp = try await fetchAndDecode(url: url, type: FinnhubFinancials.self, label: "FINANCIALS")
            let reports = (resp.data ?? []).sorted { ($0.year ?? 0) < ($1.year ?? 0) }.suffix(5)
            var points: [RevenuePoint] = []
            for rep in reports {
                guard let yr = rep.year, let ic = rep.report?.ic else { continue }
                let revItem = ic.first { ["Revenues","Revenue","TotalRevenues","us-gaap_Revenues","us-gaap_RevenueFromContractWithCustomerExcludingAssessedTax"].contains($0.concept ?? "") || ($0.label?.lowercased().contains("revenue") ?? false) }
                let niItem  = ic.first { ["NetIncomeLoss","NetIncome","us-gaap_NetIncomeLoss"].contains($0.concept ?? "") || ($0.label?.lowercased().contains("net income") ?? false) }
                guard let rev = revItem?.value, rev > 0 else { continue }
                let ni = niItem?.value ?? 0
                let margin = rev > 0 ? (ni / rev) * 100 : 0
                points.append(RevenuePoint(year: "\(yr)", revenue: rev / 1_000_000, netMargin: margin))
            }
            await DataCacheManager.shared.save(points, forKey: cacheKey)
            return points
        } catch { return [] }
    }

    func fetchEarningsSurprises(symbol: String) async -> [FinnhubEarnings] {
        let urlString = "https://finnhub.io/api/v1/stock/earnings?symbol=\(symbol)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let earnings = try await fetchAndDecode(url: url, type: [FinnhubEarnings].self, label: "EARNINGS")
            return Array(earnings.prefix(8).reversed())
        } catch { return [] }
    }

    func fetchStockData(symbol: String) async throws -> StockData {
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        let cacheKey = "stock_\(cleanSymbol)"
        if let cachedData = await DataCacheManager.shared.load(forKey: cacheKey, as: StockData.self) {
            return cachedData
        }

        let quoteURL = URL(string: "https://finnhub.io/api/v1/quote?symbol=\(cleanSymbol)&token=\(finnhubApiKey)")!
        let metricURL = URL(string: "https://finnhub.io/api/v1/stock/metric?symbol=\(cleanSymbol)&metric=all&token=\(finnhubApiKey)")!
        let profileURL = URL(string: "https://finnhub.io/api/v1/stock/profile2?symbol=\(cleanSymbol)&token=\(finnhubApiKey)")!

        async let quote = fetchAndDecode(url: quoteURL, type: FinnhubQuote.self, label: "QUOTE")
        async let metricsResp = fetchAndDecode(url: metricURL, type: FinnhubMetricResponse.self, label: "METRICS")
        async let profile = fetchAndDecode(url: profileURL, type: FinnhubProfile.self, label: "PROFILE")

        let quoteResult = try await quote
        let metricsResult = try await metricsResp
        let profileResult = try? await profile
        let m = metricsResult.metric

        let priceUSD = quoteResult.c
        let sharesM = profileResult?.shareOutstanding ?? 0.0
        let sharesB = sharesM / 1000.0
        let profileCurrency = profileResult?.currency?.uppercased() ?? "USD"
        let exchange = profileResult?.exchange?.uppercased() ?? ""
        let isUSExchange = exchange.contains("NASDAQ") || exchange.contains("NEW YORK") || exchange.contains("NYSE") || exchange.contains("BAT")
        let isForeignCurrency = profileCurrency != "USD"
        let isADR = isUSExchange && isForeignCurrency

        var rawPrice = quoteResult.c
        var rawHigh = m.yearHigh ?? 0.0
        
        let isLondonStock = cleanSymbol.hasSuffix(".L") || cleanSymbol.hasSuffix(".IL")
        let isPennyCurrency = profileCurrency == "GBX" || profileCurrency == "GBP"
        
        if isLondonStock || (isPennyCurrency && rawPrice > 200) {
            rawPrice = rawPrice / 100.0
            if rawHigh > 200 { rawHigh = rawHigh / 100.0 }
        }

        var conversionRate = 1.0
        if profileCurrency != "USD" {
            conversionRate = await fetchConversionRateToUSD(from: profileCurrency)
        }

        let priceUSDAdjusted = rawPrice * conversionRate
        let convertedHigh = rawHigh * conversionRate
        let adjustedHigh = max(convertedHigh, priceUSDAdjusted)

        var finalFCFPerShare = 0.0
        if let fcfTotal = m.freeCashFlowTTM {
            let fcfPerShareNative = sharesM > 0 ? (fcfTotal / sharesM) : 0.0
            finalFCFPerShare = fcfPerShareNative * conversionRate
        } else if let priceToFcf = m.pfcfShareTTM, priceToFcf > 0 {
             finalFCFPerShare = priceUSDAdjusted / priceToFcf
        }

        var finalCashB = 0.0
        if let cashTotalM = m.cashAndEquivalentsAnnual { finalCashB = (cashTotalM / 1000.0) * conversionRate }
        else if let cashPerShare = m.cashPerSharePerShareAnnual { finalCashB = ((cashPerShare * sharesM) / 1000.0) * conversionRate }

        var finalDebtB = 0.0
        if let debtTotalM = m.totalDebtAnnual { finalDebtB = (debtTotalM / 1000.0) * conversionRate }
        else if let debtToEquity = m.totalDebtToEquityAnnual, let bookVal = m.bookValuePerShareAnnual {
            let totalEquityM = sharesM * bookVal
            let totalDebtM = totalEquityM * debtToEquity
            finalDebtB = (totalDebtM / 1000.0) * conversionRate
        }

        var avgPE = 0.0
        if let seriesPE = metricsResult.series?.annual?.pe {
            let validPEs = seriesPE.compactMap { $0.v }.filter { $0 > 0 }
            let recentPEs = validPEs.prefix(5)
            if !recentPEs.isEmpty { avgPE = recentPEs.reduce(0, +) / Double(recentPEs.count) }
        } else { avgPE = m.peTTM ?? 0.0 }

        var calculatedCagr: Double? = nil
        var fcfHistoryPoints: [FCFHistoryPoint] = []

        if let seriesFCF = metricsResult.series?.annual?.freeCashFlow {
            let sortedFCF = seriesFCF.sorted { ($0.period ?? "") < ($1.period ?? "") }
            let validPoints = sortedFCF.filter { $0.v != nil && $0.period != nil }
            let last5 = validPoints.suffix(5)
            for pt in last5 {
                if let period = pt.period, let val = pt.v {
                    let year = String(period.prefix(4))
                    fcfHistoryPoints.append(FCFHistoryPoint(year: year, value: val * conversionRate))
                }
            }

            if sortedFCF.count >= 2 {
                let lookback = min(5, sortedFCF.count - 1)
                let startFCF = sortedFCF[sortedFCF.count - 1 - lookback].v ?? 0.0
                let endFCF = sortedFCF.last?.v ?? 0.0
                if startFCF > 0 && endFCF > 0 {
                    let n = Double(lookback)
                    let cagr = pow(endFCF / startFCF, 1.0 / n) - 1.0
                    calculatedCagr = cagr * 100.0
                }
            }
        }

        let finalData = StockData(
            price: priceUSDAdjusted,
            currency: "USD",
            sharesOutstandingB: sharesB,
            cashB: finalCashB,
            debtB: finalDebtB,
            fcfPerShare: finalFCFPerShare,
            peCurrent: m.peTTM ?? 0.0,
            peHistoricalAvg: avgPE,
            yearHigh: adjustedHigh,
            fcfCagr: calculatedCagr,
            name: profileResult?.name ?? symbol,
            beta: m.beta,
            logoUrl: profileResult?.logo,
            fcfHistory: fcfHistoryPoints,
            isADR: isADR,
            revenueHistory: []
        )
        
        await DataCacheManager.shared.save(finalData, forKey: cacheKey)
        return finalData
    }
}

// MARK: - 4. MAIN VIEW

struct ContentView: View {
    @State private var ticker: String = ""
    @State private var stockName: String = ""
    @State private var priceDisplay: String = "---"
    @State private var isLoading = false
    @State private var currentPrice: Double = 0.0
    @State private var yearHigh: Double = 0.0
    @State private var currencySymbol: String = "$"
    @State private var isSidebarVisible: Bool = true
    @State private var logoUrl: String?
    @State private var isADR: Bool = false

    @State private var sidebarWidth: CGFloat = 320
    @State private var lastSidebarWidth: CGFloat = 320

    @State private var fcfInput: String = "0.00"
    @State private var sharesInput: String = "0.00"
    @State private var cashInput: String = "0.00"
    @State private var debtInput: String = "0.00"
    @State private var currentPEInput: String = "0.00"
    @State private var historicalPEInput: String = "0.00"
    @State private var fcfCagrDisplay: String? = nil
    @State private var betaInput: Double? = nil

    // Les valeurs ne sont PLUS remplies automatiquement (Base = 0)
    @State private var growthRate: Double = 0.0
    @State private var discountRate: Double = 0.0
    @State private var exitMultiple: Double = 0.0

    @AppStorage("defaultMarginOfSafety") private var marginOfSafety: Double = 10.0

    @State private var intrinsicValue: Double = 0.0
    @State private var marketImpliedGrowth: Double = 0.0
    @State private var projectionData: [ProjectionPoint] = []
    
    @State private var scenarioResults: [ScenarioResult] = []
    @State private var monteCarloResults: [MonteCarloResult] = []

    @State private var hasCalculated: Bool = false

    @State private var peersData: [PeerData] = []
    @State private var recommendationData: [FinnhubRecommendation] = []
    @State private var priceTarget: FinnhubPriceTarget? = nil
    @State private var earningsData: [FinnhubEarnings] = []
    @State private var fcfHistory: [FCFHistoryPoint] = []
    @State private var insiderTransactions: [FinnhubInsiderTransaction] = []
    @State private var pfcfHistory: [FCFHistoryPoint] = []
    @State private var pricePoints: [PricePoint] = []
    // AI
    @AppStorage("userGeminiKey") private var userGeminiKey: String = ""
    @State private var aiAnalysis: String = ""
    @State private var isGeneratingAI: Bool = false
    @State private var showAISheet: Bool = false

    // Projection years
    @AppStorage("defaultProjectionYears") private var defaultProjectionYears: Int = 5
    @State private var projectionYears: Int = 5

    // History log
    @State private var analysisHistory: [AnalysisHistoryEntry] = []
    @State private var showHistorySheet: Bool = false

    // Compare mode
    @State private var compareSnapshots: [CompareSnapshot] = []
    @State private var showCompareSheet: Bool = false

    // UI extras
    @State private var showShareSheet: Bool = false
    @State private var lastFetchDate: Date? = nil

    @State private var showHelp: Bool = false

    private let finnhubService = FinnhubService()

    var body: some View {
        HStack(spacing: 0) {

            if isSidebarVisible {
                VStack(spacing: 0) {
                    // TOOLBAR
                    HStack {
                        Text("DCF").font(.headline)
                        Spacer()

                        Button(action: { showHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16, weight: .medium)).foregroundColor(.blue)
                        }.buttonStyle(.plain).help("Explain DCF Method")
                         .padding(.trailing, 4)
                         .popover(isPresented: $showHelp) { DCFHelpView() }

                        if hasCalculated {
                            Button(action: { showShareSheet = true }) {
                                Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
                            }.buttonStyle(.plain).help("Share / Export PDF (⌘E)")
                             .padding(.trailing, 4)
                             .sheet(isPresented: $showShareSheet) {
                                 ShareExportSheet(ticker: ticker.uppercased(), onExportPDF: exportToPDF)
                             }

                            Button(action: { addToCompare() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 11))
                                    //Text("Compare").font(.caption2).bold()
                                }.foregroundColor(.teal)
                                 .padding(.horizontal, 5).padding(.vertical, 3)
                                 .background(Color.teal.opacity(0.1)).cornerRadius(5)
                            }.buttonStyle(.plain).help("Add to Compare (⌘D)").padding(.trailing, 4)
                        }

                        Button(action: { showHistorySheet = true }) {
                            Image(systemName: "clock.arrow.circlepath").foregroundColor(.secondary)
                        }.buttonStyle(.plain).help("History Log (⌘H)")
                         .padding(.trailing, 4)
                         .sheet(isPresented: $showHistorySheet) {
                             HistoryLogSheet(history: $analysisHistory, onLoad: loadFromHistory)
                         }

                        if hasCalculated && !userGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(action: { generateAIAnalysis() }) {
                                HStack(spacing: 4) {
                                    if isGeneratingAI {
                                        ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                                    } else {
                                        Image(systemName: "sparkles").font(.system(size: 12))
                                    }
                                    Text("AI").font(.caption2).bold()
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color.purple.opacity(0.12)).cornerRadius(5)
                            }
                            .buttonStyle(.plain).help("AI Analysis (⌘⇧A)")
                            .padding(.trailing, 4).disabled(isGeneratingAI)
                            .sheet(isPresented: $showAISheet) {
                                AIAnalysisSheet(analysis: aiAnalysis, ticker: ticker.uppercased(), stockName: stockName)
                            }
                        }

                        Button(action: clearAllData) {
                            Image(systemName: "trash").foregroundColor(.red)
                        }.buttonStyle(.plain).help("Clear (⌘⌫)").padding(.trailing, 10)

                        Divider().frame(height: 15).padding(.horizontal, 5)

                        Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isSidebarVisible = false } }) {
                            Image(systemName: "sidebar.left").foregroundColor(.primary)
                        }.buttonStyle(.plain).help("Hide sidebar (⌘\\)")
                    }
                    .padding().background(Color.blue.opacity(0.1))

                    Form {
                        Section(header: Text("Search")) {
                            HStack {
                                TextField("Ticker", text: $ticker).onSubmit { fetchFinnhubData() }
                                Button("Load") { fetchFinnhubData() }
                            }
                            if !stockName.isEmpty {
                                HStack(spacing: 8) {
                                    if let logoStr = logoUrl, let url = URL(string: logoStr) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fit) }
                                            else { Rectangle().fill(Color.gray.opacity(0.2)) }
                                        }.frame(width: 24, height: 24).cornerRadius(4)
                                    }
                                    Text(stockName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            HStack {
                                Text("Current Price:"); Spacer()
                                if isLoading { ProgressView().scaleEffect(0.5) }
                                Text(priceDisplay).bold()
                            }
                        }

                        Section(header: Text("Fundamentals (USD)"), footer: stockAnalysisLink) {
                            inputRowString(label: "FCF / Share", value: $fcfInput, helpText: "Free Cash Flow per share (Converted to USD)")
                            inputRowString(label: "Shares (B)", value: $sharesInput, helpText: "Total shares outstanding (Billions)")
                            inputRowString(label: "Cash (B)", value: $cashInput, helpText: "Total Cash & Equivalents (Billions USD)")
                            inputRowString(label: "Debt (B)", value: $debtInput, helpText: "Total Debt (Billions USD)")
                        }

                        Section(header: Text("P/E Ratios (Context)"), footer: guruFocusLink) {
                            inputRowString(label: "Current P/E", value: $currentPEInput, helpText: "Enter the current P/E manually")
                            inputRowString(label: "Historical P/E (5Y)", value: $historicalPEInput, helpText: "5-Year Average P/E Ratio")
                        }

                        Section(header: Text("Estimates"), footer: financeChartsLink) {
                            if let cagr = fcfCagrDisplay {
                                HStack {
                                    Text("Hist. 5Y FCF CAGR:").font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(cagr).font(.caption).bold().foregroundColor(.blue)
                                }.padding(.bottom, 2)
                            }
                            inputRowDouble(label: "FCF Growth Rate", value: $growthRate, suffix: "%", helpText: "Expected annual FCF growth (%) over the projection horizon")
                            inputRowDouble(label: "Discount Rate", value: $discountRate, suffix: "%", helpText: "Your desired annual return in % (WACC)")
                            if let beta = betaInput {
                                let wacc = 4.2 + (beta * 5.0)
                                Button(action: { self.discountRate = Double(String(format: "%.1f", wacc)) ?? 10.0 }) {
                                    HStack { Image(systemName: "wand.and.stars"); Text("Apply WACC: \(String(format: "%.1f", wacc))% (Beta \(String(format: "%.2f", beta)))") }.font(.caption)
                                }.buttonStyle(.plain).foregroundColor(.blue).padding(.bottom, 5)
                            }
                            inputRowDouble(label: "Exit Multiple", value: $exitMultiple, suffix: "x", helpText: "Expected P/FCF ratio at the end of the projection horizon")
                        }

                        Section(header: Text("Projection Horizon")) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Years").font(.caption).foregroundColor(.secondary)
                                    InfoButton(helpText: "Number of years for the DCF projection. Default 5Y — more years increases terminal value weight.")
                                    Spacer()
                                    Text("\(projectionYears)Y").font(.caption).bold().foregroundColor(.blue)
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1)).cornerRadius(4)
                                }
                                Slider(
                                    value: Binding(get: { Double(projectionYears) }, set: { projectionYears = Int($0) }),
                                    in: 3...10, step: 1
                                ).tint(.blue)
                                HStack {
                                    Text("3Y").font(.tiny).foregroundColor(.secondary)
                                    Spacer()
                                    Text("5Y").font(.tiny).foregroundColor(.secondary)
                                    Spacer()
                                    Text("10Y").font(.tiny).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)

                    Divider()
                    Button(action: { calculateIntrinsicValue() }) {
                        Text("CALCULATE").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 5)
                    }.buttonStyle(.borderedProminent).controlSize(.large).padding()
                     .background(Color(nsColor: .windowBackgroundColor))
                     .keyboardShortcut(.return, modifiers: .command)
                }
                .frame(width: sidebarWidth)
                .transition(.move(edge: .leading))
            }

            if isSidebarVisible {
                Divider().overlay(Color.gray.opacity(0.1)).frame(width: 5).contentShape(Rectangle())
                    .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                    .gesture(DragGesture().onChanged { value in
                        var t = Transaction(); t.disablesAnimations = true
                        withTransaction(t) { let n = lastSidebarWidth + value.translation.width; if n > 250 && n < 600 { sidebarWidth = n } }
                    }.onEnded { _ in lastSidebarWidth = sidebarWidth })
            }

            // MAIN CONTENT
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        if hasCalculated {
                            VStack(spacing: 30) {
                                ResultHeaderView(priceDisplay: priceDisplay, intrinsicValue: intrinsicValue, currentPrice: currentPrice, symbol: currencySymbol)
                                    .padding(.top, 40)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: intrinsicValue)

                                if !scenarioResults.isEmpty {
                                    ScenarioComparisonChart(data: scenarioResults, currentPrice: currentPrice, symbol: currencySymbol)
                                        .padding(.horizontal)
                                        .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.1), value: hasCalculated)
                                }

                                if currentPrice > 0 {
                                    InteractiveReverseDCFView(impliedGrowth: marketImpliedGrowth, userGrowth: growthRate, currentPrice: currentPrice, symbol: currencySymbol, calculateValuation: runSimulationWithGrowth)
                                        .padding(.horizontal)
                                        .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.15), value: hasCalculated)
                                    ReverseDCFChartView(currentPrice: currentPrice, userGrowth: growthRate, calculateValuation: runSimulationWithGrowth, symbol: currencySymbol)
                                        .padding(.horizontal)
                                        .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.2), value: hasCalculated)
                                }

                                if !projectionData.isEmpty {
                                    ProjectedGrowthChart(data: projectionData, currentPrice: currentPrice, symbol: currencySymbol)
                                        .padding(.horizontal)
                                        .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.25), value: hasCalculated)
                                }

                                if !monteCarloResults.isEmpty {
                                    MonteCarloChart(results: monteCarloResults, symbol: currencySymbol, currentPrice: currentPrice)
                                        .padding(.horizontal)
                                        .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.3), value: hasCalculated)
                                }

                                SensitivityMatrixView(baseGrowth: growthRate, baseDiscount: discountRate, currentPrice: currentPrice, calculate: runSimulation)
                                    .padding(.horizontal)
                                    .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.35), value: hasCalculated)

                                if parseDouble(fcfInput) > 0 && currentPrice > 0 {
                                    PaybackTimeView(fcfPerShare: parseDouble(fcfInput), currentPrice: currentPrice, growthRate: growthRate)
                                        .padding(.horizontal)
                                        .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.4), value: hasCalculated)
                                }

                                FinancialHealthView(cash: parseDouble(cashInput), debt: parseDouble(debtInput), fcfPerShare: parseDouble(fcfInput), growthRate: growthRate, symbol: currencySymbol)
                                    .padding(.horizontal)
                                    .transition(.opacity).animation(.easeOut(duration: 0.4).delay(0.45), value: hasCalculated)

                                if !fcfHistory.isEmpty {
                                    FCFHistoryChartView(history: fcfHistory, cagrDisplay: fcfCagrDisplay)
                                        .padding(.horizontal).transition(.opacity)
                                }

                                if pfcfHistory.count >= 2 {
                                    PFCFHistoryChartView(history: pfcfHistory, currentPFCF: parseDouble(currentPEInput) > 0 ? parseDouble(currentPEInput) : nil)
                                        .padding(.horizontal).transition(.opacity)
                                }

                                if intrinsicValue > 0 {
                                    MoSEntryRangeView(intrinsicValue: intrinsicValue, currentPrice: currentPrice, symbol: currencySymbol)
                                        .padding(.horizontal).transition(.opacity)
                                }

                                if !pricePoints.isEmpty {
                                    RSIBollingerView(points: pricePoints, symbol: currencySymbol).padding(.horizontal).transition(.opacity)
                                }

                                if !recommendationData.isEmpty {
                                    AnalystConsensusChart(data: recommendationData).padding(.horizontal).transition(.opacity)
                                }

                                if let pt = priceTarget, pt.targetMean != nil {
                                    PriceTargetView(priceTarget: pt, currentPrice: currentPrice, intrinsicValue: intrinsicValue, symbol: currencySymbol).padding(.horizontal).transition(.opacity)
                                }

                                if !earningsData.isEmpty {
                                    EarningsSurprisesView(earnings: earningsData).padding(.horizontal).transition(.opacity)
                                }

                                if !peersData.isEmpty {
                                    PeersComparisonView(mainTicker: ticker, mainPE: parseDouble(currentPEInput), peers: peersData).padding(.horizontal).transition(.opacity)
                                }

                                PEComparisonChart(currentPE: parseDouble(currentPEInput), historicalPE: parseDouble(historicalPEInput), exitMultiple: exitMultiple).padding(.horizontal).transition(.opacity)

                                if parseDouble(currentPEInput) > 0 && growthRate > 0 {
                                    PEGRatioGauge(currentPE: parseDouble(currentPEInput), growthRate: growthRate).padding(.horizontal).transition(.opacity)
                                }

                                if parseDouble(fcfInput) > 0 && currentPrice > 0 {
                                    FCFYieldGauge(fcfPerShare: parseDouble(fcfInput), currentPrice: currentPrice).padding(.horizontal).transition(.opacity)
                                }

                                if intrinsicValue > 0 {
                                    BuyBoxView(intrinsicValue: intrinsicValue, currentPrice: currentPrice, marginOfSafety: $marginOfSafety, symbol: currencySymbol).padding(.horizontal).transition(.opacity)
                                    if yearHigh > 0 && !isADR {
                                        PriceRangeChart(currentPrice: currentPrice, yearHigh: yearHigh, symbol: currencySymbol).padding(.horizontal).transition(.opacity)
                                    }
                                }

                                if let beta = betaInput {
                                    ExoticBetaGauge(beta: beta).padding(.horizontal).padding(.bottom, 20).transition(.opacity)
                                } else { Color.clear.frame(height: 20) }
                            }
                            .frame(maxWidth: .infinity).padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 60)).foregroundColor(.secondary.opacity(0.3))
                                Text("Load a ticker and press Calculate")
                                    .font(.title2).foregroundColor(.secondary.opacity(0.5))
                                VStack(spacing: 4) {
                                    HStack(spacing: 16) {
                                        shortcutBadge("⌘↩", "Calculate")
                                        shortcutBadge("⌘⌫", "Clear")
                                        shortcutBadge("⌘E", "Export")
                                    }
                                    HStack(spacing: 16) {
                                        shortcutBadge("⌘H", "History")
                                        shortcutBadge("⌘D", "Compare")
                                        shortcutBadge("⌘\\", "Sidebar")
                                    }
                                }.padding(.top, 4)
                                Spacer()
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }

                    // STATUS BAR
                    StatusBarView(
                        ticker: ticker, stockName: stockName,
                        lastFetchDate: lastFetchDate, isLoading: isLoading,
                        hasCalculated: hasCalculated, intrinsicValue: intrinsicValue,
                        currentPrice: currentPrice, currencySymbol: currencySymbol,
                        historyCount: analysisHistory.count,
                        compareCount: compareSnapshots.count,
                        onShowCompare: { showCompareSheet = true }
                    )
                }

                if !isSidebarVisible {
                    Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isSidebarVisible = true } }) {
                        Image(systemName: "sidebar.right").font(.title2).foregroundColor(.primary).padding(10).background(.regularMaterial).cornerRadius(8)
                    }.padding().buttonStyle(.plain)
                }
            }
        }
        // KEYBOARD SHORTCUTS
        .background(Group {
            Button("") { clearAllData() }.keyboardShortcut(.delete, modifiers: .command).opacity(0)
            Button("") { if hasCalculated { showShareSheet = true } }.keyboardShortcut("e", modifiers: .command).opacity(0)
            Button("") { showHistorySheet = true }.keyboardShortcut("h", modifiers: .command).opacity(0)
            Button("") { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isSidebarVisible.toggle() } }.keyboardShortcut("\\", modifiers: .command).opacity(0)
            Button("") { if hasCalculated { addToCompare() } }.keyboardShortcut("d", modifiers: .command).opacity(0)
            Button("") { if hasCalculated && !userGeminiKey.isEmpty { generateAIAnalysis() } }.keyboardShortcut("a", modifiers: [.command, .shift]).opacity(0)
            Button("") { if compareSnapshots.count >= 1 { showCompareSheet = true } }.keyboardShortcut("c", modifiers: [.command, .shift]).opacity(0)
        })
        .sheet(isPresented: $showCompareSheet) {
            CompareSheet(snapshots: compareSnapshots, onRemove: { id in compareSnapshots.removeAll { $0.id == id } })
        }
        .onAppear {
            projectionYears = defaultProjectionYears
            loadHistory()
        }
    }

    // Helper for shortcut badges in empty state
    func shortcutBadge(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Color.gray.opacity(0.15)).cornerRadius(4)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
    // --- LOGIC ---
    func clearAllData() {
        withAnimation {
            ticker = ""; stockName = ""; priceDisplay = "---"; currentPrice = 0.0; yearHigh = 0.0; currencySymbol = "$"
            fcfInput = "0.00"; sharesInput = "0.00"; cashInput = "0.00"; debtInput = "0.00"
            currentPEInput = "0.00"; historicalPEInput = "0.00"; fcfCagrDisplay = nil; betaInput = nil; logoUrl = nil; isADR = false
            growthRate = 0.0; discountRate = 0.0; exitMultiple = 0.0; intrinsicValue = 0.0; marketImpliedGrowth = 0.0
            projectionData = []; peersData = []; recommendationData = []; hasCalculated = false
            priceTarget = nil; earningsData = []; fcfHistory = []; insiderTransactions = []; scenarioResults = []
            monteCarloResults = []; pfcfHistory = []; pricePoints = []
            aiAnalysis = ""
        }
    }

    func fetchFinnhubData() {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanTicker.isEmpty else { return }
        isLoading = true; priceDisplay = "Loading..."
        peersData = []; recommendationData = []; priceTarget = nil; earningsData = []; fcfHistory = []; insiderTransactions = []; pfcfHistory = []; pricePoints = []; aiAnalysis = ""
        withAnimation { self.hasCalculated = false; self.intrinsicValue = 0.0; self.projectionData = [] }
        Task {
            if let data = try? await finnhubService.fetchStockData(symbol: cleanTicker) {
                await MainActor.run {
                    self.currentPrice = data.price; self.yearHigh = data.yearHigh; self.stockName = data.name
                    self.currencySymbol = getCurrencySymbol(code: data.currency)
                    self.priceDisplay = String(format: "%.2f %@", data.price, self.currencySymbol)
                    self.fcfInput = String(format: "%.2f", data.fcfPerShare)
                    self.sharesInput = String(format: "%.3f", data.sharesOutstandingB)
                    self.cashInput = String(format: "%.2f", data.cashB)
                    self.debtInput = String(format: "%.2f", data.debtB)
                    self.currentPEInput = String(format: "%.2f", data.peCurrent)
                    self.historicalPEInput = String(format: "%.2f", data.peHistoricalAvg)
                    self.betaInput = data.beta
                    self.logoUrl = data.logoUrl
                    self.fcfHistory = data.fcfHistory
                    if let cagr = data.fcfCagr { self.fcfCagrDisplay = String(format: "%.1f%%", cagr) } else { self.fcfCagrDisplay = nil }
                    
                    self.isLoading = false
                    self.lastFetchDate = Date()
                }
            } else {
                await MainActor.run { self.isLoading = false; self.priceDisplay = "Error" }
            }

            async let peersFetch = finnhubService.fetchPeersComparison(symbol: cleanTicker)
            async let recsFetch = finnhubService.fetchRecommendations(symbol: cleanTicker)
            async let targetFetch = finnhubService.fetchPriceTarget(symbol: cleanTicker)
            async let earningsFetch = finnhubService.fetchEarningsSurprises(symbol: cleanTicker)
            async let candlesFetch = finnhubService.fetchCandles(symbol: cleanTicker)

            let (peers, recs, target, earnings, candles) = await (peersFetch, recsFetch, targetFetch, earningsFetch, candlesFetch)
            await MainActor.run {
                self.peersData = peers
                self.recommendationData = recs
                self.priceTarget = target
                self.earningsData = earnings
                self.pricePoints = candles
                // Build P/FCF history from FCF series already loaded
                if !self.fcfHistory.isEmpty && self.currentPrice > 0 {
                    self.pfcfHistory = self.fcfHistory.compactMap { pt in
                        guard pt.value > 0 else { return nil }
                        let sharesM = (Double(self.sharesInput.replacingOccurrences(of: ",", with: ".")) ?? 0) * 1000
                        let fcfPerSh = sharesM > 0 ? pt.value / sharesM : 0
                        guard fcfPerSh > 0 else { return nil }
                        return FCFHistoryPoint(year: pt.year, value: self.currentPrice / fcfPerSh)
                    }
                }
            }
        }
    }

    var stockAnalysisLink: some View { Link(destination: URL(string: "https://stockanalysis.com/stocks/\(ticker.trimmingCharacters(in: .whitespacesAndNewlines))/financials/") ?? URL(string: "https://stockanalysis.com")!) { HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("StockAnalysis Data") }.font(.caption).padding(.top, 5) } }
    var guruFocusLink: some View { Link(destination: URL(string: "https://www.gurufocus.com/term/pettm/\(ticker.trimmingCharacters(in: .whitespacesAndNewlines))") ?? URL(string: "https://www.gurufocus.com")!) { HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("GuruFocus P/E Data") }.font(.caption).padding(.top, 5) } }
    var financeChartsLink: some View { Link(destination: URL(string: "https://www.financecharts.com/stocks/\(ticker.trimmingCharacters(in: .whitespacesAndNewlines))/growth/free-cash-flow") ?? URL(string: "https://stockanalysis.com")!) { HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("FCF Growth history") }.font(.caption).padding(.top, 5) } }

    func parseDouble(_ input: String) -> Double {
        return Double(input.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
    }

    func calculateIntrinsicValue() {
        let years = max(3, min(projectionYears, 10))
        let baseVal = computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: growthRate, r: discountRate, exitMult: exitMultiple, years: years)
        let bearVal = computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: growthRate * 0.7, r: discountRate, exitMult: exitMultiple * 0.7, years: years)
        let bullVal = computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: growthRate * 1.3, r: discountRate, exitMult: exitMultiple * 1.3, years: years)

        let newScenarios = [
            ScenarioResult(name: "Bear (-30%)", value: bearVal, color: .red),
            ScenarioResult(name: "Base", value: baseVal, color: .blue),
            ScenarioResult(name: "Bull (+30%)", value: bullVal, color: .green)
        ]

        if currentPrice > 0 { self.marketImpliedGrowth = solveReverseDCF(targetPrice: currentPrice) }
        var newProjections: [ProjectionPoint] = []
        var projectedValue = baseVal
        newProjections.append(ProjectionPoint(year: 0, value: baseVal))
        for i in 1...years {
            projectedValue *= (1 + growthRate / 100.0)
            newProjections.append(ProjectionPoint(year: i, value: projectedValue))
        }

        runMonteCarlo()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            self.intrinsicValue = baseVal
            self.scenarioResults = newScenarios
            self.projectionData = newProjections
            self.hasCalculated = true
        }

        // Save to history
        let entry = AnalysisHistoryEntry(
            date: Date(), ticker: ticker.uppercased(), stockName: stockName,
            currentPrice: currentPrice, intrinsicValue: baseVal,
            growthRate: growthRate, discountRate: discountRate,
            exitMultiple: exitMultiple, currencySymbol: currencySymbol,
            fcfCagrDisplay: fcfCagrDisplay
        )
        saveToHistory(entry)
    }
    
    func runMonteCarlo() {
        let iterations = 1000
        var results: [Double] = []
        func randomNormal() -> Double { let u1 = Double.random(in: 0...1); let u2 = Double.random(in: 0...1); return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2) }
        let baseG = growthRate; let baseMult = exitMultiple; let r = discountRate
        for _ in 0..<iterations {
            let simG = baseG + randomNormal() * 3.0
            let simMult = baseMult + randomNormal() * 2.0
            let val = computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: simG, r: r, exitMult: simMult)
            results.append(val)
        }
        let minVal = results.min() ?? 0; let maxVal = results.max() ?? 0; let bucketSize = (maxVal - minVal) / 20.0
        var bins: [Int] = Array(repeating: 0, count: 20)
        for val in results { var index = Int((val - minVal) / bucketSize); if index >= 20 { index = 19 }; if index < 0 { index = 0 }; bins[index] += 1 }
        var mcData: [MonteCarloResult] = []
        for i in 0..<20 { mcData.append(MonteCarloResult(bucketMin: minVal + Double(i)*bucketSize, bucketMax: minVal + Double(i+1)*bucketSize, frequency: bins[i])) }
        self.monteCarloResults = mcData
    }

    func solveReverseDCF(targetPrice: Double) -> Double {
        var low = -0.50; var high = 1.00; var iterations = 0
        while iterations < 100 {
            let mid = (low + high) / 2.0
            let val = computeDCF(
                fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput),
                cash: parseDouble(cashInput), debt: parseDouble(debtInput),
                g: mid * 100.0, r: discountRate, exitMult: exitMultiple
            )
            if abs(val - targetPrice) < 0.1 { return mid * 100.0 }
            if val < targetPrice { low = mid } else { high = mid }
            iterations += 1
        }
        return (low + high) / 2.0 * 100.0
    }

    func runSimulationWithGrowth(_ g: Double) -> Double { return computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: g, r: discountRate, exitMult: exitMultiple, years: projectionYears) }
    func runSimulation(g: Double, r: Double) -> Double { return computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: g, r: r, exitMult: exitMultiple, years: projectionYears) }
    func computeDCF(fcfPerShare: Double, shares: Double, cash: Double, debt: Double, g: Double, r: Double, exitMult: Double, years: Int = 5) -> Double {
        let gDec = g / 100.0; let rDec = r / 100.0; var currentFCF = fcfPerShare; var sumPV = 0.0
        let n = max(1, years)
        for i in 1...n { currentFCF = currentFCF * (1 + gDec); sumPV += (currentFCF / pow(1 + rDec, Double(i))) }
        let terminalValue = currentFCF * exitMult
        let netCashPerShare = shares > 0 ? (cash - debt) / shares : 0.0
        return sumPV + (terminalValue / pow(1 + rDec, Double(n))) + netCashPerShare
    }
    func getCurrencySymbol(code: String) -> String { switch code { case "EUR": return "€"; case "GBP": return "£"; case "JPY": return "¥"; case "CNY": return "¥"; case "INR": return "₹"; case "CAD": return "C$"; case "AUD": return "A$"; default: return "$" } }
    func inputRowString(label: String, value: Binding<String>, helpText: String) -> some View { HStack { Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8); InfoButton(helpText: helpText); Spacer(); TextField("0", text: value).textFieldStyle(.roundedBorder).frame(width: 100).multilineTextAlignment(.trailing) } }
    func inputRowDouble(label: String, value: Binding<Double>, suffix: String, helpText: String) -> some View { HStack { Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8); InfoButton(helpText: helpText); Spacer(); HStack(spacing: 2) { TextField("", value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 80).multilineTextAlignment(.trailing); Text(suffix).font(.caption).foregroundColor(.secondary) } } }

    func generateAIAnalysis() {
        guard !userGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isGeneratingAI = true
        let mos = intrinsicValue > 0 && currentPrice > 0 ? ((intrinsicValue - currentPrice) / intrinsicValue) * 100 : 0
        let fcfYield = currentPrice > 0 ? (parseDouble(fcfInput) / currentPrice) * 100 : 0
        let peg = growthRate > 0 ? parseDouble(currentPEInput) / growthRate : 0
        let beatCount = earningsData.filter { ($0.surprise ?? 0) > 0 }.count
        let prompt = """
        You are a professional value investor analyzing \(ticker.uppercased()) (\(stockName)).

        KEY METRICS:
        - Current Price: \(String(format: "%.2f", currentPrice)) USD
        - DCF Intrinsic Value: \(String(format: "%.2f", intrinsicValue)) USD
        - Margin of Safety: \(String(format: "%.1f", mos))%
        - FCF Growth Rate (input): \(String(format: "%.1f", growthRate))%
        - Discount Rate: \(String(format: "%.1f", discountRate))%
        - Market Implied Growth: \(String(format: "%.1f", marketImpliedGrowth))%
        - FCF Yield: \(String(format: "%.2f", fcfYield))%
        - PEG Ratio: \(String(format: "%.2f", peg))
        - Beta: \(betaInput.map { String(format: "%.2f", $0) } ?? "N/A")
        - Net Cash (B): \(String(format: "%.2f", parseDouble(cashInput) - parseDouble(debtInput)))
        - Historical 5Y FCF CAGR: \(fcfCagrDisplay ?? "N/A")
        - Earnings beats (last 8Q): \(beatCount)/\(earningsData.count)
        - Exit Multiple: \(String(format: "%.1f", exitMultiple))x

        Provide a structured investment analysis in exactly this format:

        ## Summary
        2-3 sentences on the overall valuation picture.

        ## Strengths
        3 bullet points of the most compelling investment arguments.

        ## Risks
        3 bullet points of the key risks to the thesis.

        ## Verdict
        One of: BUY / HOLD / AVOID — with a one-sentence justification.

        Be concise, data-driven, and direct. No disclaimers.
        """

        let key = userGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                //let (data, _) = try await URLSession.shared.data(for: req)
                
                let (data, response) = try await URLSession.shared.data(for: req)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let errorString = String(data: data, encoding: .utf8) ?? "Erreur inconnue"
                    print("❌ ERREUR GOOGLE API (Status \(httpResponse.statusCode)): \(errorString)")
                    await MainActor.run {
                        self.aiAnalysis = "Erreur \(httpResponse.statusCode): \(errorString)"
                        self.isGeneratingAI = false
                        self.showAISheet = true
                    }
                    return
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    await MainActor.run {
                        self.aiAnalysis = text
                        self.isGeneratingAI = false
                        self.showAISheet = true
                    }
                } else {
                    await MainActor.run {
                        self.aiAnalysis = "Error: Could not parse Gemini response. Check your API key in Settings."
                        self.isGeneratingAI = false
                        self.showAISheet = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiAnalysis = "Error: \(error.localizedDescription)"
                    self.isGeneratingAI = false
                    self.showAISheet = true
                }
            }
        }
    }

    // MARK: - History
    func saveToHistory(_ entry: AnalysisHistoryEntry) {
        analysisHistory.removeAll { $0.ticker == entry.ticker }
        analysisHistory.insert(entry, at: 0)
        if analysisHistory.count > 50 { analysisHistory = Array(analysisHistory.prefix(50)) }
        if let encoded = try? JSONEncoder().encode(analysisHistory) {
            UserDefaults.standard.set(encoded, forKey: "analysisHistory")
        }
    }

    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "analysisHistory"),
           let decoded = try? JSONDecoder().decode([AnalysisHistoryEntry].self, from: data) {
            analysisHistory = decoded
        }
        projectionYears = defaultProjectionYears
    }

    func loadFromHistory(_ entry: AnalysisHistoryEntry) {
        ticker = entry.ticker
        stockName = entry.stockName
        currentPrice = entry.currentPrice
        intrinsicValue = entry.intrinsicValue
        priceDisplay = String(format: "%.2f %@", entry.currentPrice, entry.currencySymbol)
        currencySymbol = entry.currencySymbol
        growthRate = entry.growthRate
        discountRate = entry.discountRate
        exitMultiple = entry.exitMultiple
        fcfCagrDisplay = entry.fcfCagrDisplay
        showHistorySheet = false
    }

    // MARK: - Compare
    func addToCompare() {
        guard hasCalculated else { return }
        let snap = CompareSnapshot(
            ticker: ticker.uppercased(), stockName: stockName,
            currentPrice: currentPrice, intrinsicValue: intrinsicValue,
            growthRate: growthRate, discountRate: discountRate, exitMultiple: exitMultiple,
            fcfInput: fcfInput, cashInput: cashInput, debtInput: debtInput,
            currentPEInput: currentPEInput, currencySymbol: currencySymbol,
            betaInput: betaInput, fcfCagrDisplay: fcfCagrDisplay,
            scenarioResults: scenarioResults, projectionYears: projectionYears
        )
        compareSnapshots.removeAll { $0.ticker == snap.ticker }
        compareSnapshots.append(snap)
        if compareSnapshots.count >= 2 { showCompareSheet = true }
    }

    @MainActor
    func exportToPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(ticker.isEmpty ? "Analysis" : ticker.uppercased())_DCF_Analysis.pdf"
        panel.title = "Export DCF Analysis"
        panel.canCreateDirectories = true

        // runModal() is blocking and safe on MainActor — avoids the completion-handler threading crash
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Snapshot all state before Task (already on MainActor)
        let snap = (
            ticker: ticker.uppercased(), stockName: stockName, currentPrice: currentPrice,
            intrinsicValue: intrinsicValue, currencySymbol: currencySymbol, growthRate: growthRate,
            discountRate: discountRate, exitMultiple: exitMultiple, marginOfSafety: marginOfSafety,
            fcfInput: fcfInput, cashInput: cashInput, debtInput: debtInput, sharesInput: sharesInput,
            currentPEInput: currentPEInput, fcfCagrDisplay: fcfCagrDisplay, betaInput: betaInput,
            fcfHistory: fcfHistory, projectionData: projectionData, priceTarget: priceTarget,
            earningsData: earningsData, marketImpliedGrowth: marketImpliedGrowth,
            scenarioResults: scenarioResults, logoUrl: logoUrl, monteCarloResults: monteCarloResults
        )
        let simFn = runSimulation

        Task { @MainActor in
            let pdfView = PDFExportView(
                ticker: snap.ticker, stockName: snap.stockName, currentPrice: snap.currentPrice,
                intrinsicValue: snap.intrinsicValue, currencySymbol: snap.currencySymbol,
                growthRate: snap.growthRate, discountRate: snap.discountRate,
                exitMultiple: snap.exitMultiple, marginOfSafety: snap.marginOfSafety,
                fcfInput: snap.fcfInput, cashInput: snap.cashInput, debtInput: snap.debtInput,
                sharesInput: snap.sharesInput, currentPEInput: snap.currentPEInput,
                fcfCagrDisplay: snap.fcfCagrDisplay, betaInput: snap.betaInput,
                fcfHistory: snap.fcfHistory, projectionData: snap.projectionData,
                priceTarget: snap.priceTarget, earningsData: snap.earningsData,
                parseDouble: parseDouble, marketImpliedGrowth: snap.marketImpliedGrowth,
                scenarioResults: snap.scenarioResults, calculateSimulation: simFn,
                logoUrl: snap.logoUrl, monteCarloResults: snap.monteCarloResults
            )
            // Render to CGImage first (avoids all CGContext flip/coordinate issues)
            let renderer = ImageRenderer(content: pdfView)
            renderer.scale = 2.0
            guard let cgImage = renderer.cgImage else { return }

            let pageWidth: CGFloat = 794
            let pageHeight: CGFloat = CGFloat(cgImage.height) * pageWidth / CGFloat(cgImage.width)
            var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

            guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }
            pdf.beginPDFPage(nil)
            // Draw image straight into the PDF box — CGImage draw is always top-left, no flip needed
            pdf.draw(cgImage, in: mediaBox)
            pdf.endPDFPage()
            pdf.closePDF()
        }
    }
}

// MARK: - 5. SUBVIEWS

struct ResultHeaderView: View {
    var priceDisplay: String; var intrinsicValue: Double; var currentPrice: Double; var symbol: String
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 50) {
                VStack { Text("Current Price").font(.headline).foregroundColor(.secondary); Text(priceDisplay).font(.system(size: 36, weight: .bold)) }
                Image(systemName: "arrow.right").font(.largeTitle).opacity(0.3)
                VStack { Text("Intrinsic Value (Base)").font(.headline).foregroundColor(.secondary); Text(String(format: "%.2f %@", intrinsicValue, symbol)).font(.system(size: 36, weight: .bold)).foregroundColor(intrinsicValue > currentPrice ? .green : .red) }
            }
            if currentPrice > 0 && intrinsicValue > 0 {
                let margin = ((intrinsicValue - currentPrice) / intrinsicValue) * 100
                HStack(spacing: 8) {
                    Image(systemName: margin > 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    Text(margin > 0 ? "Undervalued by" : "Overvalued by").fontWeight(.bold).textCase(.uppercase)
                    Text(String(format: "%.1f %%", abs(margin))).fontWeight(.black)
                }.font(.callout).padding(.horizontal, 16).padding(.vertical, 8).background(margin > 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15)).foregroundColor(margin > 0 ? .green : .red).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(margin > 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1))
            }
        }
    }
}

struct ValuationBarChart: View {
    var marketPrice: Double; var intrinsicValue: Double; var symbol: String
    @State private var selectedItem: String?
    var data: [(type: String, value: Double, color: Color)] { [("Market", marketPrice, .gray.opacity(0.4)), ("Value", intrinsicValue, intrinsicValue >= marketPrice ? .green : .red)] }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Chart {
                ForEach(data, id: \.type) { item in BarMark(x: .value("Type", item.type), y: .value("Price", item.value)).foregroundStyle(item.color.gradient).annotation(position: .top) { Text("\(Int(item.value)) \(symbol)").font(.caption).bold().foregroundColor(.secondary) } }
                if let selectedItem, let item = data.first(where: { $0.type == selectedItem }) {
                    RuleMark(x: .value("Type", selectedItem)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack(alignment: .leading) { Text(item.type).font(.caption).bold(); Text(String(format: "%.2f %@", item.value, symbol)).font(.caption2) }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4)
                    }.zIndex(10)
                }
            }.chartOverlay { proxy in GeometryReader { geo in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedItem = x } case .ended: selectedItem = nil } } } }
        }
    }
}

// MODIFIÉ : Ajout du Hover Interactif
struct ScenarioComparisonChart: View {
    let data: [ScenarioResult]; let currentPrice: Double; let symbol: String
    @State private var selectedScenario: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "chart.bar.xaxis.ascending").font(.title2).foregroundColor(.blue); Text("Scenario Analysis (-30% / +30%)").font(.headline).foregroundColor(.secondary) }
            Chart {
                RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5])).annotation(position: .leading) { Text("Price").font(.caption).foregroundColor(.red) }
                ForEach(data) { item in BarMark(x: .value("Scenario", item.name), y: .value("Value", item.value)).foregroundStyle(item.color.gradient).annotation(position: .top) { Text(String(format: "%.0f %@", item.value, symbol)).font(.caption).bold() } }
                if let sel = selectedScenario, let item = data.first(where: { $0.name == sel }) {
                    RuleMark(x: .value("Scenario", sel)).foregroundStyle(Color.gray.opacity(0.2)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sel).bold().font(.caption)
                            Text(String(format: "%.2f %@", item.value, symbol)).font(.caption2).foregroundColor(item.color)
                            if currentPrice > 0 { let d = ((item.value - currentPrice) / currentPrice) * 100; Text(String(format: "vs market: %@%.1f%%", d >= 0 ? "+" : "", d)).font(.caption2).foregroundColor(d >= 0 ? .green : .red) }
                        }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4)
                    }.zIndex(10)
                }
            }.frame(height: 300).chartYAxis { AxisMarks(position: .leading) }.chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedScenario = x }; case .ended: selectedScenario = nil } } } }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct InteractiveReverseDCFView: View {
    var impliedGrowth: Double; var userGrowth: Double; var currentPrice: Double; var symbol: String; let calculateValuation: (Double) -> Double
    @State private var sliderGrowth: Double
    init(impliedGrowth: Double, userGrowth: Double, currentPrice: Double, symbol: String, calculateValuation: @escaping (Double) -> Double) { self.impliedGrowth = impliedGrowth; self.userGrowth = userGrowth; self.currentPrice = currentPrice; self.symbol = symbol; self.calculateValuation = calculateValuation; _sliderGrowth = State(initialValue: impliedGrowth) }
    var dynamicValue: Double { calculateValuation(sliderGrowth) }
    var isRisky: Bool { impliedGrowth > userGrowth }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 20) {
                Image(systemName: isRisky ? "exclamationmark.triangle.fill" : "hand.thumbsup.fill").font(.largeTitle).foregroundColor(isRisky ? .orange : .green).frame(width: 50)
                VStack(alignment: .leading, spacing: 5) { Text("Reverse DCF (Market Expectations)").font(.headline).foregroundColor(.secondary); Text("To justify the price of \(String(format: "%.2f %@", currentPrice, symbol)), the market expects a growth of:").font(.caption).foregroundColor(.secondary); HStack(alignment: .firstTextBaseline) { Text(String(format: "%.1f%%", impliedGrowth)).font(.title2).bold().foregroundColor(isRisky ? .orange : .primary); Text("per year").font(.caption).bold().foregroundColor(.secondary); Text(isRisky ? "(Higher than your \(String(format: "%.1f", userGrowth))%)" : "(Lower than your \(String(format: "%.1f", userGrowth))%)").font(.caption).foregroundColor(isRisky ? .red : .green).padding(.leading, 5) } }
                Spacer()
            }
            Divider()
            VStack(spacing: 5) { HStack { Text("Test Market Growth: \(String(format: "%.1f%%", sliderGrowth))").font(.caption).bold(); Spacer(); Text("Simulated Value: \(String(format: "%.2f", dynamicValue)) \(symbol)").font(.headline).foregroundColor(dynamicValue > currentPrice ? .green : .red) }; Slider(value: $sliderGrowth, in: -5...35, step: 0.5) }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isRisky ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1))
    }
}

// AMÉLIORÉ : Reverse DCF Curve Chart — X = Implied Growth, Y = Intrinsic Value
struct ReverseDCFChartView: View {
    let currentPrice: Double
    let userGrowth: Double
    let calculateValuation: (Double) -> Double
    let symbol: String

    // Implied growth = growth at which DCF value == market price (solved by binary search)
    var impliedGrowth: Double {
        var lo = -5.0, hi = 30.0
        for _ in 0..<80 {
            let mid = (lo + hi) / 2.0
            if calculateValuation(mid) < currentPrice { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2.0
    }

    struct ChartPt: Identifiable { let id = UUID(); let growth: Double; let value: Double }
    var chartData: [ChartPt] {
        stride(from: -5.0, through: 32.0, by: 0.5).map { ChartPt(growth: $0, value: calculateValuation($0)) }
    }

    @State private var hoveredGrowth: Double? = nil

    var hoveredPt: ChartPt? {
        guard let hg = hoveredGrowth else { return nil }
        return chartData.min(by: { abs($0.growth - hg) < abs($1.growth - hg) })
    }

    var allValues: [Double] { chartData.map(\.value) }
    var yMin: Double { max(0, (allValues.min() ?? 0) * 0.85) }
    var yMax: Double { (allValues.max() ?? 100) * 1.1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line").font(.title2).foregroundColor(.blue)
                Text("Reverse DCF Curve").font(.headline).foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Implied growth to justify market price")
                        .font(.caption2).foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", impliedGrowth))
                        .font(.title3).bold().foregroundColor(.orange)
                }
            }

            // Summary pills
            HStack(spacing: 12) {
                pill(label: "Your estimate", value: userGrowth, color: .blue)
                pill(label: "Market implied", value: impliedGrowth, color: .orange)
                let gap = userGrowth - impliedGrowth
                HStack(spacing: 4) {
                    Image(systemName: gap > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(gap > 0 ? .green : .red).font(.caption)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Gap").font(.caption2).foregroundColor(.secondary)
                        Text(String(format: "%@%.1f%%", gap > 0 ? "+" : "", gap))
                            .font(.caption).bold().foregroundColor(gap > 0 ? .green : .red)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.gray.opacity(0.08)).cornerRadius(7)
            }

            Chart {
                // Area fill under curve
                ForEach(chartData) { pt in
                    AreaMark(x: .value("Growth (%)", pt.growth), y: .value("Intrinsic Value", pt.value))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.18), Color.blue.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                }
                // Main DCF curve
                ForEach(chartData) { pt in
                    LineMark(x: .value("Growth (%)", pt.growth), y: .value("Intrinsic Value", pt.value))
                        .foregroundStyle(Color.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                }
                // Market price horizontal rule
                if currentPrice > 0 {
                    RuleMark(y: .value("Market Price", currentPrice))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Market Price: \(String(format: "%.0f", currentPrice)) \(symbol)")
                                .font(.caption2).bold().foregroundColor(.orange)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1)).cornerRadius(4)
                        }
                }
                // Implied growth vertical rule (intersection point)
                RuleMark(x: .value("Implied Growth", impliedGrowth))
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .bottom, alignment: .center) {
                        Text(String(format: "%.1f%%", impliedGrowth))
                            .font(.caption2).bold().foregroundColor(.orange)
                    }
                // User's growth vertical rule
                RuleMark(x: .value("Your Growth", userGrowth))
                    .foregroundStyle(.blue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .center) {
                        Text(String(format: "%.1f%%", userGrowth))
                            .font(.caption2).bold().foregroundColor(.blue)
                    }
                // Hover crosshair
                if let pt = hoveredPt {
                    PointMark(x: .value("Growth", pt.growth), y: .value("Value", pt.value))
                        .foregroundStyle(.blue)
                        .symbolSize(80)
                    RuleMark(x: .value("HoverG", pt.growth))
                        .foregroundStyle(Color.gray.opacity(0.25))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Growth: \(String(format: "%.1f%%", pt.growth))").font(.caption).bold()
                                Text("Fair Value: \(String(format: "%.2f %@", pt.value, symbol))")
                                    .font(.caption2).foregroundColor(.blue)
                                if currentPrice > 0 {
                                    let upside = ((pt.value - currentPrice) / currentPrice) * 100
                                    Text(String(format: "vs Market: %@%.1f%%", upside >= 0 ? "+" : "", upside))
                                        .font(.caption2).foregroundColor(upside >= 0 ? .green : .red)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(8).shadow(radius: 4)
                        }
                        .zIndex(10)
                }
            }
            .chartYScale(domain: yMin...yMax)
            .chartXAxisLabel("Implied FCF Growth Rate (%)", alignment: .center)
            .chartYAxisLabel("Intrinsic Value (\(symbol))", alignment: .center)
            .frame(height: 360)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc):
                                if let x: Double = proxy.value(atX: loc.x) { hoveredGrowth = x }
                            case .ended:
                                hoveredGrowth = nil
                            }
                        }
                }
            }

            HStack(spacing: 16) {
                legendLine(color: .blue, label: "DCF Fair Value curve")
                legendLine(color: .orange, label: "Market price / implied growth")
                legendLine(color: .blue.opacity(0.5), label: "Your growth estimate")
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.15), lineWidth: 1))
    }

    func pill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(String(format: "%.1f%%", value)).font(.caption).bold().foregroundColor(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(color.opacity(0.08)).cornerRadius(7)
    }

    func legendLine(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(color).frame(width: 16, height: 2).cornerRadius(1)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MODIFIÉ : Ajout du Hover Interactif
struct MonteCarloChart: View {
    let results: [MonteCarloResult]; let symbol: String; let currentPrice: Double; @State private var hoveredVal: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "dice.fill").font(.title2).foregroundColor(.purple); Text("Monte Carlo Simulation (1,000 runs)").font(.headline).foregroundColor(.secondary) }; Text("Probability distribution based on randomized growth and exit multiples.").font(.caption).foregroundColor(.secondary)
            Chart {
                ForEach(results) { item in BarMark(x: .value("Value", (item.bucketMin + item.bucketMax) / 2), y: .value("Frequency", item.frequency)).foregroundStyle(Color.purple.gradient) }
                if currentPrice > 0 { RuleMark(x: .value("Market Price", currentPrice)).foregroundStyle(.orange).lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4])).annotation(position: .top, alignment: .trailing) { Text("Market").font(.caption2).foregroundColor(.orange) } }
                if let val = hoveredVal, let item = results.first(where: { val >= $0.bucketMin && val <= $0.bucketMax }) {
                    RuleMark(x: .value("Value", (item.bucketMin + item.bucketMax) / 2)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 3) { Text("Between \(Int(item.bucketMin)) and \(Int(item.bucketMax)) \(symbol)").font(.caption).bold(); Text("Probability: \(String(format: "%.1f", Double(item.frequency)/10.0))%").font(.caption2).foregroundColor(.purple) }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10)
                }
            }.chartXAxisLabel("Intrinsic Value (\(symbol))").chartYAxisLabel("Frequency").frame(height: 300).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: Double = proxy.value(atX: l.x) { hoveredVal = x }; case .ended: hoveredVal = nil } } } }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct ProjectedGrowthChart: View {
    var data: [ProjectionPoint]; var currentPrice: Double; var symbol: String; @State private var selectedYear: Int?
    var yDomain: ClosedRange<Double> { let all = data.map { $0.value } + [currentPrice]; return ((all.min() ?? 0) * 0.9)...((all.max() ?? 100) * 1.1) }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) { HStack { Image(systemName: "chart.line.uptrend.xyaxis").font(.title2).foregroundColor(.blue); Text("Value Projection vs Price").font(.headline).foregroundColor(.secondary) }; HStack(spacing: 15) { HStack(spacing: 5) { Image(systemName: "circle.fill").foregroundColor(.blue).font(.caption); Text("Intrinsic Value").font(.caption).bold() }; HStack(spacing: 5) { Image(systemName: "line.horizontal.3").foregroundColor(.red).font(.caption); Text("Current Price").font(.caption).bold() } } }
            Chart {
                RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5])).annotation(position: .top, alignment: .leading) { Text("Price: \(Int(currentPrice))\(symbol)").font(.caption2).foregroundColor(.red) }
                ForEach(data) { point in LineMark(x: .value("Year", point.year), y: .value("Value", point.value)).foregroundStyle(.blue).interpolationMethod(.monotone); PointMark(x: .value("Year", point.year), y: .value("Value", point.value)).foregroundStyle(.blue).symbolSize(60) }
                if let selectedYear, let point = data.first(where: { $0.year == selectedYear }) { RuleMark(x: .value("Year", selectedYear)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 4) { Text("Year \(point.year)").font(.caption).bold().foregroundColor(.primary); Text("Value: \(Int(point.value)) \(symbol)").font(.caption).bold().foregroundColor(.blue) }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) }
            }.chartYScale(domain: yDomain).chartXScale(domain: 0...5).frame(height: 375).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: Int = proxy.value(atX: l.x) { selectedYear = x }; case .ended: selectedYear = nil } } } }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct PaybackTimeView: View {
    let fcfPerShare: Double; let currentPrice: Double; let growthRate: Double
    var paybackYears: Double? { guard currentPrice > 0, fcfPerShare > 0 else { return nil }; var currentFCF = fcfPerShare; var sum = 0.0; var years = 0; while sum < currentPrice && years < 50 { years += 1; sum += currentFCF; currentFCF *= (1 + growthRate / 100.0) }; return Double(years) }

    struct AccumPoint: Identifiable { let id = UUID(); let year: Int; let cumFCF: Double }
    var accumData: [AccumPoint] {
        guard fcfPerShare > 0 else { return [] }
        var pts: [AccumPoint] = []; var fcf = fcfPerShare; var sum = 0.0
        for yr in 1...min(Int(paybackYears ?? 0) + 5, 30) {
            sum += fcf; pts.append(AccumPoint(year: yr, cumFCF: sum)); fcf *= (1 + growthRate / 100.0)
            if sum > currentPrice * 1.4 { break }
        }
        return pts
    }
    @State private var hoveredYear: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "timer").font(.title2).foregroundColor(.blue)
                Text("Payback Time").font(.headline).foregroundColor(.secondary)
                Spacer()
                if let years = paybackYears {
                    Text("\(Int(years)) Years").font(.system(size: 28, weight: .bold))
                        .foregroundColor(years < 10 ? .green : years < 15 ? .orange : .red)
                } else { Text("N/A").foregroundColor(.gray) }
            }
            Text("Years to recoup your investment through cumulative projected FCF.").font(.caption).foregroundColor(.secondary)
            if !accumData.isEmpty {
                let allVals = accumData.map(\.cumFCF) + [currentPrice]
                let yMax = (allVals.max() ?? currentPrice) * 1.15
                Chart {
                    ForEach(accumData) { pt in
                        LineMark(x: .value("Year", pt.year), y: .value("Cumulative FCF", pt.cumFCF))
                            .foregroundStyle(Color.blue.gradient).interpolationMethod(.monotone)
                        AreaMark(x: .value("Year", pt.year), y: .value("Cumulative FCF", pt.cumFCF))
                            .foregroundStyle(Color.blue.opacity(0.08).gradient).interpolationMethod(.monotone)
                    }
                    if currentPrice > 0 {
                        RuleMark(y: .value("Purchase Price", currentPrice))
                            .foregroundStyle(.orange).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Purchase Price").font(.caption2).foregroundColor(.orange)
                            }
                    }
                    if let hyr = hoveredYear, let pt = accumData.first(where: { $0.year == hyr }) {
                        PointMark(x: .value("Year", pt.year), y: .value("Cumulative FCF", pt.cumFCF))
                            .foregroundStyle(.blue).symbolSize(70)
                        RuleMark(x: .value("Year", pt.year))
                            .foregroundStyle(Color.gray.opacity(0.3))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Year \(pt.year)").font(.caption).bold()
                                    Text(String(format: "Cumul. FCF: %.2f", pt.cumFCF)).font(.caption2).foregroundColor(.blue)
                                    if currentPrice > 0 {
                                        let pct = (pt.cumFCF / currentPrice) * 100
                                        Text(String(format: "Recovered: %.0f%%", pct)).font(.caption2)
                                            .foregroundColor(pct >= 100 ? .green : .orange)
                                    }
                                }
                                .padding(8).background(Color(nsColor: .windowBackgroundColor))
                                .cornerRadius(8).shadow(radius: 4)
                            }
                            .zIndex(10)
                    }
                }
                .chartYScale(domain: 0...yMax).frame(height: 360)
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let l): if let x: Int = proxy.value(atX: l.x) { hoveredYear = x }
                                case .ended: hoveredYear = nil
                                }
                            }
                    }
                }
            }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

// MODIFIÉ : Retrait du Hover Interactif
struct SensitivityMatrixView: View {
    let baseGrowth: Double; let baseDiscount: Double; let currentPrice: Double; let calculate: (Double, Double) -> Double
    var growthSteps: [Double] { [baseGrowth-3, baseGrowth-2, baseGrowth-1, baseGrowth, baseGrowth+1, baseGrowth+2, baseGrowth+3] }
    var discountSteps: [Double] { [baseDiscount-3, baseDiscount-2, baseDiscount-1, baseDiscount, baseDiscount+1, baseDiscount+2, baseDiscount+3] }
    
    func getColor(value: Double) -> Color { guard currentPrice > 0 else { return .gray.opacity(0.1) }; let diff = (value - currentPrice) / currentPrice; if diff > 0 { return Color.green.opacity(min(diff * 2.5, 0.6) + 0.05) } else { return Color.red.opacity(min(abs(diff) * 2.5, 0.6) + 0.05) } }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "tablecells").font(.title2).foregroundColor(.blue)
                Text("Sensitivity Matrix (7x7 Heatmap)").font(.headline).foregroundColor(.secondary)
                Spacer()
            }
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("Disc. \\ Grwth").font(.caption2).foregroundColor(.secondary).frame(width: 70, alignment: .leading)
                    ForEach(growthSteps, id: \.self) { g in
                        Text("\(String(format: "%.0f", g))%").font(.caption2).bold().foregroundColor(g == baseGrowth ? .blue : .primary)
                    }
                }
                ForEach(discountSteps, id: \.self) { r in
                    GridRow {
                        Text("\(String(format: "%.1f", r))%").font(.caption2).bold().foregroundColor(r == baseDiscount ? .blue : .primary).frame(width: 70, alignment: .leading)
                        ForEach(growthSteps, id: \.self) { g in
                            let val = calculate(g, r)
                            Text(String(format: "%.0f", val))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(getColor(value: val))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke((r == baseDiscount && g == baseGrowth) ? Color.blue : Color.clear, lineWidth: 2))
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12)
    }
}

struct FinancialHealthView: View {
    var cash: Double; var debt: Double; var fcfPerShare: Double; var growthRate: Double; var symbol: String
    var netCash: Double { cash - debt }
    var fcfProjections: [Double] { var v: [Double] = []; var c = fcfPerShare; for _ in 1...5 { c = c * (1 + growthRate / 100.0); v.append(c) }; return v }
    var body: some View {
        VStack(spacing: 20) {
            HStack { Image(systemName: "shield.checkerboard").font(.title2).foregroundColor(.blue); Text("Risk & Growth Check").font(.headline).foregroundColor(.secondary); Spacer() }
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) { Text("Balance Sheet").font(.caption).bold().foregroundColor(.secondary)
                    if cash == 0 && debt == 0 { Text("Enter Cash & Debt").font(.caption).italic().foregroundColor(.secondary) } else { HStack(alignment: .bottom, spacing: 15) { VStack { Text(String(format: "%.1fB", cash)).font(.caption2); RoundedRectangle(cornerRadius: 6).fill(Color.green.gradient).frame(width: 30, height: 60 * (cash / max(cash, debt, 1.0))); Text("Cash").font(.tiny).bold() }; VStack { Text(String(format: "%.1fB", debt)).font(.caption2); RoundedRectangle(cornerRadius: 6).fill(Color.red.gradient).frame(width: 30, height: 60 * (debt / max(cash, debt, 1.0))); Text("Debt").font(.tiny).bold() } }.frame(height: 80); Text(netCash >= 0 ? "Net Cash (Safe)" : "Net Debt (Leveraged)").font(.tiny).bold().foregroundColor(netCash >= 0 ? .green : .red).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4) }
                }.padding().frame(maxWidth: .infinity).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                VStack(alignment: .leading, spacing: 10) { Text("Proj. FCF Growth (5Y)").font(.caption).bold().foregroundColor(.secondary)
                    if fcfPerShare > 0 { HStack(alignment: .bottom, spacing: 8) { let d = fcfProjections; let m = (d.max() ?? 1.0) * 1.1; ForEach(0..<5) { i in VStack(spacing: 2) { Spacer(); RoundedRectangle(cornerRadius: 4).fill(Color.blue.gradient).frame(height: 60 * (d[i] / m)); Text("\(Int(d[i]))").font(.system(size: 9)); Text("Y\(i+1)").font(.tiny).foregroundColor(.secondary) } } }.frame(height: 80); Text("CAGR: \(String(format: "%.1f", growthRate))%").font(.tiny).bold().foregroundColor(growthRate > 0 ? .green : .red).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4) } else { Text("Enter Positive FCF").font(.caption).italic().foregroundColor(.secondary) }
                }.padding().frame(maxWidth: .infinity).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            }
        }
    }
}

struct FCFHistoryChartView: View {
    let history: [FCFHistoryPoint]; let cagrDisplay: String?; @State private var selectedYear: String? = nil
    var minVal: Double { history.map { $0.value }.min() ?? 0 }; var maxVal: Double { history.map { $0.value }.max() ?? 1 }; var yMin: Double { min(0, minVal * 1.15) }; var yMax: Double { maxVal * 1.2 }
    func barColor(_ value: Double) -> Color { if value < 0 { return .red }; return .teal }
    func formatFCF(_ val: Double) -> String { let billions = val / 1_000_000_000; if abs(billions) >= 1 { return String(format: "%.1fB", billions) }; let millions = val / 1_000_000; return String(format: "%.0fM", millions) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Image(systemName: "dollarsign.arrow.circlepath").font(.title2).foregroundColor(.teal); Text("Free Cash Flow History (5Y)").font(.headline).foregroundColor(.secondary); Spacer(); if let cagr = cagrDisplay { HStack(spacing: 4) { Image(systemName: "wand.and.stars").font(.caption).foregroundColor(.blue); Text("5Y CAGR: \(cagr)").font(.caption).bold().foregroundColor(.blue) }.padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).cornerRadius(6) } }
            Chart { ForEach(history) { point in BarMark(x: .value("Year", point.year), y: .value("FCF", point.value)).foregroundStyle(barColor(point.value).gradient).annotation(position: point.value >= 0 ? .top : .bottom) { Text(formatFCF(point.value)).font(.caption2).bold().foregroundColor(barColor(point.value)) }; if let sel = selectedYear, sel == point.year { RuleMark(x: .value("Year", point.year)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 4) { Text(point.year).font(.caption).bold(); Text("FCF: \(formatFCF(point.value))").font(.caption2).foregroundColor(barColor(point.value)); Text(point.value >= 0 ? "Positive cash generation ✓" : "Negative FCF — watch carefully ⚠️").font(.caption2).foregroundColor(point.value >= 0 ? .green : .red) }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) } }; if history.contains(where: { $0.value < 0 }) || history.contains(where: { $0.value >= 0 }) { RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.gray.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])) } }
            .chartYScale(domain: yMin...yMax).frame(height: 330).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedYear = x }; case .ended: selectedYear = nil } } } }
            if history.count >= 2 { let first = history.first!.value; let last = history.last!.value; let trend = last > first; HStack(spacing: 6) { Image(systemName: trend ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill").foregroundColor(trend ? .green : .red); Text(trend ? "FCF trending upward over the period" : "FCF declining over the period — investigate why").font(.caption).foregroundColor(trend ? .green : .red) } }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.teal.opacity(0.2), lineWidth: 1))
    }
}

struct AnalystConsensusChart: View {
    let data: [FinnhubRecommendation]; @State private var selectedPeriod: String?
    var chartData: [RecChartItem] { var i: [RecChartItem] = []; for r in data { let d = r.period; i.append(RecChartItem(period: d, type: "Strong Buy", value: r.strongBuy, color: .green, order: 0)); i.append(RecChartItem(period: d, type: "Buy", value: r.buy, color: .mint, order: 1)); i.append(RecChartItem(period: d, type: "Hold", value: r.hold, color: .yellow, order: 2)); i.append(RecChartItem(period: d, type: "Sell", value: r.sell, color: .orange, order: 3)); i.append(RecChartItem(period: d, type: "Strong Sell", value: r.strongSell, color: .red, order: 4)) }; return i }
    func getDataForPeriod(_ p: String) -> FinnhubRecommendation? { return data.first { $0.period == p } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "person.wave.2.fill").font(.title2).foregroundColor(.blue); Text("Analyst Consensus Trend").font(.headline).foregroundColor(.secondary) }
            Chart {
                ForEach(chartData) { item in BarMark(x: .value("Period", item.period), y: .value("Count", item.value)).foregroundStyle(item.color) }
                if let selectedPeriod, let rec = getDataForPeriod(selectedPeriod) { RuleMark(x: .value("Period", selectedPeriod)).foregroundStyle(Color.gray.opacity(0.3)).lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5])).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 6) { Text("Period: \(selectedPeriod)").font(.caption).bold().foregroundColor(.primary); Divider(); tooltipRow(label: "Strong Buy", value: rec.strongBuy, color: .green); tooltipRow(label: "Buy", value: rec.buy, color: .mint); tooltipRow(label: "Hold", value: rec.hold, color: .yellow); tooltipRow(label: "Sell", value: rec.sell, color: .orange); tooltipRow(label: "Strong Sell", value: rec.strongSell, color: .red) }.padding(12).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(10).shadow(radius: 5) }.zIndex(10) }
            }.chartForegroundStyleScale(["Strong Buy": .green, "Buy": .mint, "Hold": .yellow, "Sell": .orange, "Strong Sell": .red]).frame(height: 375).padding(.top, 50).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedPeriod = x }; case .ended: selectedPeriod = nil } } } }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    func tooltipRow(label: String, value: Int, color: Color) -> some View { HStack { Circle().fill(color).frame(width: 8, height: 8); Text(label).font(.caption2).foregroundColor(.secondary); Spacer(); Text("\(value)").font(.caption2).bold().foregroundColor(.primary) } }
}

struct PriceTargetView: View {
    let priceTarget: FinnhubPriceTarget; let currentPrice: Double; let intrinsicValue: Double; let symbol: String; @State private var selectedLabel: String? = nil
    struct TargetBar: Identifiable { let id = UUID(); let label: String; let value: Double; let color: Color }
    var bars: [TargetBar] { var result: [TargetBar] = []; if currentPrice > 0 { result.append(TargetBar(label: "Current", value: currentPrice, color: .gray)) }; if intrinsicValue > 0 { result.append(TargetBar(label: "DCF Value", value: intrinsicValue, color: .blue)) }; if let low = priceTarget.targetLow, low > 0 { result.append(TargetBar(label: "Target Low", value: low, color: .orange)) }; if let median = priceTarget.targetMedian, median > 0 { result.append(TargetBar(label: "Target Median", value: median, color: .teal)) }; if let mean = priceTarget.targetMean, mean > 0 { result.append(TargetBar(label: "Target Mean", value: mean, color: .purple)) }; if let high = priceTarget.targetHigh, high > 0 { result.append(TargetBar(label: "Target High", value: high, color: .green)) }; return result }
    var meanUpsidePct: Double? { guard let mean = priceTarget.targetMean, mean > 0, currentPrice > 0 else { return nil }; return ((mean - currentPrice) / currentPrice) * 100 }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Image(systemName: "scope").font(.title2).foregroundColor(.purple); Text("Analyst Price Targets").font(.headline).foregroundColor(.secondary); Spacer(); if let upside = meanUpsidePct { HStack(spacing: 4) { Image(systemName: upside >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill").foregroundColor(upside >= 0 ? .green : .red); Text(String(format: "Mean: %@%.1f%%", upside >= 0 ? "+" : "", upside)).font(.caption).bold().foregroundColor(upside >= 0 ? .green : .red) }.padding(.horizontal, 8).padding(.vertical, 4).background((upside >= 0 ? Color.green : Color.red).opacity(0.1)).cornerRadius(6) } }
            HStack(spacing: 10) { if let low = priceTarget.targetLow, low > 0 { statPill(label: "Low", value: low, color: .orange) }; if let median = priceTarget.targetMedian, median > 0 { statPill(label: "Median", value: median, color: .teal) }; if let mean = priceTarget.targetMean, mean > 0 { statPill(label: "Mean", value: mean, color: .purple) }; if let high = priceTarget.targetHigh, high > 0 { statPill(label: "High", value: high, color: .green) } }
            if let low = priceTarget.targetLow, let high = priceTarget.targetHigh, let mean = priceTarget.targetMean, low > 0, high > 0, currentPrice > 0 { let allVals = [low, high, currentPrice, mean]; let rangeMin = allVals.min()! * 0.9; let rangeMax = allVals.max()! * 1.1; let total = rangeMax - rangeMin; VStack(alignment: .leading, spacing: 6) { Text("Price Range Visualizer").font(.caption).bold().foregroundColor(.secondary); GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15)).frame(height: 24); let lowX = CGFloat((low - rangeMin) / total) * geo.size.width; let highX = CGFloat((high - rangeMin) / total) * geo.size.width; RoundedRectangle(cornerRadius: 6).fill(Color.teal.opacity(0.2)).frame(width: highX - lowX, height: 24).offset(x: lowX); let meanX = CGFloat((mean - rangeMin) / total) * geo.size.width; Capsule().fill(Color.purple).frame(width: 4, height: 30).offset(x: meanX - 2); let curX = CGFloat((currentPrice - rangeMin) / total) * geo.size.width; Capsule().fill(Color.orange).frame(width: 3, height: 30).offset(x: curX - 1.5); if intrinsicValue > 0 { let dcfClamped = min(max(intrinsicValue, rangeMin), rangeMax); let dcfX = CGFloat((dcfClamped - rangeMin) / total) * geo.size.width; Capsule().fill(Color.blue).frame(width: 3, height: 30).offset(x: dcfX - 1.5) } } }.frame(height: 30); HStack(spacing: 12) { legendDot(color: .teal, label: "Analyst range"); legendDot(color: .purple, label: "Mean target"); legendDot(color: .orange, label: "Current price"); if intrinsicValue > 0 { legendDot(color: .blue, label: "DCF value") } } } }
            Chart { ForEach(bars) { bar in BarMark(x: .value("Label", bar.label), y: .value("Price", bar.value)).foregroundStyle(bar.color.gradient).annotation(position: .top) { Text(String(format: "%.0f", bar.value)).font(.caption2).bold().foregroundColor(bar.color) }; if let sel = selectedLabel, sel == bar.label { RuleMark(x: .value("Label", sel)).foregroundStyle(Color.gray.opacity(0.2)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 3) { Text(bar.label).bold().font(.caption); Text(String(format: "%.2f %@", bar.value, symbol)).font(.caption2).foregroundColor(bar.color); if bar.label != "Current" && currentPrice > 0 { let d = ((bar.value - currentPrice) / currentPrice) * 100; Text(String(format: "vs current: %@%.1f%%", d >= 0 ? "+" : "", d)).font(.caption2).foregroundColor(d >= 0 ? .green : .red) } }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) } } }.frame(height: 330).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedLabel = x }; case .ended: selectedLabel = nil } } } }
            if let updated = priceTarget.lastUpdated { Text("Last updated: \(updated)").font(.caption2).foregroundColor(.secondary) }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
    func statPill(label: String, value: Double, color: Color) -> some View { VStack(spacing: 2) { Text(label).font(.caption2).foregroundColor(.secondary); Text(String(format: "%.2f", value)).font(.caption).bold().foregroundColor(color) }.padding(.horizontal, 10).padding(.vertical, 5).background(color.opacity(0.1)).cornerRadius(8) }
    func legendDot(color: Color, label: String) -> some View { HStack(spacing: 4) { Circle().fill(color).frame(width: 6, height: 6); Text(label).font(.caption2).foregroundColor(.secondary) } }
}

struct EarningsSurprisesView: View {
    let earnings: [FinnhubEarnings]; @State private var selectedPeriod: String? = nil
    struct EarningsBar: Identifiable { let id = UUID(); let period: String; let type: String; let value: Double; let color: Color }
    var chartData: [EarningsBar] { earnings.compactMap { e -> [EarningsBar]? in guard let period = e.period else { return nil }; let shortPeriod = String(period.prefix(7)); var bars: [EarningsBar] = []; if let est = e.estimate { bars.append(EarningsBar(period: shortPeriod, type: "Estimate", value: est, color: .gray.opacity(0.6))) }; if let act = e.actual { bars.append(EarningsBar(period: shortPeriod, type: "Actual", value: act, color: act >= (e.estimate ?? act) ? .green : .red)) }; return bars }.flatMap { $0 } }
    var beatCount: Int { earnings.filter { ($0.surprise ?? 0) > 0 }.count }
    var missCount: Int { earnings.filter { ($0.surprise ?? 0) < 0 }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Image(systemName: "chart.bar.doc.horizontal.fill").font(.title2).foregroundColor(.indigo); Text("Earnings Surprises (EPS)").font(.headline).foregroundColor(.secondary); Spacer(); HStack(spacing: 8) { HStack(spacing: 4) { Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.caption); Text("\(beatCount) beats").font(.caption).bold().foregroundColor(.green) }; HStack(spacing: 4) { Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.caption); Text("\(missCount) misses").font(.caption).bold().foregroundColor(.red) } } }
            if earnings.contains(where: { $0.surprisePercent != nil }) { VStack(alignment: .leading, spacing: 6) { Text("EPS Surprise %").font(.caption).bold().foregroundColor(.secondary); Chart { ForEach(earnings) { e in if let pct = e.surprisePercent, let period = e.period { let shortPeriod = String(period.prefix(7)); BarMark(x: .value("Period", shortPeriod), y: .value("Surprise %", pct)).foregroundStyle((pct >= 0 ? Color.green : Color.red).gradient).annotation(position: pct >= 0 ? .top : .bottom) { Text(String(format: "%@%.1f%%", pct >= 0 ? "+" : "", pct)).font(.system(size: 8)).bold().foregroundColor(pct >= 0 ? .green : .red) } } }; RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.gray.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])) }.frame(height: 150) }.padding(10).background(Color.gray.opacity(0.05)).cornerRadius(8) }
            Chart { ForEach(chartData) { bar in BarMark(x: .value("Period", bar.period), y: .value("EPS", bar.value)).foregroundStyle(bar.color.gradient).position(by: .value("Type", bar.type)) }; if let sel = selectedPeriod { let relevant = earnings.first { String(($0.period ?? "").prefix(7)) == sel }; if let e = relevant { RuleMark(x: .value("Period", sel)).foregroundStyle(Color.gray.opacity(0.25)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 4) { Text(sel).bold().font(.caption); if let est = e.estimate { Text(String(format: "Estimate: %.3f", est)).font(.caption2).foregroundColor(.gray) }; if let act = e.actual { Text(String(format: "Actual: %.3f", act)).font(.caption2).foregroundColor(act >= (e.estimate ?? act) ? .green : .red) }; if let pct = e.surprisePercent { Text(String(format: "Surprise: %@%.2f%%", pct >= 0 ? "+" : "", pct)).font(.caption2).bold().foregroundColor(pct >= 0 ? .green : .red) } }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) } } }.chartForegroundStyleScale(["Estimate": Color.gray.opacity(0.6), "Actual": Color.green]).frame(height: 300).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedPeriod = x }; case .ended: selectedPeriod = nil } } } }
            HStack(spacing: 12) { HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.6)).frame(width: 12, height: 8); Text("Estimate").font(.caption2).foregroundColor(.secondary) }; HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(Color.green).frame(width: 12, height: 8); Text("Beat").font(.caption2).foregroundColor(.secondary) }; HStack(spacing: 4) { RoundedRectangle(cornerRadius: 2).fill(Color.red).frame(width: 12, height: 8); Text("Miss").font(.caption2).foregroundColor(.secondary) }; Spacer(); Text("Hover bars for details").font(.caption2).foregroundColor(.secondary).italic() }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
    }
}

struct PeersComparisonView: View {
    let mainTicker: String; let mainPE: Double; let peers: [PeerData]; @State private var selectedTicker: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Image(systemName: "person.3.fill").font(.title2).foregroundColor(.blue); Text("Competitor Analysis (P/E)").font(.headline).foregroundColor(.secondary) }
            if mainPE == 0 { Text("Enter P/E to compare with peers").font(.caption).italic().foregroundColor(.secondary) } else {
                Chart {
                    BarMark(x: .value("Ticker", mainTicker), y: .value("P/E", mainPE)).foregroundStyle(Color.blue.gradient).annotation(position: .top) { Text(String(format: "%.1f", mainPE)).font(.caption).bold() }
                    ForEach(peers) { peer in BarMark(x: .value("Ticker", peer.ticker), y: .value("P/E", peer.pe)).foregroundStyle(Color.purple.opacity(0.3).gradient).annotation(position: .top) { Text(String(format: "%.1f", peer.pe)).font(.caption).foregroundColor(.secondary) } }
                    if let selectedTicker { RuleMark(x: .value("Ticker", selectedTicker)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { let peVal = (selectedTicker == mainTicker) ? mainPE : (peers.first(where: { $0.ticker == selectedTicker })?.pe ?? 0); VStack { Text(selectedTicker).bold(); Text("P/E: \(String(format: "%.2f", peVal))") }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) }
                }.frame(height: 300).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedTicker = x }; case .ended: selectedTicker = nil } } } }
            }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct PEComparisonChart: View {
    var currentPE: Double; var historicalPE: Double; var exitMultiple: Double; @State private var selectedType: String?
    var data: [PEDataPoint] { [.init(type: "Historical", value: historicalPE, color: .gray.opacity(0.5)), .init(type: "Current", value: currentPE, color: .gray), .init(type: "Exit (Yr 5)", value: exitMultiple, color: .blue)] }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Image(systemName: "chart.bar.xaxis").font(.title2).foregroundColor(.blue); Text("Valuation Reality Check (P/E Ratios)").font(.headline).foregroundColor(.secondary) }
            if currentPE == 0 && historicalPE == 0 && exitMultiple == 0 { Text("Enter P/E data to visualize comparison").font(.caption).italic().foregroundColor(.secondary) } else {
                Chart(data) { point in BarMark(x: .value("Type", point.type), y: .value("P/E Ratio", point.value)).foregroundStyle(point.color.gradient).annotation(position: .top) { Text(String(format: "%.1fx", point.value)).font(.caption).bold() } }
                .chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedType = x }; case .ended: selectedType = nil } } } }.frame(height: 300)
            }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct PEGRatioGauge: View {
    var currentPE: Double; var growthRate: Double; var peg: Double { growthRate > 0 ? currentPE / growthRate : 0.0 }; var pegProgress: CGFloat { CGFloat(min(peg, 3.0) / 3.0) }; var statusText: String { peg < 1.0 ? "Undervalued (<1.0)" : peg < 1.5 ? "Fair Value (1.0-1.5)" : "Overvalued (>1.5)" }; var statusColor: Color { peg < 1.0 ? .green : peg < 1.5 ? .yellow : .red }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "gauge.with.needle").font(.title2).foregroundColor(.blue); Text("PEG Ratio (Lynch Valuation)").font(.headline).foregroundColor(.secondary); Spacer(); Text(String(format: "%.2f", peg)).font(.title2).bold().foregroundColor(statusColor) }
            GeometryReader { geo in ZStack(alignment: .leading) { Rectangle().fill(LinearGradient(stops: [.init(color: .green.opacity(0.8), location: 0.0), .init(color: .green.opacity(0.8), location: 0.33), .init(color: .yellow, location: 0.33), .init(color: .yellow, location: 0.5), .init(color: .red.opacity(0.8), location: 0.5), .init(color: .red.opacity(0.8), location: 1.0)], startPoint: .leading, endPoint: .trailing)).frame(height: 20).cornerRadius(10); Image(systemName: "arrowtriangle.down.fill").foregroundColor(.primary).font(.title3).offset(x: (geo.size.width * pegProgress) - 10, y: -20); Text(statusText).font(.caption2).bold().foregroundColor(statusColor).offset(x: (geo.size.width * pegProgress) - 10, y: 22).fixedSize() } }.frame(height: 50)
            HStack { Text("0.0").font(.tiny); Spacer(); Text("1.0 (Cheap)").font(.tiny).padding(.trailing, 40); Spacer(); Text("3.0+").font(.tiny) }.foregroundColor(.gray)
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct FCFYieldGauge: View {
    var fcfPerShare: Double; var currentPrice: Double; var yield: Double { guard currentPrice > 0 else { return 0.0 }; return (fcfPerShare / currentPrice) * 100.0 }; var yieldProgress: CGFloat { let clamped = min(max(yield, 0.0), 10.0); return CGFloat(clamped / 10.0) }; var statusText: String { if yield < 3.0 { return "Expensive (<3%)" } else if yield < 7.0 { return "Fair (3-7%)" } else { return "Attractive (>7%)" } }; var statusColor: Color { if yield < 3.0 { return .red } else if yield < 7.0 { return .yellow } else { return .green } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "banknote.fill").font(.title2).foregroundColor(.blue); Text("FCF Yield (Market Payback)").font(.headline).foregroundColor(.blue); Spacer(); Text(String(format: "%.2f%%", yield)).font(.title2).bold().foregroundColor(statusColor) }
            GeometryReader { geo in ZStack(alignment: .leading) { Rectangle().fill(LinearGradient(stops: [.init(color: .red.opacity(0.8), location: 0.0), .init(color: .red.opacity(0.8), location: 0.3), .init(color: .yellow, location: 0.3), .init(color: .yellow, location: 0.7), .init(color: .green.opacity(0.8), location: 0.7), .init(color: .green.opacity(0.8), location: 1.0)], startPoint: .leading, endPoint: .trailing)).frame(height: 20).cornerRadius(10); Image(systemName: "arrowtriangle.down.fill").foregroundColor(.primary).font(.title3).offset(x: max(0, (geo.size.width * yieldProgress) - 10), y: -20); Text(statusText).font(.caption2).bold().foregroundColor(statusColor).offset(x: max(0, (geo.size.width * yieldProgress) - 10), y: 22).fixedSize() } }.frame(height: 50)
            HStack { Text("0%").font(.tiny); Spacer(); Text("5% (Avg)").font(.tiny); Spacer(); Text("10%+").font(.tiny) }.foregroundColor(.gray)
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct BuyBoxView: View {
    var intrinsicValue: Double; var currentPrice: Double; @Binding var marginOfSafety: Double; var symbol: String
    var targetBuyPrice: Double { intrinsicValue * (1.0 - (marginOfSafety / 100.0)) }; var isBuyable: Bool { currentPrice > 0 && currentPrice <= targetBuyPrice }
    var body: some View {
        VStack(spacing: 15) {
            HStack { Image(systemName: "cart.fill.badge.plus").font(.title2).foregroundColor(isBuyable ? .green : .secondary); Text("Entry Price Planner").font(.headline).foregroundColor(.secondary); Spacer(); Text(isBuyable ? "BUY ZONE" : "WAIT").font(.caption).fontWeight(.black).padding(.horizontal, 8).padding(.vertical, 4).background(isBuyable ? Color.green : Color.orange).foregroundColor(.white).cornerRadius(8) }
            Divider()
            VStack(alignment: .leading, spacing: 5) { HStack { Text("Margin of Safety").font(.caption).bold().foregroundColor(.secondary); Spacer(); Text("\(Int(marginOfSafety))%").font(.body).bold().foregroundColor(.blue) }; Slider(value: $marginOfSafety, in: 0...60, step: 5).tint(.blue) }
            HStack(alignment: .bottom) { VStack(alignment: .leading) { Text("Target Buy Price").font(.caption).foregroundColor(.secondary); Text(String(format: "%.2f %@", targetBuyPrice, symbol)).font(.system(size: 32, weight: .bold)).foregroundColor(isBuyable ? .green : .primary) }; Spacer(); if currentPrice > 0 { VStack(alignment: .trailing) { let delta = (currentPrice - targetBuyPrice) / targetBuyPrice * 100; Text(isBuyable ? "Discount" : "Premium").font(.caption).foregroundColor(isBuyable ? .green : .orange); Text(String(format: "%@%.1f%%", isBuyable ? "-" : "+", abs(delta))).font(.title3).bold().foregroundColor(isBuyable ? .green : .orange) } } }
        }.padding().background(ZStack { Color(nsColor: .controlBackgroundColor); if isBuyable { Color.green.opacity(0.05) } }).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isBuyable ? Color.green : Color.gray.opacity(0.2), lineWidth: isBuyable ? 2 : 1))
    }
}

struct PriceRangeChart: View {
    var currentPrice: Double; var yearHigh: Double; var symbol: String; @State private var selectedLabel: String?
    var drawdown: Double { guard yearHigh > 0 else { return 0.0 }; return ((currentPrice - yearHigh) / yearHigh) * 100.0 }
    struct BarData: Identifiable { let id = UUID(); let label: String; let value: Double; let color: Color }
    var data: [BarData] { [ .init(label: "52W High", value: yearHigh, color: .gray.opacity(0.5)), .init(label: "Current", value: currentPrice, color: .blue) ] }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "arrow.down.right.circle.fill").font(.title2).foregroundColor(.blue); Text("Price vs 52-Week High").font(.headline).foregroundColor(.secondary); Spacer(); if drawdown < -0.1 { Text("\(String(format: "%.1f", drawdown))%").font(.title3).bold().foregroundColor(.red) } }
            Chart(data) { item in BarMark(x: .value("Price", item.value), y: .value("Type", item.label)).foregroundStyle(item.color.gradient).annotation(position: .trailing) { Text(String(format: "%.2f %@", item.value, symbol)).font(.caption).foregroundColor(.secondary) }
                if let selectedLabel, selectedLabel == item.label { RuleMark(y: .value("Type", selectedLabel)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { Text("\(item.label): \(String(format: "%.2f", item.value))").padding(6).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(6).shadow(radius: 2) }.zIndex(10) }
            }.chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let y: String = proxy.value(atY: l.y) { selectedLabel = y }; case .ended: selectedLabel = nil } } } }.frame(height: 360).chartXAxis { AxisMarks(position: .bottom) }.chartYAxis { AxisMarks(position: .leading) }
            if drawdown < -20 { Text("📉 Trading significantly below highs. Potential opportunity if fundamentals are intact.").font(.caption).italic().foregroundColor(.secondary) }
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct ExoticBetaGauge: View {
    let beta: Double; private var normalizedBeta: Double { min(max(beta, 0.0), 3.0) / 3.0 }; private var colorZone: Color { return .blue }
    private var riskText: String { if beta < 0.8 { return "LOW VOLATILITY" }; if beta < 1.2 { return "MARKET AVG" }; if beta < 2.0 { return "HIGH VOLATILITY" }; return "SPECULATIVE" }
    var body: some View {
        VStack(spacing: 5) {
            HStack { Image(systemName: "bolt.horizontal.circle.fill").foregroundColor(colorZone); Text("MARKET RISK (BETA)").font(.headline).foregroundColor(.secondary); Spacer(); Text(String(format: "%.2f", beta)).font(.title2).fontWeight(.black).foregroundColor(colorZone) }
            ZStack {
                Circle().trim(from: 0.0, to: 0.5).stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 20, lineCap: .round)).rotationEffect(.degrees(180)).frame(height: 150)
                Circle().trim(from: 0.0, to: 0.5 * normalizedBeta).stroke(AngularGradient(gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue]), center: .center, startAngle: .degrees(180), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: 20, lineCap: .round)).rotationEffect(.degrees(180)).frame(height: 150).animation(.easeOut(duration: 1.5), value: beta)
                ForEach(0..<4) { i in VStack { Text("\(i)").font(.caption).fontWeight(.bold).foregroundColor(.secondary); Spacer() }.rotationEffect(.degrees(Double(i) * 60 - 90)).frame(height: 190) }
                Rectangle().fill(colorZone).frame(width: 4, height: 80).offset(y: -30).rotationEffect(.degrees(normalizedBeta * 180 - 90)).animation(.spring(response: 0.8, dampingFraction: 0.6), value: beta)
                Circle().fill(Color(nsColor: .windowBackgroundColor)).frame(width: 20, height: 20).overlay(Circle().stroke(Color.gray, lineWidth: 2))
                VStack { Spacer(); Text(riskText).font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundColor(colorZone).padding(.top, 40).shadow(color: colorZone.opacity(0.5), radius: 5) }
            }.frame(height: 110).padding(.bottom, 10)
        }.frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct InfoButton: View {
    let helpText: String; @State private var show = false
    var body: some View { Button(action: { show.toggle() }) { Image(systemName: "info.circle").foregroundColor(.secondary) }.buttonStyle(.plain).popover(isPresented: $show) { Text(helpText).padding().frame(width: 250) } }
}

struct DCFHelpView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Image(systemName: "graduationcap.fill").font(.title2).foregroundColor(.blue); Text("Understanding DCF").font(.title3).bold(); Spacer() }
                Text("Discounted Cash Flow (DCF) is a valuation method used to estimate the value of an investment based on its expected future cash flows.").font(.body)
                Text("The core principle is that a dollar today is worth more than a dollar tomorrow. This tool projects how much cash the company will generate in the future and 'discounts' it back to arrive at a fair price today.").font(.body).foregroundColor(.secondary)
                Divider()
                Text("Key Inputs Explained").font(.headline)
                VStack(alignment: .leading, spacing: 10) {
                    ExplanationRow(title: "FCF Growth Rate", desc: "The percentage by which you expect the company's cash flow to grow annually for the next 5 years. Be conservative.")
                    ExplanationRow(title: "Discount Rate (WACC)", desc: "The annual return you demand for the risk taken. Higher risk requires a higher rate. This number reduces the value of future money.")
                    ExplanationRow(title: "Exit Multiple", desc: "The valuation ratio (Price/FCF) you expect the market will pay for this stock after 5 years. Often aligned with historical averages.")
                }
            }.padding()
        }.frame(width: 400, height: 500)
    }
}

struct ExplanationRow: View {
    let title: String; let desc: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).bold().foregroundColor(.blue)
            Text(desc).font(.caption).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
        }.padding(10).background(Color.gray.opacity(0.1)).cornerRadius(8)
    }
}

// MARK: - PDF EXPORT VIEW (Vectoriel Complet)
struct PDFExportView: View {
    let ticker: String; let stockName: String; let currentPrice: Double; let intrinsicValue: Double; let currencySymbol: String
    let growthRate: Double; let discountRate: Double; let exitMultiple: Double; let marginOfSafety: Double
    let fcfInput: String; let cashInput: String; let debtInput: String; let sharesInput: String; let currentPEInput: String
    let fcfCagrDisplay: String?; let betaInput: Double?
    let fcfHistory: [FCFHistoryPoint]; let projectionData: [ProjectionPoint]; let priceTarget: FinnhubPriceTarget?
    let earningsData: [FinnhubEarnings]; let parseDouble: (String) -> Double
    let marketImpliedGrowth: Double
    let scenarioResults: [ScenarioResult]
    let calculateSimulation: (Double, Double) -> Double
    let logoUrl: String?
    let monteCarloResults: [MonteCarloResult]

    var updownPct: Double { guard currentPrice > 0, intrinsicValue > 0 else { return 0 }; return ((intrinsicValue - currentPrice) / intrinsicValue) * 100 }
    var targetBuyPrice: Double { intrinsicValue * (1.0 - (marginOfSafety / 100.0)) }
    var isBuyable: Bool { currentPrice > 0 && currentPrice <= targetBuyPrice }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // HEADER with logo
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Intrinsic").font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.8))
                    Text("\(ticker) — DCF Fair Value Analysis").font(.system(size: 26, weight: .black)).foregroundColor(.white)
                    if !stockName.isEmpty { Text(stockName).font(.headline).foregroundColor(.white.opacity(0.8)) }
                }
                Spacer()
                HStack(spacing: 12) {
                    // Company logo (fetched via AsyncImage — ImageRenderer captures it if already loaded)
                    if let logoStr = logoUrl, let url = URL(string: logoStr) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .background(Color.white.opacity(0.15))
                            }
                        }.frame(width: 48, height: 48)
                    }
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Fair Value Report").font(.caption).foregroundColor(.white.opacity(0.7))
                        Text(Date().formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                }
            }.padding(24).background(LinearGradient(colors: [Color.blue, Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    pdfStatCard(label: "Current Price", value: String(format: "%.2f %@", currentPrice, currencySymbol), color: .primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intrinsic Value").font(.caption2).foregroundColor(.secondary)
                        Text(String(format: "%.2f %@", intrinsicValue, currencySymbol)).font(.system(size: 16, weight: .bold)).foregroundColor(intrinsicValue > currentPrice ? .green : .red)
                        let upPct = currentPrice > 0 ? ((intrinsicValue - currentPrice) / intrinsicValue) * 100 : 0
                        Text(String(format: "%@ %.1f%%", upPct >= 0 ? "▲" : "▼", abs(upPct)))
                            .font(.caption2).bold().foregroundColor(upPct >= 0 ? .green : .red)
                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.gray.opacity(0.08)).cornerRadius(8)
                    pdfStatCard(label: "Implied Market Growth", value: String(format: "%.1f%%", marketImpliedGrowth), color: .purple)
                    pdfStatCard(label: "Buy Target (\(Int(marginOfSafety))% MoS)", value: String(format: "%.2f %@", targetBuyPrice, currencySymbol), color: isBuyable ? .green : .orange)
                }
                Divider()
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DCF Parameters").font(.headline).foregroundColor(.secondary)
                        pdfKeyValue("FCF/Share", fcfInput); pdfKeyValue("Growth Rate", String(format: "%.1f%%", growthRate)); pdfKeyValue("Discount Rate", String(format: "%.1f%%", discountRate)); pdfKeyValue("Exit Multiple", String(format: "%.1fx", exitMultiple))
                        if let cagr = fcfCagrDisplay { pdfKeyValue("5Y FCF CAGR", cagr) }
                        if let beta = betaInput { pdfKeyValue("Beta", String(format: "%.2f", beta)) }
                        pdfKeyValue("Reverse DCF Growth", String(format: "%.1f%%", marketImpliedGrowth))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Balance Sheet").font(.headline).foregroundColor(.secondary)
                        pdfKeyValue("Cash (B)", cashInput); pdfKeyValue("Debt (B)", debtInput); pdfKeyValue("Shares (B)", sharesInput); pdfKeyValue("Current P/E", currentPEInput)
                        if let pt = priceTarget, let mean = pt.targetMean { pdfKeyValue("Analyst Target (Mean)", String(format: "%.2f", mean)) }
                    }
                }
                Divider()
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        if !scenarioResults.isEmpty {
                            Text("Scenario Analysis (-30% / +30%)").font(.headline).foregroundColor(.secondary)
                            Chart {
                                RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                                ForEach(scenarioResults) { item in BarMark(x: .value("Scenario", item.name), y: .value("Value", item.value)).foregroundStyle(item.color.gradient).annotation(position: .top) { Text(String(format: "%.0f", item.value)).font(.caption2).bold() } }
                            }.frame(height: 210).chartYAxis { AxisMarks(position: .leading) }
                        }
                        if !projectionData.isEmpty {
                            Text("Value Projection (5Y)").font(.headline).foregroundColor(.secondary)
                            Chart {
                                RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                                ForEach(projectionData) { pt in LineMark(x: .value("Year", pt.year), y: .value("Value", pt.value)).foregroundStyle(.blue).interpolationMethod(.monotone); PointMark(x: .value("Year", pt.year), y: .value("Value", pt.value)).foregroundStyle(.blue) }
                            }.frame(height: 210)
                        }
                    }.frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        if growthRate > 0 && discountRate > 0 {
                            PDFSensitivityMatrix(baseGrowth: growthRate, baseDiscount: discountRate, currentPrice: currentPrice, calculate: calculateSimulation)
                        }
                        if !fcfHistory.isEmpty {
                            Text("FCF History").font(.headline).foregroundColor(.secondary)
                            Chart {
                                ForEach(fcfHistory) { pt in BarMark(x: .value("Year", pt.year), y: .value("FCF", pt.value)).foregroundStyle((pt.value >= 0 ? Color.teal : Color.red).gradient).annotation(position: pt.value >= 0 ? .top : .bottom) { Text(String(format: "%.1f", pt.value)).font(.system(size: 8)) } }
                                RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.gray.opacity(0.5))
                            }.frame(height: 120)
                        }
                        // Monte Carlo bottom-right
                        if !monteCarloResults.isEmpty {
                            Text("Monte Carlo (1000 simulations)").font(.headline).foregroundColor(.secondary)
                            let mcMin = monteCarloResults.map(\.bucketMin).min() ?? 0
                            let mcMax = monteCarloResults.map(\.bucketMax).max() ?? 1
                            Chart {
                                ForEach(monteCarloResults) { r in
                                    let center = (r.bucketMin + r.bucketMax) / 2
                                    BarMark(x: .value("Value", center), y: .value("Count", r.frequency))
                                        .foregroundStyle((center >= currentPrice ? Color.green : Color.red).opacity(0.7).gradient)
                                }
                                if currentPrice > 0 {
                                    RuleMark(x: .value("Market", currentPrice))
                                        .foregroundStyle(.orange)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                        .annotation(position: .top) {
                                            Text("Market").font(.system(size: 7)).foregroundColor(.orange)
                                        }
                                }
                            }
                            .chartXScale(domain: mcMin...mcMax)
                            .frame(height: 150)
                            let aboveCount = monteCarloResults.filter { ($0.bucketMin + $0.bucketMax) / 2 >= currentPrice }.map(\.frequency).reduce(0, +)
                            let totalCount = monteCarloResults.map(\.frequency).reduce(0, +)
                            let prob = totalCount > 0 ? Double(aboveCount) / Double(totalCount) * 100 : 0
                            Text(String(format: "Upside probability: %.0f%% of scenarios > market price", prob))
                                .font(.system(size: 8)).foregroundColor(prob > 50 ? .green : .red)
                        }
                    }.frame(maxWidth: .infinity)
                }
                Divider()
                Text("⚠️ This analysis is for informational purposes only and does not constitute financial advice. Always do your own due diligence before investing.").font(.caption2).foregroundColor(.secondary).italic()
            }.padding(24)
        }.frame(width: 794).background(Color(nsColor: .windowBackgroundColor))
    }
    func pdfStatCard(label: String, value: String, color: Color) -> some View { VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption2).foregroundColor(.secondary); Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.gray.opacity(0.08)).cornerRadius(8) }
    func pdfKeyValue(_ key: String, _ value: String) -> some View { HStack { Text(key).font(.caption).foregroundColor(.secondary); Spacer(); Text(value).font(.caption).bold() } }
}

// PDF-safe static sensitivity matrix (no hover/interaction, renders correctly in ImageRenderer)
struct PDFSensitivityMatrix: View {
    let baseGrowth: Double
    let baseDiscount: Double
    let currentPrice: Double
    let calculate: (Double, Double) -> Double

    var growthSteps: [Double] { [baseGrowth-3, baseGrowth-2, baseGrowth-1, baseGrowth, baseGrowth+1, baseGrowth+2, baseGrowth+3] }
    var discountSteps: [Double] { [baseDiscount-3, baseDiscount-2, baseDiscount-1, baseDiscount, baseDiscount+1, baseDiscount+2, baseDiscount+3] }

    func getColor(value: Double) -> Color {
        guard currentPrice > 0 else { return .gray.opacity(0.1) }
        let diff = (value - currentPrice) / currentPrice
        return diff > 0 ? Color.green.opacity(min(diff * 2.5, 0.6) + 0.05) : Color.red.opacity(min(abs(diff) * 2.5, 0.6) + 0.05)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sensitivity Matrix").font(.headline).foregroundColor(.secondary)
            // Header row
            HStack(spacing: 3) {
                Text("Disc \\ Grw").font(.system(size: 8)).foregroundColor(.secondary).frame(width: 52, alignment: .leading)
                ForEach(growthSteps, id: \.self) { g in
                    Text("\(Int(g))%").font(.system(size: 8)).bold()
                        .foregroundColor(g == baseGrowth ? .blue : .primary)
                        .frame(maxWidth: .infinity)
                }
            }
            // Data rows
            ForEach(discountSteps, id: \.self) { r in
                HStack(spacing: 3) {
                    Text("\(String(format: "%.1f", r))%").font(.system(size: 8)).bold()
                        .foregroundColor(r == baseDiscount ? .blue : .primary)
                        .frame(width: 52, alignment: .leading)
                    ForEach(growthSteps, id: \.self) { g in
                        let val = calculate(g, r)
                        Text("\(Int(val))").font(.system(size: 8, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 20)
                            .background(getColor(value: val))
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke((r == baseDiscount && g == baseGrowth) ? Color.blue : Color.clear, lineWidth: 1.5)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - NEW CHARTS

// 1. P/FCF History Chart
struct PFCFHistoryChartView: View {
    let history: [FCFHistoryPoint]
    let currentPFCF: Double?
    @State private var hoveredYear: String? = nil

    var yMin: Double { max(0, (history.map(\.value).min() ?? 0) * 0.8) }
    var yMax: Double { (history.map(\.value).max() ?? 50) * 1.2 }
    var avgPFCF: Double {
        let vals = history.map(\.value).filter { $0 > 0 }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.flattrend.xyaxis").font(.title2).foregroundColor(.purple)
                Text("Price / FCF Ratio History").font(.headline).foregroundColor(.secondary)
                Spacer()
                if avgPFCF > 0 {
                    HStack(spacing: 4) {
                        Text("5Y Avg:").font(.caption).foregroundColor(.secondary)
                        Text(String(format: "%.1fx", avgPFCF)).font(.caption).bold().foregroundColor(.purple)
                    }.padding(.horizontal, 8).padding(.vertical, 4).background(Color.purple.opacity(0.1)).cornerRadius(6)
                }
            }

            Chart {
                ForEach(history) { pt in
                    BarMark(x: .value("Year", pt.year), y: .value("P/FCF", pt.value))
                        .foregroundStyle(Color.purple.opacity(0.7).gradient)
                        .annotation(position: .top) {
                            Text(String(format: "%.1fx", pt.value)).font(.system(size: 9)).bold().foregroundColor(.purple)
                        }
                    if let hov = hoveredYear, hov == pt.year {
                        RuleMark(x: .value("Year", pt.year))
                            .foregroundStyle(Color.gray.opacity(0.3))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pt.year).font(.caption).bold()
                                    Text(String(format: "P/FCF: %.1fx", pt.value)).font(.caption2).foregroundColor(.purple)
                                    if avgPFCF > 0 {
                                        let delta = ((pt.value - avgPFCF) / avgPFCF) * 100
                                        Text(String(format: "vs avg: %@%.1f%%", delta >= 0 ? "+" : "", delta))
                                            .font(.caption2).foregroundColor(delta <= 0 ? .green : .red)
                                    }
                                    Text(pt.value < 20 ? "Historically cheap ✓" : pt.value < 35 ? "Fair range" : "Historically expensive ⚠️")
                                        .font(.caption2).foregroundColor(pt.value < 20 ? .green : pt.value < 35 ? .orange : .red)
                                }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4)
                            }.zIndex(10)
                    }
                }
                // Average line
                if avgPFCF > 0 {
                    RuleMark(y: .value("5Y Average", avgPFCF))
                        .foregroundStyle(.purple.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text(String(format: "Avg %.1fx", avgPFCF)).font(.caption2).foregroundColor(.purple)
                        }
                }
                // Current P/FCF
                if let cur = currentPFCF, cur > 0 {
                    RuleMark(y: .value("Current", cur))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .annotation(position: .bottom, alignment: .trailing) {
                            Text(String(format: "Now %.1fx", cur)).font(.caption2).foregroundColor(.orange)
                        }
                }
            }
            .chartYScale(domain: yMin...yMax)
            .frame(height: 300)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let l): if let x: String = proxy.value(atX: l.x) { hoveredYear = x }
                            case .ended: hoveredYear = nil
                            }
                        }
                }
            }
            Text("Low P/FCF historically signals better entry points. Hover bars to compare vs 5Y average.")
                .font(.caption2).foregroundColor(.secondary).italic()
        }
        .frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
}

// 4. Margin of Safety Entry Range — concrete buy targets at 10/20/30/40% MoS
struct MoSEntryRangeView: View {
    let intrinsicValue: Double
    let currentPrice: Double
    let symbol: String

    struct MoSLevel: Identifiable {
        let id = UUID()
        let label: String
        let pct: Double
        let targetPrice: Double
        let color: Color
        var isActive: Bool // current price is at or below this target
    }

    var levels: [MoSLevel] {
        [10, 20, 30, 40].map { pct in
            let tp = intrinsicValue * (1 - Double(pct) / 100)
            return MoSLevel(
                label: "\(pct)% MoS", pct: Double(pct), targetPrice: tp,
                color: pct == 10 ? .blue : pct == 20 ? .teal : pct == 30 ? .green : .mint,
                isActive: currentPrice > 0 && currentPrice <= tp
            )
        }
    }

    var currentMoS: Double {
        guard currentPrice > 0, intrinsicValue > 0 else { return 0 }
        return ((intrinsicValue - currentPrice) / intrinsicValue) * 100
    }

    @State private var hoveredLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shield.lefthalf.filled").font(.title2).foregroundColor(.green)
                Text("Margin of Safety Entry Targets").font(.headline).foregroundColor(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Current MoS").font(.caption2).foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", currentMoS))
                        .font(.title3).bold()
                        .foregroundColor(currentMoS >= 30 ? .green : currentMoS >= 15 ? .orange : .red)
                }
            }

            // Horizontal bar showing intrinsic value with MoS zones
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.12)).frame(height: 44)
                    // MoS zones as colored segments
                    ForEach(levels) { level in
                        let xPos = CGFloat(1 - level.pct / 100) * geo.size.width
                        RoundedRectangle(cornerRadius: 0)
                            .fill(level.color.opacity(0.2))
                            .frame(width: geo.size.width - xPos, height: 44)
                            .offset(x: xPos)
                    }
                    // MoS level markers
                    ForEach(levels) { level in
                        let xPos = CGFloat(1 - level.pct / 100) * geo.size.width
                        Capsule().fill(level.color).frame(width: 2, height: 44).offset(x: xPos)
                        Text(String(format: "%.0f", level.targetPrice))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(level.color)
                            .offset(x: xPos + 3, y: -14)
                    }
                    // Intrinsic value marker (right edge)
                    Capsule().fill(Color.blue).frame(width: 3, height: 52).offset(x: geo.size.width - 1.5)
                    Text(String(format: "%.0f IV", intrinsicValue)).font(.system(size: 9, weight: .bold))
                        .foregroundColor(.blue).offset(x: geo.size.width - 40, y: -14)
                    // Current price marker
                    if currentPrice > 0 && currentPrice < intrinsicValue {
                        let xPos = CGFloat(currentPrice / intrinsicValue) * geo.size.width
                        Capsule().fill(Color.orange).frame(width: 3, height: 52).offset(x: xPos - 1.5)
                        Text(String(format: "%.0f", currentPrice)).font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange).offset(x: max(4, xPos - 16), y: 14)
                    }
                }
            }
            .frame(height: 44)
            .padding(.vertical, 12)

            // Target cards
            HStack(spacing: 10) {
                ForEach(levels) { level in
                    VStack(spacing: 4) {
                        Text(level.label).font(.caption2).foregroundColor(.secondary)
                        Text(String(format: "%.2f %@", level.targetPrice, symbol))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(level.color)
                        if currentPrice > 0 {
                            let gap = currentPrice - level.targetPrice
                            if gap > 0 {
                                Text(String(format: "-%.1f%%", (gap / currentPrice) * 100))
                                    .font(.caption2).foregroundColor(.red)
                                Text("need drop").font(.system(size: 8)).foregroundColor(.secondary)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green).font(.caption)
                                Text("In zone").font(.system(size: 8)).bold().foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 8).padding(.horizontal, 6)
                    .frame(maxWidth: .infinity)
                    .background(level.isActive ? level.color.opacity(0.12) : Color.gray.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(level.isActive ? level.color : Color.clear, lineWidth: 1.5))
                }
            }

            // Gauge-style current MoS bar
            VStack(alignment: .leading, spacing: 4) {
                Text("Current position relative to intrinsic value").font(.caption2).foregroundColor(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                stops: [.init(color: .red, location: 0), .init(color: .orange, location: 0.3),
                                        .init(color: .yellow, location: 0.5), .init(color: .green, location: 1)],
                                startPoint: .leading, endPoint: .trailing
                            )).frame(height: 10)
                        let clampedMoS = min(max(currentMoS, 0), 50)
                        Capsule().fill(Color.white).frame(width: 4, height: 16)
                            .shadow(radius: 2)
                            .offset(x: CGFloat(clampedMoS / 50) * geo.size.width - 2)
                    }
                }.frame(height: 10)
                HStack { Text("0% (At price)").font(.tiny); Spacer(); Text("25%").font(.tiny); Spacer(); Text("50%+ (Deep value)").font(.tiny) }
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }
}


// 4. RSI + Bollinger Bands Chart
struct RSIBollingerView: View {
    let points: [PricePoint]
    let symbol: String
    @State private var hoveredDate: Date? = nil

    var displayPoints: [PricePoint] { Array(points.suffix(90)) }

    var hoveredPt: PricePoint? {
        guard let h = hoveredDate else { return nil }
        return displayPoints.min(by: { abs($0.date.timeIntervalSince(h)) < abs($1.date.timeIntervalSince(h)) })
    }

    var currentRSI: Double? { displayPoints.last?.rsi }
    var rsiSignal: String {
        guard let rsi = currentRSI else { return "" }
        if rsi > 70 { return "Overbought (>70)" }
        if rsi < 30 { return "Oversold (<30)" }
        return "Neutral (30–70)"
    }
    var rsiColor: Color {
        guard let rsi = currentRSI else { return .secondary }
        if rsi > 70 { return .red }
        if rsi < 30 { return .green }
        return .orange
    }

    var priceYDomain: ClosedRange<Double> {
        let prices = displayPoints.flatMap { [$0.close, $0.upperBand ?? $0.close, $0.lowerBand ?? $0.close] }
        return ((prices.min() ?? 0) * 0.97)...((prices.max() ?? 100) * 1.03)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg").font(.title2).foregroundColor(.pink)
                Text("RSI + Bollinger Bands (90D)").font(.headline).foregroundColor(.secondary)
                Spacer()
                if let rsi = currentRSI {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("RSI(14)").font(.caption2).foregroundColor(.secondary)
                        Text(String(format: "%.0f", rsi)).font(.title3).bold().foregroundColor(rsiColor)
                        Text(rsiSignal).font(.system(size: 9)).foregroundColor(rsiColor)
                    }
                }
            }

            // Price + Bollinger chart
            VStack(alignment: .leading, spacing: 4) {
                Text("Price & Bollinger Bands (SMA20 ± 2σ)").font(.caption).bold().foregroundColor(.secondary)
                Chart {
                    // Upper band area fill
                    ForEach(displayPoints.filter { $0.upperBand != nil }) { pt in
                        AreaMark(x: .value("Date", pt.date),
                                 yStart: .value("Lower", pt.lowerBand ?? pt.close),
                                 yEnd: .value("Upper", pt.upperBand ?? pt.close))
                            .foregroundStyle(Color.blue.opacity(0.06))
                    }
                    // Upper band line
                    ForEach(displayPoints.filter { $0.upperBand != nil }) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("Upper", pt.upperBand!), series: .value("S", "Upper"))
                            .foregroundStyle(Color.blue.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .interpolationMethod(.monotone)
                    }
                    // Lower band line
                    ForEach(displayPoints.filter { $0.lowerBand != nil }) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("Lower", pt.lowerBand!), series: .value("S", "Lower"))
                            .foregroundStyle(Color.blue.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .interpolationMethod(.monotone)
                    }
                    // SMA20
                    ForEach(displayPoints) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("SMA20", pt.sma20 ?? pt.close), series: .value("S", "SMA20"))
                            .foregroundStyle(Color.orange.opacity(0.8))
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.monotone)
                    }
                    // Close price
                    ForEach(displayPoints) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("Price", pt.close), series: .value("S", "Price"))
                            .foregroundStyle(Color.primary)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                    }
                    // Hover
                    if let pt = hoveredPt {
                        PointMark(x: .value("Date", pt.date), y: .value("Price", pt.close))
                            .foregroundStyle(Color.primary).symbolSize(60)
                        RuleMark(x: .value("Date", pt.date))
                            .foregroundStyle(Color.gray.opacity(0.25))
                            .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pt.date.formatted(.dateTime.month().day())).font(.caption).bold()
                                    Text(String(format: "Close: %.2f %@", pt.close, symbol)).font(.caption2)
                                    if let sma = pt.sma20 { Text(String(format: "SMA20: %.2f", sma)).font(.caption2).foregroundColor(.orange) }
                                    if let up = pt.upperBand { Text(String(format: "BB Upper: %.2f", up)).font(.caption2).foregroundColor(.blue) }
                                    if let lo = pt.lowerBand { Text(String(format: "BB Lower: %.2f", lo)).font(.caption2).foregroundColor(.blue) }
                                    if let rsi = pt.rsi { Text(String(format: "RSI: %.0f", rsi)).font(.caption2).foregroundColor(rsi > 70 ? .red : rsi < 30 ? .green : .orange) }
                                }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4)
                            }.zIndex(10)
                    }
                }
                .chartYScale(domain: priceYDomain)
                .frame(height: 200)
                .chartOverlay { proxy in
                    GeometryReader { _ in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let l): if let x: Date = proxy.value(atX: l.x) { hoveredDate = x }
                                case .ended: hoveredDate = nil
                                }
                            }
                    }
                }
            }

            // RSI sub-chart
            VStack(alignment: .leading, spacing: 4) {
                Text("RSI (14)").font(.caption).bold().foregroundColor(.secondary)
                Chart {
                    ForEach(displayPoints.filter { $0.rsi != nil }) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("RSI", pt.rsi!))
                            .foregroundStyle(Color.pink.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.monotone)
                        AreaMark(x: .value("Date", pt.date), y: .value("RSI", pt.rsi!))
                            .foregroundStyle(Color.pink.opacity(0.08).gradient)
                            .interpolationMethod(.monotone)
                    }
                    RuleMark(y: .value("OB", 70)).foregroundStyle(.red.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .trailing) { Text("70").font(.caption2).foregroundColor(.red) }
                    RuleMark(y: .value("OS", 30)).foregroundStyle(.green.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .trailing) { Text("30").font(.caption2).foregroundColor(.green) }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 100)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) { Rectangle().fill(Color.primary).frame(width: 14, height: 2); Text("Price").font(.caption2).foregroundColor(.secondary) }
                HStack(spacing: 4) { Rectangle().fill(Color.orange.opacity(0.8)).frame(width: 14, height: 1.5); Text("SMA20").font(.caption2).foregroundColor(.secondary) }
                HStack(spacing: 4) { Rectangle().fill(Color.blue.opacity(0.5)).frame(width: 14, height: 1).cornerRadius(1); Text("Bollinger Bands (2σ)").font(.caption2).foregroundColor(.secondary) }
            }
        }
        .frame(maxWidth: .infinity).padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pink.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - AI Analysis Sheet
struct AIAnalysisSheet: View {
    let analysis: String
    let ticker: String
    let stockName: String
    @Environment(\.dismiss) var dismiss

    var verdictColor: Color {
        if analysis.contains("BUY") { return .green }
        if analysis.contains("AVOID") { return .red }
        return .orange
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundColor(.purple).font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Investment Analysis").font(.headline)
                        Text("\(ticker) · \(stockName)").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.title2)
                }.buttonStyle(.plain)
            }
            .padding()
            .background(Color.purple.opacity(0.08))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Render markdown-ish sections
                    ForEach(parseAnalysisSections(analysis), id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            if !section.title.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: sectionIcon(section.title)).foregroundColor(sectionColor(section.title))
                                    Text(section.title).font(.headline).foregroundColor(sectionColor(section.title))
                                }
                                .padding(.top, 16)
                            }
                            //Text(section.content)
                            Text(try! AttributedString(markdown: section.content))
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 4)
                            if section.title.lowercased().contains("verdict") {
                                HStack {
                                    Spacer()
                                    Text(extractVerdict(section.content))
                                        .font(.system(size: 22, weight: .black))
                                        .foregroundColor(verdictColor)
                                        .padding(.horizontal, 20).padding(.vertical, 10)
                                        .background(verdictColor.opacity(0.1))
                                        .cornerRadius(10)
                                    Spacer()
                                }.padding(.top, 4)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()
            HStack {
                Text("Powered by Gemini Flash Latest · For informational purposes only")
                    .font(.caption2).foregroundColor(.secondary).italic()
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(analysis, forType: .string)
                }.buttonStyle(.bordered).controlSize(.small)
            }.padding()
        }
        .frame(width: 560, height: 620)
    }

    struct Section { let title: String; let content: String }

    func parseAnalysisSections(_ text: String) -> [Section] {
        var sections: [Section] = []
        let lines = text.components(separatedBy: "\n")
        var currentTitle = ""
        var currentContent: [String] = []
        for line in lines {
            if line.hasPrefix("## ") {
                if !currentContent.isEmpty {
                    sections.append(Section(title: currentTitle, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentTitle = String(line.dropFirst(3))
                currentContent = []
            } else {
                currentContent.append(line)
            }
        }
        if !currentContent.isEmpty {
            sections.append(Section(title: currentTitle, content: currentContent.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        return sections.filter { !$0.content.isEmpty }
    }

    func sectionIcon(_ title: String) -> String {
        switch title.lowercased() {
        case let t where t.contains("summary"): return "doc.text.fill"
        case let t where t.contains("strength"): return "arrow.up.circle.fill"
        case let t where t.contains("risk"): return "exclamationmark.triangle.fill"
        case let t where t.contains("verdict"): return "checkmark.seal.fill"
        default: return "circle.fill"
        }
    }

    func sectionColor(_ title: String) -> Color {
        switch title.lowercased() {
        case let t where t.contains("summary"): return .blue
        case let t where t.contains("strength"): return .green
        case let t where t.contains("risk"): return .orange
        case let t where t.contains("verdict"): return verdictColor
        default: return .secondary
        }
    }

    func extractVerdict(_ content: String) -> String {
        if content.uppercased().contains("BUY") { return "✅ BUY" }
        if content.uppercased().contains("AVOID") { return "🚫 AVOID" }
        return "⚖️ HOLD"
    }
}

// MARK: - STATUS BAR
struct StatusBarView: View {
    let ticker: String; let stockName: String; let lastFetchDate: Date?
    let isLoading: Bool; let hasCalculated: Bool
    let intrinsicValue: Double; let currentPrice: Double; let currencySymbol: String
    let historyCount: Int; let compareCount: Int
    let onShowCompare: () -> Void

    var mosText: String? {
        guard hasCalculated, currentPrice > 0, intrinsicValue > 0 else { return nil }
        let pct = ((intrinsicValue - currentPrice) / intrinsicValue) * 100
        return String(format: "%@%.1f%% MoS", pct >= 0 ? "▲" : "▼", abs(pct))
    }
    var mosColor: Color {
        guard hasCalculated, currentPrice > 0, intrinsicValue > 0 else { return .secondary }
        return ((intrinsicValue - currentPrice) / intrinsicValue) * 100 >= 0 ? .green : .red
    }

    var body: some View {
        HStack(spacing: 12) {
            // Ticker badge
            if !ticker.isEmpty {
                HStack(spacing: 4) {
                    Circle().fill(isLoading ? Color.orange : Color.green).frame(width: 6, height: 6)
                    Text(ticker.uppercased()).font(.caption2).bold().foregroundColor(.primary)
                    if !stockName.isEmpty { Text("· \(stockName)").font(.caption2).foregroundColor(.secondary).lineLimit(1) }
                }
            } else {
                Text("No ticker loaded").font(.caption2).foregroundColor(.secondary)
            }

            Divider().frame(height: 12)

            // MoS
            if let mos = mosText {
                Text(mos).font(.caption2).bold().foregroundColor(mosColor)
                Divider().frame(height: 12)
            }

            // Last fetch
            if let date = lastFetchDate {
                Image(systemName: "clock").font(.caption2).foregroundColor(.secondary)
                Text(date.formatted(.relative(presentation: .named))).font(.caption2).foregroundColor(.secondary)
                Divider().frame(height: 12)
            }

            Spacer()

            // History count
            if historyCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "clock.arrow.circlepath").font(.caption2).foregroundColor(.secondary)
                    Text("\(historyCount)").font(.caption2).foregroundColor(.secondary)
                }
            }

            // Compare badge
            if compareCount > 0 {
                Button(action: onShowCompare) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.left.arrow.right").font(.caption2)
                        Text("\(compareCount) in compare").font(.caption2).bold()
                    }
                    .foregroundColor(.teal)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.teal.opacity(0.1)).cornerRadius(4)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - SHARE EXPORT SHEET
struct ShareExportSheet: View {
    let ticker: String
    let onExportPDF: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "square.and.arrow.up").foregroundColor(.blue).font(.title2)
                Text("Share & Export").font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.title2)
                }.buttonStyle(.plain)
            }.padding()

            Divider()

            VStack(spacing: 12) {
                shareRow(icon: "doc.richtext.fill", color: .red, title: "Export as PDF", subtitle: "Save a full analysis report to disk") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onExportPDF() }
                }

                shareRow(icon: "doc.on.clipboard", color: .blue, title: "Copy Summary to Clipboard", subtitle: "Copy ticker, fair value and MoS as plain text") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("Intrinsic Analysis: \(ticker)", forType: .string)
                    dismiss()
                }

                shareRow(icon: "envelope.fill", color: .green, title: "Share via Mail", subtitle: "Open Mail with analysis summary") {
                    if let url = URL(string: "mailto:?subject=Intrinsic%20Analysis%20\(ticker)&body=Analysis%20for%20\(ticker)") {
                        NSWorkspace.shared.open(url)
                    }
                    dismiss()
                }
            }.padding()

            Spacer()
        }.frame(width: 380, height: 300)
    }

    func shareRow(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).bold()
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
            }
            .padding(12)
            .background(Color.gray.opacity(0.06)).cornerRadius(10)
        }.buttonStyle(.plain)
    }
}

// MARK: - HISTORY LOG SHEET
struct HistoryLogSheet: View {
    @Binding var history: [AnalysisHistoryEntry]
    let onLoad: (AnalysisHistoryEntry) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clock.arrow.circlepath").foregroundColor(.blue).font(.title2)
                Text("Analysis History").font(.headline)
                Spacer()
                if !history.isEmpty {
                    Button("Clear All") {
                        history.removeAll()
                        UserDefaults.standard.removeObject(forKey: "analysisHistory")
                    }.foregroundColor(.red).font(.caption)
                }
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.title2)
                }.buttonStyle(.plain).padding(.leading, 8)
            }.padding()

            Divider()

            if history.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock").font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                    Text("No analyses yet").foregroundColor(.secondary)
                    Text("Calculate a valuation to save it here automatically.").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Spacer()
                }
            } else {
                List {
                    ForEach(history) { entry in
                        Button(action: { onLoad(entry) }) {
                            HStack(spacing: 12) {
                                // Color badge
                                VStack {
                                    Text(entry.ticker).font(.system(size: 13, weight: .black))
                                    Text(entry.currencySymbol).font(.caption2)
                                }
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(entry.mosPercent >= 0 ? Color.green.gradient : Color.red.gradient)
                                .cornerRadius(10)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(entry.stockName.isEmpty ? entry.ticker : entry.stockName)
                                            .font(.subheadline).bold().lineLimit(1)
                                        Spacer()
                                        Text(entry.date.formatted(.dateTime.month().day().hour().minute()))
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 8) {
                                        Text(String(format: "Price: %.2f", entry.currentPrice)).font(.caption2).foregroundColor(.secondary)
                                        Text("→").font(.caption2).foregroundColor(.secondary)
                                        Text(String(format: "IV: %.2f", entry.intrinsicValue)).font(.caption2).bold()
                                            .foregroundColor(entry.mosPercent >= 0 ? .green : .red)
                                    }
                                    HStack(spacing: 6) {
                                        Text(String(format: "G: %.1f%%", entry.growthRate)).font(.caption2).foregroundColor(.secondary)
                                        Text(String(format: "R: %.1f%%", entry.discountRate)).font(.caption2).foregroundColor(.secondary)
                                        Text(String(format: "%.1fx", entry.exitMultiple)).font(.caption2).foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "%@%.1f%%", entry.mosPercent >= 0 ? "▲" : "▼", abs(entry.mosPercent)))
                                            .font(.caption2).bold()
                                            .foregroundColor(entry.mosPercent >= 0 ? .green : .red)
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background((entry.mosPercent >= 0 ? Color.green : Color.red).opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                }
                                Image(systemName: "arrow.up.left.circle").foregroundColor(.blue).font(.caption)
                            }
                            .padding(.vertical, 4)
                        }.buttonStyle(.plain)
                    }
                    .onDelete { indexSet in history.remove(atOffsets: indexSet) }
                }
            }
        }
        .frame(width: 520, height: 480)
    }
}

// MARK: - COMPARE SHEET
struct CompareSheet: View {
    let snapshots: [CompareSnapshot]
    let onRemove: (UUID) -> Void
    @Environment(\.dismiss) var dismiss

    let rows: [(label: String, value: (CompareSnapshot) -> String, highlight: Bool)] = [
        ("Current Price",    { s in String(format: "%.2f %@", s.currentPrice, s.currencySymbol) }, false),
        ("Intrinsic Value",  { s in String(format: "%.2f %@", s.intrinsicValue, s.currencySymbol) }, true),
        ("Margin of Safety", { s in String(format: "%.1f%%", s.mosPercent) }, true),
        ("Growth Rate",      { s in String(format: "%.1f%%", s.growthRate) }, false),
        ("Discount Rate",    { s in String(format: "%.1f%%", s.discountRate) }, false),
        ("Exit Multiple",    { s in String(format: "%.1fx", s.exitMultiple) }, false),
        ("FCF / Share",      { s in s.fcfInput }, false),
        ("P/E Current",      { s in s.currentPEInput }, false),
        ("Beta",             { s in s.betaInput.map { String(format: "%.2f", $0) } ?? "—" }, false),
        ("5Y FCF CAGR",      { s in s.fcfCagrDisplay ?? "—" }, false),
        ("Proj. Years",      { s in "\(s.projectionYears)Y" }, false),
    ]

    func bestIndex(for rowIdx: Int) -> Int? {
        guard rows[rowIdx].highlight else { return nil }
        let label = rows[rowIdx].label
        if label == "Margin of Safety" || label == "Intrinsic Value" {
            let vals = snapshots.map { Double($0.mosPercent) }
            return vals.firstIndex(of: vals.max() ?? -999)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.left.arrow.right").foregroundColor(.teal).font(.title2)
                Text("Compare Mode").font(.headline)
                Spacer()
                Text("\(snapshots.count) stocks").font(.caption).foregroundColor(.secondary)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary).font(.title2)
                }.buttonStyle(.plain).padding(.leading, 8)
            }.padding()

            Divider()

            if snapshots.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 40)).foregroundColor(.secondary.opacity(0.3))
                    Text("No stocks added yet").foregroundColor(.secondary)
                    Text("Press ⌘D on any calculated stock to add it here.").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Ticker header row
                        HStack(spacing: 0) {
                            Text("Metric").font(.caption2).bold().foregroundColor(.secondary)
                                .frame(width: 130, alignment: .leading).padding(.leading, 12)
                            ForEach(snapshots) { snap in
                                VStack(spacing: 3) {
                                    Text(snap.ticker).font(.system(size: 13, weight: .black))
                                    Text(snap.stockName).font(.system(size: 8)).foregroundColor(.secondary).lineLimit(1)
                                    Button(action: { onRemove(snap.id) }) {
                                        Image(systemName: "xmark.circle.fill").font(.caption2).foregroundColor(.red.opacity(0.7))
                                    }.buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                                .background(snap.mosPercent >= 0 ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                            }
                        }
                        .background(Color.gray.opacity(0.08))

                        Divider()

                        ForEach(rows.indices, id: \.self) { rowIdx in
                            let row = rows[rowIdx]
                            let best = bestIndex(for: rowIdx)
                            HStack(spacing: 0) {
                                Text(row.label).font(.caption2).foregroundColor(.secondary)
                                    .frame(width: 130, alignment: .leading).padding(.leading, 12)
                                ForEach(snapshots.indices, id: \.self) { si in
                                    let val = row.value(snapshots[si])
                                    let isBest = best == si
                                    Text(val)
                                        .font(.system(size: 12, weight: isBest ? .bold : .regular))
                                        .foregroundColor(isBest ? .green : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(isBest ? Color.green.opacity(0.08) : Color.clear)
                                }
                            }
                            .background(rowIdx % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Text("⌘D to add current stock · Click ✕ to remove").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(.bordered)
            }.padding(10)
        }
        .frame(width: min(CGFloat(160 + snapshots.count * 160), 900), height: 560)
    }
}

// MARK: - UTILS
extension Font { static let tiny = Font.system(size: 10) }
extension Text { func secondaryStr() -> Text { self.foregroundColor(.secondary) } }
