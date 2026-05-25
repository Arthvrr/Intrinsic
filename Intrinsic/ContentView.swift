import SwiftUI
import Charts
internal import UniformTypeIdentifiers

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

    private enum CodingKeys: String, CodingKey {
        case cashAndEquivalentsAnnual
        case totalDebtAnnual
        case freeCashFlowTTM
        case peTTM
        case yearHigh = "52WeekHigh"
        case beta
        case pfcfShareTTM
        case cashPerSharePerShareAnnual
        case bookValuePerShareAnnual
        case totalDebtToEquityAnnual = "totalDebt/totalEquityAnnual"
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

struct FCFHistoryPoint: Identifiable, Sendable {
    let id = UUID()
    let year: String
    let value: Double
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

struct PeerData: Identifiable, Sendable {
    let id = UUID()
    let ticker: String
    let pe: Double
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

// NOUVEAU : Modèle pour Monte Carlo
struct MonteCarloResult: Identifiable {
    let id = UUID()
    let bucketMin: Double
    let bucketMax: Double
    let frequency: Int
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

    struct StockData: Sendable {
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
    }

    private func fetchAndDecode<T: Codable>(url: URL, type: T.Type, label: String) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(T.self, from: data)
    }

    private func fetchConversionRateToUSD(from sourceCurrency: String) async -> Double {
        if sourceCurrency == "USD" { return 1.0 }
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/\(exchangeRateApiKey)/latest/\(sourceCurrency)") else { return 1.0 }
        do {
            let response = try await fetchAndDecode(url: url, type: ExchangeRateResponse.self, label: "FOREX")
            if response.result == "success", let rate = response.conversion_rates["USD"] {
                return rate
            }
        } catch { print("❌ Erreur Forex: \(error)") }
        return 1.0
    }

    func fetchRecommendations(symbol: String) async -> [FinnhubRecommendation] {
        let urlString = "https://finnhub.io/api/v1/stock/recommendation?symbol=\(symbol)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let recs = try await fetchAndDecode(url: url, type: [FinnhubRecommendation].self, label: "RECS")
            return Array(recs.prefix(4))
        } catch { return [] }
    }
    
    func fetchInsiderTransactions(symbol: String) async -> [FinnhubInsiderTransaction] {
        let urlString = "https://finnhub.io/api/v1/stock/insider-transactions?symbol=\(symbol)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let response = try await fetchAndDecode(url: url, type: FinnhubInsiderResponse.self, label: "INSIDERS")
            return Array(response.data?.prefix(20) ?? [])
        } catch { return [] }
    }

    func fetchPeersComparison(symbol: String) async -> [PeerData] {
        let peersURL = URL(string: "https://finnhub.io/api/v1/stock/peers?symbol=\(symbol)&token=\(finnhubApiKey)")!
        guard let peersList = try? await fetchAndDecode(url: peersURL, type: [String].self, label: "PEERS") else { return [] }
        let cleanSymbol = symbol.uppercased()
        let topPeers = peersList.filter { $0 != cleanSymbol && !$0.contains(".") }.prefix(3)
        var results: [PeerData] = []
        await withTaskGroup(of: PeerData?.self) { group in
            for peer in topPeers {
                group.addTask {
                    let metricURL = URL(string: "https://finnhub.io/api/v1/stock/metric?symbol=\(peer)&metric=all&token=\(await self.finnhubApiKey)")!
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
        return results.sorted { $0.ticker < $1.ticker }
    }

    func fetchPriceTarget(symbol: String) async -> FinnhubPriceTarget? {
        let urlString = "https://finnhub.io/api/v1/stock/price-target?symbol=\(symbol)&token=\(finnhubApiKey)"
        guard let url = URL(string: urlString) else { return nil }
        return try? await fetchAndDecode(url: url, type: FinnhubPriceTarget.self, label: "PRICE_TARGET")
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

        var conversionRate = 1.0
        if profileCurrency != "USD" {
            conversionRate = await fetchConversionRateToUSD(from: profileCurrency)
        }

        var finalFCFPerShare = 0.0
        if let fcfTotal = m.freeCashFlowTTM {
            finalFCFPerShare = sharesM > 0 ? (fcfTotal / sharesM) : 0.0
        } else if let priceToFcf = m.pfcfShareTTM, priceToFcf > 0 {
            if let rawFCF = m.freeCashFlowTTM {
                finalFCFPerShare = (rawFCF / sharesM) * conversionRate
            } else {
                finalFCFPerShare = priceUSD / priceToFcf
            }
        }
        if let fcfTotal = m.freeCashFlowTTM {
            let fcfPerShareNative = sharesM > 0 ? (fcfTotal / sharesM) : 0.0
            finalFCFPerShare = fcfPerShareNative * conversionRate
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

        let rawHigh = m.yearHigh ?? 0.0
        let convertedHigh = (rawHigh > 0 ? rawHigh : priceUSD) * conversionRate
        let adjustedHigh = max(convertedHigh, priceUSD)

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

        return StockData(
            price: priceUSD,
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
            fcfHistory: fcfHistoryPoints
        )
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

    @State private var showHelp: Bool = false

    private let finnhubService = FinnhubService()

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                VStack(spacing: 0) {
                    HStack {
                        Text("DCF Parameters").font(.headline)
                        Spacer()

                        Button(action: { showHelp.toggle() }) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Explain DCF Method")
                        .padding(.trailing, 8)
                        .popover(isPresented: $showHelp) {
                            DCFHelpView()
                        }

                        if hasCalculated {
                            Button(action: exportToPDF) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Export analysis as PDF")
                            .padding(.trailing, 8)
                        }

                        Button(action: clearAllData) {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Clear all inputs")
                        .padding(.trailing, 10)

                        Divider().frame(height: 15).padding(.horizontal, 5)

                        Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isSidebarVisible = false } }) {
                            Image(systemName: "sidebar.left").foregroundColor(.primary)
                        }
                        .buttonStyle(.plain).help("Hide sidebar")
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
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fit)
                                            } else {
                                                Rectangle().fill(Color.gray.opacity(0.2))
                                            }
                                        }
                                        .frame(width: 24, height: 24)
                                        .cornerRadius(4)
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
                            inputRowString(label: "FCF / Share", value: $fcfInput, helpText: "Free Cash Flow per share (Converted)")
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
                                    Text("Hist. 5Y FCF CAGR:")
                                        .font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(cagr).font(.caption).bold().foregroundColor(.blue)
                                }.padding(.bottom, 2)
                            }

                            inputRowDouble(label: "FCF Growth Rate", value: $growthRate, suffix: "%", helpText: "Expected annual FCF growth for 5 years in %")
                            inputRowDouble(label: "Discount Rate", value: $discountRate, suffix: "%", helpText: "Your desired annual return in %")

                            if let beta = betaInput {
                                let riskFree = 4.2
                                let riskPremium = 5.0
                                let wacc = riskFree + (beta * riskPremium)
                                Button(action: { self.discountRate = Double(String(format: "%.1f", wacc)) ?? 10.0 }) {
                                    HStack {
                                        Image(systemName: "wand.and.stars")
                                        Text("Apply WACC: \(String(format: "%.1f", wacc))% (Beta \(String(format: "%.2f", beta)))")
                                    }
                                    .font(.caption)
                                }.buttonStyle(.plain).foregroundColor(.blue).padding(.bottom, 5)
                            }

                            inputRowDouble(label: "Exit Multiple", value: $exitMultiple, suffix: "x", helpText: "Expected P/E ratio in 5 years")
                        }
                    }
                    .formStyle(.grouped)

                    Divider()
                    Button(action: { calculateIntrinsicValue() }) {
                        Text("CALCULATE").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 5)
                    }.buttonStyle(.borderedProminent).controlSize(.large).padding().background(Color(nsColor: .windowBackgroundColor)).keyboardShortcut(.return, modifiers: .command)
                }
                .frame(width: sidebarWidth)
                .transition(.move(edge: .leading))
            }

            if isSidebarVisible {
                Divider().overlay(Color.gray.opacity(0.1)).frame(width: 5).contentShape(Rectangle())
                    .onHover { inside in if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
                    .gesture(DragGesture().onChanged { value in
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            let n = lastSidebarWidth + value.translation.width
                            if n > 250 && n < 600 { sidebarWidth = n }
                        }
                    }.onEnded { _ in lastSidebarWidth = sidebarWidth })
            }

            // --- MAIN CONTENT ---
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

                ScrollView {
                    if hasCalculated {
                        VStack(spacing: 30) {
                            ResultHeaderView(priceDisplay: priceDisplay, intrinsicValue: intrinsicValue, currentPrice: currentPrice, symbol: currencySymbol)
                                .padding(.top, 40)
                            
                            if !scenarioResults.isEmpty {
                                ScenarioComparisonChart(data: scenarioResults, currentPrice: currentPrice, symbol: currencySymbol)
                                    .padding(.horizontal)
                            }

                            if currentPrice > 0 {
                                InteractiveReverseDCFView(impliedGrowth: marketImpliedGrowth, userGrowth: growthRate, currentPrice: currentPrice, symbol: currencySymbol, calculateValuation: runSimulationWithGrowth)
                                    .padding(.horizontal)
                            }
                            
                            if currentPrice > 0 {
                                ValuationBarChart(marketPrice: currentPrice, intrinsicValue: intrinsicValue, symbol: currencySymbol)
                                    .frame(height: 300).padding(.horizontal)
                            }

                            if !projectionData.isEmpty {
                                ProjectedGrowthChart(data: projectionData, currentPrice: currentPrice, symbol: currencySymbol)
                                    .padding(.horizontal)
                            }
                            
                            if !monteCarloResults.isEmpty {
                                MonteCarloChart(results: monteCarloResults, symbol: currencySymbol, currentPrice: currentPrice)
                                    .padding(.horizontal)
                            }

                            SensitivityMatrixView(baseGrowth: growthRate, baseDiscount: discountRate, currentPrice: currentPrice, calculate: runSimulation)
                                .padding(.horizontal)
                                
                            if parseDouble(fcfInput) > 0 && currentPrice > 0 {
                                PaybackTimeView(fcfPerShare: parseDouble(fcfInput), currentPrice: currentPrice, growthRate: growthRate)
                                    .padding(.horizontal)
                            }

                            FinancialHealthView(cash: parseDouble(cashInput), debt: parseDouble(debtInput), fcfPerShare: parseDouble(fcfInput), growthRate: growthRate, symbol: currencySymbol)
                                .padding(.horizontal)

                            if !fcfHistory.isEmpty {
                                FCFHistoryChartView(history: fcfHistory, cagrDisplay: fcfCagrDisplay)
                                    .padding(.horizontal)
                            }
                            
                            if !insiderTransactions.isEmpty {
                                InsiderTradesChart(transactions: insiderTransactions)
                                    .padding(.horizontal)
                            }

                            if !recommendationData.isEmpty {
                                AnalystConsensusChart(data: recommendationData)
                                    .padding(.horizontal)
                            }

                            if let pt = priceTarget, pt.targetMean != nil {
                                PriceTargetView(priceTarget: pt, currentPrice: currentPrice, intrinsicValue: intrinsicValue, symbol: currencySymbol)
                                    .padding(.horizontal)
                            }

                            if !earningsData.isEmpty {
                                EarningsSurprisesView(earnings: earningsData)
                                    .padding(.horizontal)
                            }

                            if !peersData.isEmpty {
                                PeersComparisonView(mainTicker: ticker, mainPE: parseDouble(currentPEInput), peers: peersData)
                                    .padding(.horizontal)
                            }

                            PEComparisonChart(currentPE: parseDouble(currentPEInput), historicalPE: parseDouble(historicalPEInput), exitMultiple: exitMultiple)
                                .padding(.horizontal)

                            if parseDouble(currentPEInput) > 0 && growthRate > 0 {
                                PEGRatioGauge(currentPE: parseDouble(currentPEInput), growthRate: growthRate)
                                    .padding(.horizontal)
                            }

                            if parseDouble(fcfInput) > 0 && currentPrice > 0 {
                                FCFYieldGauge(fcfPerShare: parseDouble(fcfInput), currentPrice: currentPrice)
                                    .padding(.horizontal)
                            }

                            if intrinsicValue > 0 {
                                BuyBoxView(intrinsicValue: intrinsicValue, currentPrice: currentPrice, marginOfSafety: $marginOfSafety, symbol: currencySymbol)
                                    .padding(.horizontal)

                                if yearHigh > 0 {
                                    PriceRangeChart(currentPrice: currentPrice, yearHigh: yearHigh, symbol: currencySymbol)
                                        .padding(.horizontal)
                                }
                            }

                            if let beta = betaInput {
                                ExoticBetaGauge(beta: beta).padding(.horizontal).padding(.bottom, 50)
                            } else {
                                Color.clear.frame(height: 50)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.horizontal, 20)
                    } else {
                        VStack {
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 60)).foregroundColor(.secondary.opacity(0.3))
                            Text("Load a ticker and press Calculate").font(.title2).foregroundColor(.secondary.opacity(0.5)).padding(.top)
                            Spacer()
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                if !isSidebarVisible {
                    Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isSidebarVisible = true } }) {
                        Image(systemName: "sidebar.right").font(.title2).foregroundColor(.primary).padding(10).background(.regularMaterial).cornerRadius(8)
                    }.padding().buttonStyle(.plain)
                }
            }
        }
    }

    // --- LOGIC ---
    func clearAllData() {
        withAnimation {
            ticker = ""; stockName = ""; priceDisplay = "---"; currentPrice = 0.0; yearHigh = 0.0; currencySymbol = "$"
            fcfInput = "0.00"; sharesInput = "0.00"; cashInput = "0.00"; debtInput = "0.00"
            currentPEInput = "0.00"; historicalPEInput = "0.00"; fcfCagrDisplay = nil; betaInput = nil; logoUrl = nil
            growthRate = 0.0; discountRate = 0.0; exitMultiple = 0.0; intrinsicValue = 0.0; marketImpliedGrowth = 0.0
            projectionData = []; peersData = []; recommendationData = []; hasCalculated = false
            priceTarget = nil; earningsData = []; fcfHistory = []; insiderTransactions = []; scenarioResults = []
            monteCarloResults = []
        }
    }

    func fetchFinnhubData() {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanTicker.isEmpty else { return }
        isLoading = true; priceDisplay = "Loading..."
        peersData = []; recommendationData = []; priceTarget = nil; earningsData = []; fcfHistory = []; insiderTransactions = []
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
                    
                    self.growthRate = data.fcfCagr ?? 10.0
                    self.exitMultiple = data.peHistoricalAvg > 0 ? data.peHistoricalAvg : 15.0
                    if let b = data.beta { self.discountRate = 4.2 + (b * 5.0) } else { self.discountRate = 10.0 }
                    
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false; self.priceDisplay = "Error" }
            }

            async let peersFetch = finnhubService.fetchPeersComparison(symbol: cleanTicker)
            async let recsFetch = finnhubService.fetchRecommendations(symbol: cleanTicker)
            async let targetFetch = finnhubService.fetchPriceTarget(symbol: cleanTicker)
            async let earningsFetch = finnhubService.fetchEarningsSurprises(symbol: cleanTicker)
            async let insidersFetch = finnhubService.fetchInsiderTransactions(symbol: cleanTicker)

            let (peers, recs, target, earnings, insiders) = await (peersFetch, recsFetch, targetFetch, earningsFetch, insidersFetch)
            await MainActor.run {
                self.peersData = peers
                self.recommendationData = recs
                self.priceTarget = target
                self.earningsData = earnings
                self.insiderTransactions = insiders
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
        let baseVal = computeDCF(
            fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput),
            cash: parseDouble(cashInput), debt: parseDouble(debtInput),
            g: growthRate, r: discountRate, exitMult: exitMultiple
        )
        let bearVal = computeDCF(
            fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput),
            cash: parseDouble(cashInput), debt: parseDouble(debtInput),
            g: growthRate * 0.7, r: discountRate, exitMult: exitMultiple * 0.7
        )
        let bullVal = computeDCF(
            fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput),
            cash: parseDouble(cashInput), debt: parseDouble(debtInput),
            g: growthRate * 1.3, r: discountRate, exitMult: exitMultiple * 1.3
        )
        
        let newScenarios = [
            ScenarioResult(name: "Bear (-30%)", value: bearVal, color: .red),
            ScenarioResult(name: "Base", value: baseVal, color: .blue),
            ScenarioResult(name: "Bull (+30%)", value: bullVal, color: .green)
        ]
        
        if currentPrice > 0 { self.marketImpliedGrowth = solveReverseDCF(targetPrice: currentPrice) }
        var newProjections: [ProjectionPoint] = []
        var projectedValue = baseVal
        newProjections.append(ProjectionPoint(year: 0, value: baseVal))
        for i in 1...5 {
            projectedValue = projectedValue * (1 + (growthRate / 100.0))
            newProjections.append(ProjectionPoint(year: i, value: projectedValue))
        }
        
        runMonteCarlo()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            self.intrinsicValue = baseVal
            self.scenarioResults = newScenarios
            self.projectionData = newProjections
            self.hasCalculated = true
        }
    }
    
    // NOUVEAU : Simulation Monte Carlo
    func runMonteCarlo() {
        let iterations = 1000
        var results: [Double] = []
        
        // Distribution normale simple (Box-Muller)
        func randomNormal() -> Double {
            let u1 = Double.random(in: 0...1)
            let u2 = Double.random(in: 0...1)
            return sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
        }
        
        let baseG = growthRate
        let baseMult = exitMultiple
        let r = discountRate
        
        for _ in 0..<iterations {
            let simG = baseG + randomNormal() * 3.0 // +/- 3% de variance sur la croissance
            let simMult = baseMult + randomNormal() * 2.0 // +/- 2x de variance sur le multiple
            let val = computeDCF(
                fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput),
                cash: parseDouble(cashInput), debt: parseDouble(debtInput),
                g: simG, r: r, exitMult: simMult
            )
            results.append(val)
        }
        
        let minVal = results.min() ?? 0
        let maxVal = results.max() ?? 0
        let bucketSize = (maxVal - minVal) / 20.0
        
        var bins: [Int] = Array(repeating: 0, count: 20)
        for val in results {
            var index = Int((val - minVal) / bucketSize)
            if index >= 20 { index = 19 }
            if index < 0 { index = 0 }
            bins[index] += 1
        }
        
        var mcData: [MonteCarloResult] = []
        for i in 0..<20 {
            mcData.append(MonteCarloResult(bucketMin: minVal + Double(i)*bucketSize, bucketMax: minVal + Double(i+1)*bucketSize, frequency: bins[i]))
        }
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

    func runSimulationWithGrowth(_ g: Double) -> Double {
        return computeDCF(
            fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput),
            cash: parseDouble(cashInput), debt: parseDouble(debtInput),
            g: g, r: discountRate, exitMult: exitMultiple
        )
    }

    func runSimulation(g: Double, r: Double) -> Double {
        return computeDCF(
            fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput),
            cash: parseDouble(cashInput), debt: parseDouble(debtInput),
            g: g, r: r, exitMult: exitMultiple
        )
    }

    // MODIFIÉ : Retrait de ValuationMethod
    func computeDCF(fcfPerShare: Double, shares: Double, cash: Double, debt: Double,
                    g: Double, r: Double, exitMult: Double) -> Double {
        let gDec = g / 100.0; let rDec = r / 100.0
        var currentFCF = fcfPerShare; var sumPV = 0.0
        for i in 1...5 {
            currentFCF = currentFCF * (1 + gDec)
            sumPV += (currentFCF / pow(1 + rDec, Double(i)))
        }
        let terminalValue = currentFCF * exitMult
        let netCashPerShare = shares > 0 ? (cash - debt) / shares : 0.0
        return sumPV + (terminalValue / pow(1 + rDec, 5.0)) + netCashPerShare
    }

    func getCurrencySymbol(code: String) -> String {
        switch code {
        case "EUR": return "€"; case "GBP": return "£"; case "JPY": return "¥"
        case "CNY": return "¥"; case "INR": return "₹"; case "CAD": return "C$"
        case "AUD": return "A$"; default: return "$"
        }
    }

    func inputRowString(label: String, value: Binding<String>, helpText: String) -> some View {
        HStack {
            Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8)
            InfoButton(helpText: helpText)
            Spacer()
            TextField("0", text: value).textFieldStyle(.roundedBorder).frame(width: 100).multilineTextAlignment(.trailing)
        }
    }

    func inputRowDouble(label: String, value: Binding<Double>, suffix: String, helpText: String) -> some View {
        HStack {
            Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8)
            InfoButton(helpText: helpText)
            Spacer()
            HStack(spacing: 2) {
                TextField("", value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 80).multilineTextAlignment(.trailing)
                Text(suffix).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    @MainActor
    func exportToPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(ticker.isEmpty ? "Analysis" : ticker.uppercased())_DCF_Analysis.pdf"
        panel.title = "Export DCF Analysis"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let pdfView = PDFExportView(
                ticker: self.ticker.uppercased(), stockName: self.stockName, currentPrice: self.currentPrice,
                intrinsicValue: self.intrinsicValue, currencySymbol: self.currencySymbol, growthRate: self.growthRate,
                discountRate: self.discountRate, exitMultiple: self.exitMultiple, marginOfSafety: self.marginOfSafety,
                fcfInput: self.fcfInput, cashInput: self.cashInput, debtInput: self.debtInput, sharesInput: self.sharesInput,
                currentPEInput: self.currentPEInput, fcfCagrDisplay: self.fcfCagrDisplay, betaInput: self.betaInput,
                fcfHistory: self.fcfHistory, projectionData: self.projectionData, priceTarget: self.priceTarget,
                earningsData: self.earningsData, parseDouble: self.parseDouble
            )

            let renderer = ImageRenderer(content: pdfView)
            renderer.scale = 2.0
            
            // Correction sûre pour le PDF
            DispatchQueue.main.async {
                if let cgImage = renderer.cgImage {
                    let pdfData = NSMutableData()
                    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return }
                    var mediaBox = CGRect(x: 0, y: 0, width: 794, height: 1123)
                    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
                    context.beginPDFPage(nil)
                    let scaleX = mediaBox.width / CGFloat(cgImage.width)
                    let scaleY = mediaBox.height / CGFloat(cgImage.height)
                    let scale = min(scaleX, scaleY)
                    let drawWidth = CGFloat(cgImage.width) * scale
                    let drawHeight = CGFloat(cgImage.height) * scale
                    let originX = (mediaBox.width - drawWidth) / 2
                    let originY = (mediaBox.height - drawHeight) / 2
                    context.draw(cgImage, in: CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight))
                    context.endPDFPage()
                    context.closePDF()
                    pdfData.write(to: url, atomically: true)
                }
            }
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
                }.font(.callout).padding(.horizontal, 16).padding(.vertical, 8)
                    .background(margin > 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .foregroundColor(margin > 0 ? .green : .red)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(margin > 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1))
            }
        }
    }
}

struct ScenarioComparisonChart: View {
    let data: [ScenarioResult]
    let currentPrice: Double
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.xaxis.ascending").font(.title2).foregroundColor(.blue)
                Text("Scenario Analysis (-30% / +30%)").font(.headline).foregroundColor(.secondary)
            }
            Chart {
                RuleMark(y: .value("Price", currentPrice))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .leading) { Text("Price").font(.caption).foregroundColor(.red) }
                
                ForEach(data) { item in
                    BarMark(x: .value("Scenario", item.name), y: .value("Value", item.value))
                    .foregroundStyle(item.color.gradient)
                    .annotation(position: .top) { Text(String(format: "%.0f %@", item.value, symbol)).font(.caption).bold() }
                }
            }
            .frame(height: 200)
            .chartYAxis { AxisMarks(position: .leading) }
        }
        .padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct InteractiveReverseDCFView: View {
    var impliedGrowth: Double
    var userGrowth: Double
    var currentPrice: Double
    var symbol: String
    let calculateValuation: (Double) -> Double
    
    @State private var sliderGrowth: Double
    
    init(impliedGrowth: Double, userGrowth: Double, currentPrice: Double, symbol: String, calculateValuation: @escaping (Double) -> Double) {
        self.impliedGrowth = impliedGrowth
        self.userGrowth = userGrowth
        self.currentPrice = currentPrice
        self.symbol = symbol
        self.calculateValuation = calculateValuation
        _sliderGrowth = State(initialValue: impliedGrowth)
    }
    
    var dynamicValue: Double {
        calculateValuation(sliderGrowth)
    }
    
    var isRisky: Bool { impliedGrowth > userGrowth }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 20) {
                Image(systemName: isRisky ? "exclamationmark.triangle.fill" : "hand.thumbsup.fill").font(.largeTitle).foregroundColor(isRisky ? .orange : .green).frame(width: 50)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Reverse DCF (Market Expectations)").font(.headline).foregroundColor(.secondary)
                    Text("To justify the price of \(String(format: "%.2f %@", currentPrice, symbol)), the market expects a growth of:").font(.caption).foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(format: "%.1f%%", impliedGrowth)).font(.title2).bold().foregroundColor(isRisky ? .orange : .primary)
                        Text("per year").font(.caption).bold().foregroundColor(.secondary)
                        Text(isRisky ? "(Lower than your \(String(format: "%.1f", userGrowth))%)" : "(Higher than your \(String(format: "%.1f", userGrowth))%)").font(.caption).foregroundColor(isRisky ? .red : .green).padding(.leading, 5)
                    }
                }
                Spacer()
            }
            Divider()
            VStack(spacing: 5) {
                HStack {
                    Text("Test Market Growth: \(String(format: "%.1f%%", sliderGrowth))").font(.caption).bold()
                    Spacer()
                    Text("Simulated Value: \(String(format: "%.2f", dynamicValue)) \(symbol)").font(.headline).foregroundColor(dynamicValue > currentPrice ? .green : .red)
                }
                Slider(value: $sliderGrowth, in: -5...35, step: 0.5)
            }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isRisky ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1))
    }
}

// NOUVEAU : MONTE CARLO CHART
struct MonteCarloChart: View {
    let results: [MonteCarloResult]
    let symbol: String
    let currentPrice: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "dice.fill").font(.title2).foregroundColor(.purple)
                Text("Monte Carlo Simulation (1,000 runs)").font(.headline).foregroundColor(.secondary)
            }
            Text("Probability distribution based on randomized growth and exit multiples.").font(.caption).foregroundColor(.secondary)
            
            Chart(results) { item in
                BarMark(
                    x: .value("Value", (item.bucketMin + item.bucketMax) / 2),
                    y: .value("Frequency", item.frequency)
                )
                .foregroundStyle(Color.purple.gradient)
            }
            .chartXAxisLabel("Intrinsic Value (\(symbol))")
            .chartYAxisLabel("Frequency")
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    if currentPrice > 0 {
                        Path { path in
                            let xPos = proxy.position(forX: currentPrice) ?? 0
                            path.move(to: CGPoint(x: xPos, y: 0))
                            path.addLine(to: CGPoint(x: xPos, y: 200))
                        }
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [5]))
                        Text("Current Price")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .position(x: (proxy.position(forX: currentPrice) ?? 0) + 30, y: 10)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
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

struct ProjectedGrowthChart: View {
    var data: [ProjectionPoint]; var currentPrice: Double; var symbol: String; @State private var selectedYear: Int?
    var yDomain: ClosedRange<Double> { let all = data.map { $0.value } + [currentPrice]; return ((all.min() ?? 0) * 0.9)...((all.max() ?? 100) * 1.1) }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                HStack { Image(systemName: "chart.line.uptrend.xyaxis").font(.title2).foregroundColor(.blue); Text("Value Projection vs Price").font(.headline).foregroundColor(.secondary) }
                HStack(spacing: 15) { HStack(spacing: 5) { Image(systemName: "circle.fill").foregroundColor(.blue).font(.caption); Text("Intrinsic Value").font(.caption).bold() }; HStack(spacing: 5) { Image(systemName: "line.horizontal.3").foregroundColor(.red).font(.caption); Text("Current Price").font(.caption).bold() } }
            }
            Chart {
                RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5])).annotation(position: .top, alignment: .leading) { Text("Price: \(Int(currentPrice))\(symbol)").font(.caption2).foregroundColor(.red) }
                ForEach(data) { point in LineMark(x: .value("Year", point.year), y: .value("Value", point.value)).foregroundStyle(.blue).interpolationMethod(.monotone); PointMark(x: .value("Year", point.year), y: .value("Value", point.value)).foregroundStyle(.blue).symbolSize(60) }
                if let selectedYear, let point = data.first(where: { $0.year == selectedYear }) {
                    RuleMark(x: .value("Year", selectedYear)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                        VStack(alignment: .leading, spacing: 4) { Text("Year \(point.year)").font(.caption).bold().foregroundColor(.primary); Text("Value: \(Int(point.value)) \(symbol)").font(.caption).bold().foregroundColor(.blue) }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4)
                    }.zIndex(10)
                }
            }.chartYScale(domain: yDomain).chartXScale(domain: 0...5).frame(height: 250).chartOverlay { proxy in GeometryReader { geo in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: Int = proxy.value(atX: l.x) { selectedYear = x } case .ended: selectedYear = nil } } } }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct PaybackTimeView: View {
    let fcfPerShare: Double
    let currentPrice: Double
    let growthRate: Double
    
    var paybackYears: Double? {
        guard currentPrice > 0, fcfPerShare > 0 else { return nil }
        var currentFCF = fcfPerShare
        var sum = 0.0
        var years = 0
        while sum < currentPrice && years < 50 {
            years += 1
            sum += currentFCF
            currentFCF *= (1 + growthRate / 100.0)
        }
        return Double(years)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "timer").font(.title2).foregroundColor(.blue)
                    Text("Payback Time").font(.headline).foregroundColor(.secondary)
                }
                Text("Years to get your money back through projected FCF.").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if let years = paybackYears {
                Text("\(Int(years)) Years")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(years < 10 ? .green : years < 15 ? .orange : .red)
            } else {
                Text("N/A").foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct SensitivityMatrixView: View {
    let baseGrowth: Double; let baseDiscount: Double; let currentPrice: Double; let calculate: (Double, Double) -> Double
    var growthSteps: [Double] { [baseGrowth-3, baseGrowth-2, baseGrowth-1, baseGrowth, baseGrowth+1, baseGrowth+2, baseGrowth+3] }
    var discountSteps: [Double] { [baseDiscount-3, baseDiscount-2, baseDiscount-1, baseDiscount, baseDiscount+1, baseDiscount+2, baseDiscount+3] }
    func getColor(value: Double) -> Color { guard currentPrice > 0 else { return .gray.opacity(0.1) }; let diff = (value - currentPrice) / currentPrice; if diff > 0 { return Color.green.opacity(min(diff * 2.5, 0.6) + 0.05) } else { return Color.red.opacity(min(abs(diff) * 2.5, 0.6) + 0.05) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Image(systemName: "tablecells").font(.title2).foregroundColor(.blue); Text("Sensitivity Matrix (7x7 Heatmap)").font(.headline).foregroundColor(.secondary) }
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow { Text("Disc. \\ Grwth").font(.caption2).foregroundColor(.secondary).frame(width: 70, alignment: .leading); ForEach(growthSteps, id: \.self) { g in Text("\(String(format: "%.0f", g))%").font(.caption2).bold().foregroundColor(g == baseGrowth ? .blue : .primary) } }
                ForEach(discountSteps, id: \.self) { r in GridRow { Text("\(String(format: "%.1f", r))%").font(.caption2).bold().foregroundColor(r == baseDiscount ? .blue : .primary).frame(width: 70, alignment: .leading); ForEach(growthSteps, id: \.self) { g in let val = calculate(g, r); Text(String(format: "%.0f", val)).font(.system(size: 11, weight: .medium)).foregroundColor(.primary).frame(maxWidth: .infinity, minHeight: 30).background(getColor(value: val)).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke((r == baseDiscount && g == baseGrowth) ? Color.blue : Color.clear, lineWidth: 2)) } } }
            }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12)
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Balance Sheet").font(.caption).bold().foregroundColor(.secondary)
                    if cash == 0 && debt == 0 { Text("Enter Cash & Debt").font(.caption).italic().foregroundColor(.secondary) } else {
                        HStack(alignment: .bottom, spacing: 15) { VStack { Text(String(format: "%.1fB", cash)).font(.caption2); RoundedRectangle(cornerRadius: 6).fill(Color.green.gradient).frame(width: 30, height: 60 * (cash / max(cash, debt, 1.0))); Text("Cash").font(.tiny).bold() }; VStack { Text(String(format: "%.1fB", debt)).font(.caption2); RoundedRectangle(cornerRadius: 6).fill(Color.red.gradient).frame(width: 30, height: 60 * (debt / max(cash, debt, 1.0))); Text("Debt").font(.tiny).bold() } }.frame(height: 80)
                        Text(netCash >= 0 ? "Net Cash (Safe)" : "Net Debt (Leveraged)").font(.tiny).bold().foregroundColor(netCash >= 0 ? .green : .red).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4)
                    }
                }.padding().frame(maxWidth: .infinity).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Proj. FCF Growth (5Y)").font(.caption).bold().foregroundColor(.secondary)
                    if fcfPerShare > 0 {
                        HStack(alignment: .bottom, spacing: 8) { let d = fcfProjections; let m = (d.max() ?? 1.0) * 1.1; ForEach(0..<5) { i in VStack(spacing: 2) { Spacer(); RoundedRectangle(cornerRadius: 4).fill(Color.blue.gradient).frame(height: 60 * (d[i] / m)); Text("\(Int(d[i]))").font(.system(size: 9)); Text("Y\(i+1)").font(.tiny).foregroundColor(.secondary) } } }.frame(height: 80)
                        Text("CAGR: \(String(format: "%.1f", growthRate))%").font(.tiny).bold().foregroundColor(growthRate > 0 ? .green : .red).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4)
                    } else { Text("Enter Positive FCF").font(.caption).italic().foregroundColor(.secondary) }
                }.padding().frame(maxWidth: .infinity).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            }
        }
    }
}

struct FCFHistoryChartView: View {
    let history: [FCFHistoryPoint]
    let cagrDisplay: String?
    @State private var selectedYear: String? = nil
    var minVal: Double { history.map { $0.value }.min() ?? 0 }
    var maxVal: Double { history.map { $0.value }.max() ?? 1 }
    var yMin: Double { min(0, minVal * 1.15) }
    var yMax: Double { maxVal * 1.2 }
    func barColor(_ value: Double) -> Color { if value < 0 { return .red }; return .teal }
    func formatFCF(_ val: Double) -> String {
        let billions = val / 1_000_000_000
        if abs(billions) >= 1 { return String(format: "%.1fB", billions) }
        let millions = val / 1_000_000
        return String(format: "%.0fM", millions)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "dollarsign.arrow.circlepath").font(.title2).foregroundColor(.teal)
                Text("Free Cash Flow History (5Y)").font(.headline).foregroundColor(.secondary)
                Spacer()
                if let cagr = cagrDisplay { HStack(spacing: 4) { Image(systemName: "wand.and.stars").font(.caption).foregroundColor(.blue); Text("5Y CAGR: \(cagr)").font(.caption).bold().foregroundColor(.blue) }.padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).cornerRadius(6) }
            }
            Chart {
                ForEach(history) { point in BarMark(x: .value("Year", point.year), y: .value("FCF", point.value)).foregroundStyle(barColor(point.value).gradient).annotation(position: point.value >= 0 ? .top : .bottom) { Text(formatFCF(point.value)).font(.caption2).bold().foregroundColor(barColor(point.value)) }
                    if let sel = selectedYear, sel == point.year { RuleMark(x: .value("Year", point.year)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 4) { Text(point.year).font(.caption).bold(); Text("FCF: \(formatFCF(point.value))").font(.caption2).foregroundColor(barColor(point.value)); Text(point.value >= 0 ? "Positive cash generation ✓" : "Negative FCF — watch carefully ⚠️").font(.caption2).foregroundColor(point.value >= 0 ? .green : .red) }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) }
                }
                if history.contains(where: { $0.value < 0 }) || history.contains(where: { $0.value >= 0 }) { RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.gray.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])) }
            }.chartYScale(domain: yMin...yMax).frame(height: 220).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedYear = x }; case .ended: selectedYear = nil } } } }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.teal.opacity(0.2), lineWidth: 1))
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
                if let selectedPeriod, let rec = getDataForPeriod(selectedPeriod) {
                    RuleMark(x: .value("Period", selectedPeriod)).foregroundStyle(Color.gray.opacity(0.3)).lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Period: \(selectedPeriod)").font(.caption).bold().foregroundColor(.primary); Divider()
                                tooltipRow(label: "Strong Buy", value: rec.strongBuy, color: .green); tooltipRow(label: "Buy", value: rec.buy, color: .mint); tooltipRow(label: "Hold", value: rec.hold, color: .yellow); tooltipRow(label: "Sell", value: rec.sell, color: .orange); tooltipRow(label: "Strong Sell", value: rec.strongSell, color: .red)
                            }.padding(12).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(10).shadow(radius: 5)
                        }.zIndex(10)
                }
            }.chartForegroundStyleScale(["Strong Buy": .green, "Buy": .mint, "Hold": .yellow, "Sell": .orange, "Strong Sell": .red]).frame(height: 250).padding(.top, 50)
            .chartOverlay { proxy in GeometryReader { geo in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedPeriod = x } case .ended: selectedPeriod = nil } } } }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
    func tooltipRow(label: String, value: Int, color: Color) -> some View { HStack { Circle().fill(color).frame(width: 8, height: 8); Text(label).font(.caption2).foregroundColor(.secondary); Spacer(); Text("\(value)").font(.caption2).bold().foregroundColor(.primary) } }
}

struct PriceTargetView: View {
    let priceTarget: FinnhubPriceTarget; let currentPrice: Double; let intrinsicValue: Double; let symbol: String
    @State private var selectedLabel: String? = nil
    struct TargetBar: Identifiable { let id = UUID(); let label: String; let value: Double; let color: Color }
    var bars: [TargetBar] { var result: [TargetBar] = []; if currentPrice > 0 { result.append(TargetBar(label: "Current", value: currentPrice, color: .gray)) }; if intrinsicValue > 0 { result.append(TargetBar(label: "DCF Value", value: intrinsicValue, color: .blue)) }; if let low = priceTarget.targetLow, low > 0 { result.append(TargetBar(label: "Target Low", value: low, color: .orange)) }; if let median = priceTarget.targetMedian, median > 0 { result.append(TargetBar(label: "Target Median", value: median, color: .teal)) }; if let mean = priceTarget.targetMean, mean > 0 { result.append(TargetBar(label: "Target Mean", value: mean, color: .purple)) }; if let high = priceTarget.targetHigh, high > 0 { result.append(TargetBar(label: "Target High", value: high, color: .green)) }; return result }
    var meanUpsidePct: Double? { guard let mean = priceTarget.targetMean, mean > 0, currentPrice > 0 else { return nil }; return ((mean - currentPrice) / currentPrice) * 100 }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Image(systemName: "scope").font(.title2).foregroundColor(.purple); Text("Analyst Price Targets").font(.headline).foregroundColor(.secondary); Spacer()
                if let upside = meanUpsidePct { HStack(spacing: 4) { Image(systemName: upside >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill").foregroundColor(upside >= 0 ? .green : .red); Text(String(format: "Mean: %@%.1f%%", upside >= 0 ? "+" : "", upside)).font(.caption).bold().foregroundColor(upside >= 0 ? .green : .red) }.padding(.horizontal, 8).padding(.vertical, 4).background((upside >= 0 ? Color.green : Color.red).opacity(0.1)).cornerRadius(6) }
            }
            Chart {
                ForEach(bars) { bar in BarMark(x: .value("Label", bar.label), y: .value("Price", bar.value)).foregroundStyle(bar.color.gradient).annotation(position: .top) { Text(String(format: "%.0f", bar.value)).font(.caption2).bold().foregroundColor(bar.color) }
                    if let sel = selectedLabel, sel == bar.label { RuleMark(x: .value("Label", sel)).foregroundStyle(Color.gray.opacity(0.2)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 3) { Text(bar.label).bold().font(.caption); Text(String(format: "%.2f %@", bar.value, symbol)).font(.caption2).foregroundColor(bar.color); if bar.label != "Current" && currentPrice > 0 { let d = ((bar.value - currentPrice) / currentPrice) * 100; Text(String(format: "vs current: %@%.1f%%", d >= 0 ? "+" : "", d)).font(.caption2).foregroundColor(d >= 0 ? .green : .red) } }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) }
                }
            }.frame(height: 220).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedLabel = x }; case .ended: selectedLabel = nil } } } }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
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
            Chart {
                ForEach(chartData) { bar in BarMark(x: .value("Period", bar.period), y: .value("EPS", bar.value)).foregroundStyle(bar.color.gradient).position(by: .value("Type", bar.type)) }
                if let sel = selectedPeriod { let relevant = earnings.first { String(($0.period ?? "").prefix(7)) == sel }; if let e = relevant { RuleMark(x: .value("Period", sel)).foregroundStyle(Color.gray.opacity(0.25)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) { VStack(alignment: .leading, spacing: 4) { Text(sel).bold().font(.caption); if let est = e.estimate { Text(String(format: "Estimate: %.3f", est)).font(.caption2).foregroundColor(.gray) }; if let act = e.actual { Text(String(format: "Actual: %.3f", act)).font(.caption2).foregroundColor(act >= (e.estimate ?? act) ? .green : .red) }; if let pct = e.surprisePercent { Text(String(format: "Surprise: %@%.2f%%", pct >= 0 ? "+" : "", pct)).font(.caption2).bold().foregroundColor(pct >= 0 ? .green : .red) } }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4) }.zIndex(10) } }
            }.chartForegroundStyleScale(["Estimate": Color.gray.opacity(0.6), "Actual": Color.green]).frame(height: 200).chartOverlay { proxy in GeometryReader { _ in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedPeriod = x }; case .ended: selectedPeriod = nil } } } }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.2), lineWidth: 1))
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
                    if let selectedTicker {
                        RuleMark(x: .value("Ticker", selectedTicker)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                            let peVal = (selectedTicker == mainTicker) ? mainPE : (peers.first(where: { $0.ticker == selectedTicker })?.pe ?? 0)
                            VStack { Text(selectedTicker).bold(); Text("P/E: \(String(format: "%.2f", peVal))") }.padding(8).background(Color(nsColor: .windowBackgroundColor)).cornerRadius(8).shadow(radius: 4)
                        }.zIndex(10)
                    }
                }.frame(height: 200).chartOverlay { proxy in GeometryReader { geo in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedTicker = x } case .ended: selectedTicker = nil } } } }
            }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
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
                .chartOverlay { proxy in GeometryReader { geo in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let x: String = proxy.value(atX: l.x) { selectedType = x } case .ended: selectedType = nil } } } }.frame(height: 200)
            }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct PEGRatioGauge: View {
    var currentPE: Double; var growthRate: Double; var peg: Double { growthRate > 0 ? currentPE / growthRate : 0.0 }
    var pegProgress: CGFloat { CGFloat(min(peg, 3.0) / 3.0) }; var statusText: String { peg < 1.0 ? "Undervalued (<1.0)" : peg < 1.5 ? "Fair Value (1.0-1.5)" : "Overvalued (>1.5)" }; var statusColor: Color { peg < 1.0 ? .green : peg < 1.5 ? .yellow : .red }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "gauge.with.needle").font(.title2).foregroundColor(.blue); Text("PEG Ratio (Lynch Valuation)").font(.headline).foregroundColor(.secondary); Spacer(); Text(String(format: "%.2f", peg)).font(.title2).bold().foregroundColor(statusColor) }
            GeometryReader { geo in ZStack(alignment: .leading) { Rectangle().fill(LinearGradient(stops: [.init(color: .green.opacity(0.8), location: 0.0), .init(color: .green.opacity(0.8), location: 0.33), .init(color: .yellow, location: 0.33), .init(color: .yellow, location: 0.5), .init(color: .red.opacity(0.8), location: 0.5), .init(color: .red.opacity(0.8), location: 1.0)], startPoint: .leading, endPoint: .trailing)).frame(height: 20).cornerRadius(10); Image(systemName: "arrowtriangle.down.fill").foregroundColor(.primary).font(.title3).offset(x: (geo.size.width * pegProgress) - 10, y: -20); Text(statusText).font(.caption2).bold().foregroundColor(statusColor).offset(x: (geo.size.width * pegProgress) - 10, y: 22).fixedSize() } }.frame(height: 50)
            HStack { Text("0.0").font(.tiny); Spacer(); Text("1.0 (Cheap)").font(.tiny).padding(.trailing, 40); Spacer(); Text("3.0+").font(.tiny) }.foregroundColor(.gray)
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct FCFYieldGauge: View {
    var fcfPerShare: Double; var currentPrice: Double; var yield: Double { guard currentPrice > 0 else { return 0.0 }; return (fcfPerShare / currentPrice) * 100.0 }
    var yieldProgress: CGFloat { let clamped = min(max(yield, 0.0), 10.0); return CGFloat(clamped / 10.0) }; var statusText: String { if yield < 3.0 { return "Expensive (<3%)" } else if yield < 7.0 { return "Fair (3-7%)" } else { return "Attractive (>7%)" } }; var statusColor: Color { if yield < 3.0 { return .red } else if yield < 7.0 { return .yellow } else { return .green } }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "banknote.fill").font(.title2).foregroundColor(.blue); Text("FCF Yield (Market Payback)").font(.headline).foregroundColor(.blue); Spacer(); Text(String(format: "%.2f%%", yield)).font(.title2).bold().foregroundColor(statusColor) }
            GeometryReader { geo in ZStack(alignment: .leading) { Rectangle().fill(LinearGradient(stops: [.init(color: .red.opacity(0.8), location: 0.0), .init(color: .red.opacity(0.8), location: 0.3), .init(color: .yellow, location: 0.3), .init(color: .yellow, location: 0.7), .init(color: .green.opacity(0.8), location: 0.7), .init(color: .green.opacity(0.8), location: 1.0)], startPoint: .leading, endPoint: .trailing)).frame(height: 20).cornerRadius(10); Image(systemName: "arrowtriangle.down.fill").foregroundColor(.primary).font(.title3).offset(x: max(0, (geo.size.width * yieldProgress) - 10), y: -20); Text(statusText).font(.caption2).bold().foregroundColor(statusColor).offset(x: max(0, (geo.size.width * yieldProgress) - 10), y: 22).fixedSize() } }.frame(height: 50)
            HStack { Text("0%").font(.tiny); Spacer(); Text("5% (Avg)").font(.tiny); Spacer(); Text("10%+").font(.tiny) }.foregroundColor(.gray)
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
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
            }.chartOverlay { proxy in GeometryReader { geo in Rectangle().fill(.clear).contentShape(Rectangle()).onContinuousHover { phase in switch phase { case .active(let l): if let y: String = proxy.value(atY: l.y) { selectedLabel = y } case .ended: selectedLabel = nil } } } }.frame(height: 160).chartXAxis { AxisMarks(position: .bottom) }.chartYAxis { AxisMarks(position: .leading) }
            if drawdown < -20 { Text("📉 Trading significantly below highs. Potential opportunity if fundamentals are intact.").font(.caption).italic().foregroundColor(.secondary) }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
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
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
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
                HStack {
                    Image(systemName: "graduationcap.fill").font(.title2).foregroundColor(.blue)
                    Text("Understanding DCF").font(.title3).bold()
                    Spacer()
                }
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

struct InsiderTradesChart: View {
    let transactions: [FinnhubInsiderTransaction]
    @State private var selectedDate: String?
    
    var chartData: [InsiderChartItem] {
        var aggregated: [String: Int] = [:]
        for t in transactions {
            if let dateStr = t.transactionDate, let change = t.change, change != 0 {
                aggregated[dateStr, default: 0] += change
            }
        }
        var items: [InsiderChartItem] = []
        let parser = DateFormatter(); parser.dateFormat = "yyyy-MM-dd"
        let displayFormatter = DateFormatter(); displayFormatter.dateFormat = "MMM dd, yy"
        
        for (dateStr, netChange) in aggregated {
            if let date = parser.date(from: dateStr), netChange != 0 {
                items.append(InsiderChartItem(
                    date: date,
                    dateString: displayFormatter.string(from: date),
                    type: netChange > 0 ? "Buy" : "Sell",
                    shares: abs(netChange),
                    color: netChange > 0 ? .green : .red
                ))
            }
        }
        return items.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2.circle.fill").font(.title2).foregroundColor(.blue)
                Text("Insider Activity (Buy/Sell)").font(.headline).foregroundColor(.secondary)
            }
            if chartData.isEmpty {
                Text("No recent insider transactions found.").font(.caption).italic().foregroundColor(.secondary)
            } else {
                Chart(chartData) { item in
                    BarMark(
                        x: .value("Date", item.dateString),
                        y: .value("Shares", item.shares)
                    )
                    .foregroundStyle(item.color.gradient)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        if let intVal = value.as(Int.self) {
                            AxisValueLabel(intVal.formatted(.number.notation(.compactName)))
                        } else {
                            AxisValueLabel()
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Export PDF View Vectoriel
struct PDFExportView: View {
    let ticker: String; let stockName: String; let currentPrice: Double; let intrinsicValue: Double; let currencySymbol: String
    let growthRate: Double; let discountRate: Double; let exitMultiple: Double; let marginOfSafety: Double
    let fcfInput: String; let cashInput: String; let debtInput: String; let sharesInput: String; let currentPEInput: String
    let fcfCagrDisplay: String?; let betaInput: Double?
    let fcfHistory: [FCFHistoryPoint]; let projectionData: [ProjectionPoint]; let priceTarget: FinnhubPriceTarget?
    let earningsData: [FinnhubEarnings]; let parseDouble: (String) -> Double

    var updownPct: Double { guard currentPrice > 0, intrinsicValue > 0 else { return 0 }; return ((intrinsicValue - currentPrice) / intrinsicValue) * 100 }
    var targetBuyPrice: Double { intrinsicValue * (1.0 - (marginOfSafety / 100.0)) }
    var isBuyable: Bool { currentPrice > 0 && currentPrice <= targetBuyPrice }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text("\(ticker) — DCF Analysis").font(.system(size: 28, weight: .black)).foregroundColor(.white); if !stockName.isEmpty { Text(stockName).font(.headline).foregroundColor(.white.opacity(0.8)) } }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) { Text("Fair Value Report").font(.caption).foregroundColor(.white.opacity(0.7)); Text(Date().formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundColor(.white.opacity(0.7)) }
            }.padding(24).background(LinearGradient(colors: [Color.blue, Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    pdfStatCard(label: "Current Price", value: String(format: "%.2f %@", currentPrice, currencySymbol), color: .primary)
                    pdfStatCard(label: "Intrinsic Value", value: String(format: "%.2f %@", intrinsicValue, currencySymbol), color: intrinsicValue > currentPrice ? .green : .red)
                    pdfStatCard(label: updownPct >= 0 ? "Undervalued By" : "Overvalued By", value: String(format: "%.1f%%", abs(updownPct)), color: updownPct >= 0 ? .green : .red)
                    pdfStatCard(label: "Buy Target (\(Int(marginOfSafety))% MoS)", value: String(format: "%.2f %@", targetBuyPrice, currencySymbol), color: isBuyable ? .green : .orange)
                }
                Divider()
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DCF Parameters").font(.headline).foregroundColor(.secondary)
                        pdfKeyValue("FCF/Share", fcfInput); pdfKeyValue("Growth Rate", String(format: "%.1f%%", growthRate)); pdfKeyValue("Discount Rate", String(format: "%.1f%%", discountRate)); pdfKeyValue("Exit Multiple", String(format: "%.1fx", exitMultiple))
                        if let cagr = fcfCagrDisplay { pdfKeyValue("5Y FCF CAGR", cagr) }
                        if let beta = betaInput { pdfKeyValue("Beta", String(format: "%.2f", beta)) }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Balance Sheet").font(.headline).foregroundColor(.secondary)
                        pdfKeyValue("Cash (B)", cashInput); pdfKeyValue("Debt (B)", debtInput); pdfKeyValue("Shares (B)", sharesInput); pdfKeyValue("Current P/E", currentPEInput)
                        if let pt = priceTarget, let mean = pt.targetMean { pdfKeyValue("Analyst Target (Mean)", String(format: "%.2f", mean)) }
                    }
                }
                if !fcfHistory.isEmpty { Divider(); Text("FCF History").font(.headline).foregroundColor(.secondary)
                    Chart { ForEach(fcfHistory) { pt in BarMark(x: .value("Year", pt.year), y: .value("FCF", pt.value)).foregroundStyle((pt.value >= 0 ? Color.teal : Color.red).gradient) }; RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.gray.opacity(0.5)) }.frame(height: 160)
                }
                if !projectionData.isEmpty { Divider(); Text("Value Projection (5Y)").font(.headline).foregroundColor(.secondary)
                    Chart { RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        ForEach(projectionData) { pt in LineMark(x: .value("Year", pt.year), y: .value("Value", pt.value)).foregroundStyle(.blue).interpolationMethod(.monotone); PointMark(x: .value("Year", pt.year), y: .value("Value", pt.value)).foregroundStyle(.blue) }
                    }.frame(height: 160)
                }
                Divider()
                Text("⚠️ This analysis is for informational purposes only and does not constitute financial advice. Always do your own due diligence before investing.").font(.caption2).foregroundColor(.secondary).italic()
            }.padding(24)
        }.frame(width: 794).background(Color(nsColor: .windowBackgroundColor))
    }

    func pdfStatCard(label: String, value: String, color: Color) -> some View { VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption2).foregroundColor(.secondary); Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(color) }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Color.gray.opacity(0.08)).cornerRadius(8) }
    func pdfKeyValue(_ key: String, _ value: String) -> some View { HStack { Text(key).font(.caption).foregroundColor(.secondary); Spacer(); Text(value).font(.caption).bold() } }
}

// UTILS
extension Font { static let tiny = Font.system(size: 10) }
