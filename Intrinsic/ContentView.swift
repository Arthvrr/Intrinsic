import SwiftUI
import Charts

// --- MODELS DONNÉES (Sendable pour Swift 6) ---

struct FinnhubQuote: Codable, Sendable {
    let c: Double // Current Price (En USD pour les ADR)
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

// Modèle pour ExchangeRate-API
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
}

// --- APP ENUMS & STRUCTS ---

enum ValuationMethod: String, CaseIterable, Identifiable {
    case gordon = "Conservative (Perpetual)"
    case multiples = "Market (Multiples)"
    var id: Self { self }
}

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

// --- FINNHUB SERVICE (CONVERSION TOTALE ADR) ---

actor FinnhubService {
    private let finnhubApiKey = "d5h5jppr01qjo5tfncbgd5h5jppr01qjo5tfncc0"
    private let exchangeRateApiKey = "2d3a18191c2ffd303066358c" // TA CLÉ ExchangeRate-API
    
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
    }
    
    private func fetchAndDecode<T: Codable>(url: URL, type: T.Type, label: String) async throws -> T {
        // print("🚀 [\(label)] Fetching: \(url.absoluteString)")
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(T.self, from: data)
    }
    
    // Fonction pour récupérer le taux de change (Devise Locale -> USD)
    private func fetchConversionRateToUSD(from sourceCurrency: String) async -> Double {
        if sourceCurrency == "USD" { return 1.0 }
        
        guard let url = URL(string: "https://v6.exchangerate-api.com/v6/\(exchangeRateApiKey)/latest/\(sourceCurrency)") else {
            return 1.0
        }
        
        do {
            let response = try await fetchAndDecode(url: url, type: ExchangeRateResponse.self, label: "FOREX")
            if response.result == "success", let rate = response.conversion_rates["USD"] {
                print("✅ Taux ExchangeRate trouvé: 1 \(sourceCurrency) = \(rate) USD")
                return rate
            }
        } catch {
            print("❌ Erreur Forex: \(error)")
        }
        return 1.0
    }
    
    func fetchStockData(symbol: String) async throws -> StockData {
        print("\n--- 🟢 DÉBUT ANALYSE : \(symbol) ---")
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
        
        // --- DONNÉES BRUTES ---
        // Hypothèse ADR : Le prix (Quote) est déjà en USD car c'est le ticker US.
        let priceUSD = quoteResult.c
        
        let sharesM = profileResult?.shareOutstanding ?? 0.0
        let sharesB = sharesM / 1000.0
        let profileCurrency = profileResult?.currency?.uppercased() ?? "USD"
        
        print("📊 Info: PrixTicker=\(priceUSD) USD, DeviseComptable=\(profileCurrency)")
        
        // --- PRÉPARATION DU TAUX DE CONVERSION ---
        var conversionRate = 1.0
        if profileCurrency != "USD" {
             print("⚠️ ADR/Devise étrangère détectée (\(profileCurrency)). Conversion des fondamentaux en USD requise.")
             conversionRate = await fetchConversionRateToUSD(from: profileCurrency)
        }
        
        // --- APPLICATION DE LA CONVERSION AUX FONDAMENTAUX (Metric) ---
        // On multiplie tout ce qui vient de 'metric' par le taux, car c'est en devise locale.
        
        // 1. FCF (Conversion)
        var finalFCFPerShare = 0.0
        if let fcfTotal = m.freeCashFlowTTM {
            finalFCFPerShare = sharesM > 0 ? (fcfTotal / sharesM) : 0.0
        } else if let priceToFcf = m.pfcfShareTTM, priceToFcf > 0 {
            // Ici c'est tricky : le ratio Price/FCF est sans unité.
            // Si on déduit le FCF via le Prix (USD) / Ratio, on obtient du USD directement.
            // Mais si on utilise le FCF total (DKK) / Shares, on a du DKK.
            // Priorité au calcul direct :
            if let rawFCF = m.freeCashFlowTTM {
                 finalFCFPerShare = (rawFCF / sharesM) * conversionRate
            } else {
                 // Fallback via ratio (déjà en USD via le prix)
                 finalFCFPerShare = priceUSD / priceToFcf
            }
        }
        // Si on a utilisé le calcul brut, on s'assure qu'il est converti.
        // (Logique simplifiée : si on a appliqué le rate ligne 146, c'est bon).
        // On refait le calcul propre :
        if let fcfTotal = m.freeCashFlowTTM {
             let fcfPerShareNative = sharesM > 0 ? (fcfTotal / sharesM) : 0.0
             finalFCFPerShare = fcfPerShareNative * conversionRate
        }
        
        // 2. Cash (Conversion)
        var finalCashB = 0.0
        if let cashTotalM = m.cashAndEquivalentsAnnual {
            finalCashB = (cashTotalM / 1000.0) * conversionRate
        } else if let cashPerShare = m.cashPerSharePerShareAnnual {
            // cashPerShare est en DKK
            finalCashB = ((cashPerShare * sharesM) / 1000.0) * conversionRate
        }
        
        // 3. Debt (Conversion)
        var finalDebtB = 0.0
        if let debtTotalM = m.totalDebtAnnual {
            finalDebtB = (debtTotalM / 1000.0) * conversionRate
        } else if let debtToEquity = m.totalDebtToEquityAnnual, let bookVal = m.bookValuePerShareAnnual {
            // BookVal est en DKK
            let totalEquityM = sharesM * bookVal
            let totalDebtM = totalEquityM * debtToEquity
            finalDebtB = (totalDebtM / 1000.0) * conversionRate
        }
        
        // 4. 52-Week High (Conversion)
        let rawHigh = m.yearHigh ?? 0.0
        // Si rawHigh est 0 (pas de donnée), on fallback sur le prix actuel
        let convertedHigh = (rawHigh > 0 ? rawHigh : priceUSD) * conversionRate
        
        // Sécurité : High ne peut pas être plus bas que le prix actuel (en USD)
        // Mais attention, si conversionRate est 1.0 (USD), convertedHigh = rawHigh.
        // Si conversionRate < 1 (DKK->USD), convertedHigh devient petit (~100).
        let adjustedHigh = max(convertedHigh, priceUSD)
        
        print("📈 High: Brut=\(rawHigh) \(profileCurrency) -> Converti=\(convertedHigh) USD")

        // 5. PE Historique (Ratio sans unité, pas de conversion nécessaire sauf si incohérence)
        // On suppose que Finnhub calcule le PE correctement (Prix / EPS) dans la même devise.
        var avgPE = 0.0
        if let seriesPE = metricsResult.series?.annual?.pe {
            let validPEs = seriesPE.compactMap { $0.v }.filter { $0 > 0 }
            let recentPEs = validPEs.prefix(5)
            if !recentPEs.isEmpty {
                avgPE = recentPEs.reduce(0, +) / Double(recentPEs.count)
            }
        } else {
            avgPE = m.peTTM ?? 0.0
        }
        
        // 6. CAGR (Pourcentage, pas de conversion)
        var calculatedCagr: Double? = nil
        if let seriesFCF = metricsResult.series?.annual?.freeCashFlow {
            let sortedFCF = seriesFCF.sorted { ($0.period ?? "") < ($1.period ?? "") }
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
            price: priceUSD, // On garde le prix du Ticker (USD)
            currency: "USD",
            sharesOutstandingB: sharesB,
            cashB: finalCashB, // Converti
            debtB: finalDebtB, // Converti
            fcfPerShare: finalFCFPerShare, // Converti
            peCurrent: m.peTTM ?? 0.0,
            peHistoricalAvg: avgPE,
            yearHigh: adjustedHigh, // Converti
            fcfCagr: calculatedCagr
        )
    }
}

// --- MAIN VIEW ---

struct ContentView: View {
    @State private var ticker: String = "NVDA"
    @State private var priceDisplay: String = "---"
    @State private var isLoading = false
    @State private var currentPrice: Double = 0.0
    @State private var yearHigh: Double = 0.0
    @State private var currencySymbol: String = "$"
    @State private var isSidebarVisible: Bool = true

    @State private var fcfInput: String = "0.00"
    @State private var sharesInput: String = "0.00"
    @State private var cashInput: String = "0.00"
    @State private var debtInput: String = "0.00"
    @State private var currentPEInput: String = "0.00"
    @State private var historicalPEInput: String = "0.00"
    @State private var fcfCagrDisplay: String? = nil

    @State private var growthRate: Double = 0.0
    @State private var discountRate: Double = 0.0
    @State private var exitMultiple: Double = 0.0
    
    @State private var selectedMethod: ValuationMethod = .multiples
    @State private var terminalGrowth: Double = 0.0
    @State private var marginOfSafety: Double = 10.0
    
    @State private var intrinsicValue: Double = 0.0
    @State private var marketImpliedGrowth: Double = 0.0
    @State private var projectionData: [ProjectionPoint] = []
    @State private var hasCalculated: Bool = false
    
    private let finnhubService = FinnhubService()

    var body: some View {
        HStack(spacing: 0) {
            
            // SIDEBAR
            if isSidebarVisible {
                VStack(spacing: 0) {
                    HStack {
                        Text("DCF Parameters").font(.headline)
                        Spacer()
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
                        
                        Section(header: Text("Estimates")) {
                            if let cagr = fcfCagrDisplay {
                                HStack {
                                    Text("Hist. 5Y FCF CAGR:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(cagr)
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.blue)
                                }
                                .padding(.bottom, 2)
                            }
                            
                            inputRowDouble(label: "FCF Growth Rate", value: $growthRate, suffix: "%", helpText: "Expected annual FCF growth for 5 years in %")
                            inputRowDouble(label: "Discount Rate", value: $discountRate, suffix: "%", helpText: "Your desired annual return in %")
                            inputRowDouble(label: "Exit Multiple", value: $exitMultiple, suffix: "x", helpText: "Expected P/E ratio in 5 years")
                        }
                    }
                    .formStyle(.grouped)
            
                    Divider()
                    Button(action: { calculateIntrinsicValue() }) {
                        Text("CALCULATE").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large).padding().background(Color(nsColor: .windowBackgroundColor))
                }
                .frame(width: 320).transition(.move(edge: .leading))
            }
            
            if isSidebarVisible { Divider() }
            
            // MAIN CONTENT
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            
                ScrollView {
                    VStack(spacing: 30) {
                        ResultHeaderView(priceDisplay: priceDisplay, intrinsicValue: intrinsicValue, currentPrice: currentPrice, symbol: currencySymbol)
                            .padding(.top, 40)
                        
                        if hasCalculated && currentPrice > 0 {
                            ReverseDCFView(impliedGrowth: marketImpliedGrowth, userGrowth: growthRate, currentPrice: currentPrice, symbol: currencySymbol)
                                .padding(.horizontal)
                        }
                        
                        if hasCalculated && currentPrice > 0 {
                            ValuationBarChart(marketPrice: currentPrice, intrinsicValue: intrinsicValue, symbol: currencySymbol)
                                .frame(height: 180).padding(.horizontal)
                        }
                        
                        if !projectionData.isEmpty && hasCalculated {
                            ProjectedGrowthChart(data: projectionData, currentPrice: currentPrice, symbol: currencySymbol)
                                .padding(.horizontal)
                        }
                        
                        if hasCalculated {
                            SensitivityMatrixView(baseGrowth: growthRate, baseDiscount: discountRate, currentPrice: currentPrice, calculate: runSimulation)
                                .padding(.horizontal)
                        }
                        
                        if hasCalculated {
                            FinancialHealthView(
                                cash: parseDouble(cashInput),
                                debt: parseDouble(debtInput),
                                fcfPerShare: parseDouble(fcfInput),
                                growthRate: growthRate,
                                symbol: currencySymbol
                            )
                            .padding(.horizontal)
                        }
                        
                        if hasCalculated {
                            PEComparisonChart(
                                currentPE: parseDouble(currentPEInput),
                                historicalPE: parseDouble(historicalPEInput),
                                exitMultiple: exitMultiple
                            )
                            .padding(.horizontal)
                            
                            if parseDouble(currentPEInput) > 0 && growthRate > 0 {
                                PEGRatioGauge(
                                    currentPE: parseDouble(currentPEInput),
                                    growthRate: growthRate
                                )
                                .padding(.horizontal)
                            }
                            
                            if parseDouble(fcfInput) > 0 && currentPrice > 0 {
                                FCFYieldGauge(
                                    fcfPerShare: parseDouble(fcfInput),
                                    currentPrice: currentPrice
                                )
                                .padding(.horizontal)
                            }
                        }
                        
                        if hasCalculated && intrinsicValue > 0 {
                            BuyBoxView(
                                intrinsicValue: intrinsicValue,
                                currentPrice: currentPrice,
                                marginOfSafety: $marginOfSafety,
                                symbol: currencySymbol
                            )
                            .padding(.horizontal)
                            
                            if yearHigh > 0 {
                                PriceRangeChart(currentPrice: currentPrice, yearHigh: yearHigh, symbol: currencySymbol)
                                    .padding(.horizontal)
                                    .padding(.bottom, 50)
                            }
                        } else {
                            Color.clear.frame(height: 50)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.horizontal, 20)
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
    
    func fetchFinnhubData() {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanTicker.isEmpty else { return }
        
        isLoading = true
        priceDisplay = "Loading..."
        
        Task {
            do {
                let data = try await finnhubService.fetchStockData(symbol: cleanTicker)
                
                await MainActor.run {
                    self.currentPrice = data.price
                    self.yearHigh = data.yearHigh
                    self.currencySymbol = getCurrencySymbol(code: data.currency)
                    self.priceDisplay = String(format: "%.2f %@", data.price, self.currencySymbol)
                    
                    self.fcfInput = String(format: "%.2f", data.fcfPerShare)
                    self.sharesInput = String(format: "%.3f", data.sharesOutstandingB)
                    self.cashInput = String(format: "%.2f", data.cashB)
                    self.debtInput = String(format: "%.2f", data.debtB)
                    self.currentPEInput = String(format: "%.2f", data.peCurrent)
                    self.historicalPEInput = String(format: "%.2f", data.peHistoricalAvg)
                    
                    if let cagr = data.fcfCagr {
                        self.fcfCagrDisplay = String(format: "%.1f%%", cagr)
                    } else {
                        self.fcfCagrDisplay = nil
                    }
                    
                    self.isLoading = false
                }
            } catch {
                print("❌ ERREUR FETCH : \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.priceDisplay = "Error"
                }
            }
        }
    }
    
    var stockAnalysisLink: some View {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = cleanTicker.isEmpty ? "https://stockanalysis.com" : "https://stockanalysis.com/stocks/\(cleanTicker)/financials/"
        return Link(destination: URL(string: urlString)!) {
            HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("StockAnalysis Data") }.font(.caption).padding(.top, 5)
        }
    }
    
    var guruFocusLink: some View {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = cleanTicker.isEmpty ? "https://www.gurufocus.com" : "https://www.gurufocus.com/term/pettm/\(cleanTicker)"
        return Link(destination: URL(string: urlString)!) {
            HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("GuruFocus P/E Data") }.font(.caption).padding(.top, 5)
        }
    }

    func parseDouble(_ input: String) -> Double {
        let clean = input.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean) ?? 0.0
    }

    func calculateIntrinsicValue() {
        let result = computeDCF(
            fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput),
            g: growthRate, r: discountRate, method: selectedMethod, tg: terminalGrowth, exitMult: exitMultiple
        )
        if currentPrice > 0 { self.marketImpliedGrowth = solveReverseDCF(targetPrice: currentPrice) }
        
        var newProjections: [ProjectionPoint] = []
        var projectedValue = result
        newProjections.append(ProjectionPoint(year: 0, value: result))
        for i in 1...5 {
            projectedValue = projectedValue * (1 + (growthRate / 100.0))
            newProjections.append(ProjectionPoint(year: i, value: projectedValue))
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            self.intrinsicValue = result
            self.projectionData = newProjections
            self.hasCalculated = true
        }
    }
    
    func solveReverseDCF(targetPrice: Double) -> Double {
        var low = -0.50; var high = 1.00; var iterations = 0
        while iterations < 100 {
            let mid = (low + high) / 2.0
            let val = computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: mid * 100.0, r: discountRate, method: selectedMethod, tg: terminalGrowth, exitMult: exitMultiple)
            if abs(val - targetPrice) < 0.1 { return mid * 100.0 }
            if val < targetPrice { low = mid } else { high = mid }
            iterations += 1
        }
        return (low + high) / 2.0 * 100.0
    }
    
    func runSimulation(g: Double, r: Double) -> Double {
        return computeDCF(fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput), g: g, r: r, method: selectedMethod, tg: terminalGrowth, exitMult: exitMultiple)
    }
    
    func computeDCF(fcfPerShare: Double, shares: Double, cash: Double, debt: Double, g: Double, r: Double, method: ValuationMethod, tg: Double, exitMult: Double) -> Double {
        let gDec = g / 100.0; let rDec = r / 100.0
        var currentFCF = fcfPerShare; var sumPV = 0.0
        for i in 1...5 { currentFCF = currentFCF * (1 + gDec); sumPV += (currentFCF / pow(1 + rDec, Double(i))) }
        let terminalValue = method == .gordon ? (currentFCF * (1 + tg/100.0)) / (rDec - tg/100.0) : currentFCF * exitMult
        let netCashPerShare = shares > 0 ? (cash - debt) / shares : 0.0
        return sumPV + (terminalValue / pow(1 + rDec, 5.0)) + netCashPerShare
    }
    
    func getCurrencySymbol(code: String) -> String {
        switch code { case "EUR": return "€"; case "GBP": return "£"; case "JPY": return "¥"; case "CNY": return "¥"; case "INR": return "₹"; case "CAD": return "C$"; case "AUD": return "A$"; default: return "$" }
    }
    
    func inputRowString(label: String, value: Binding<String>, helpText: String) -> some View {
        HStack { Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8); InfoButton(helpText: helpText); Spacer(); TextField("0", text: value).textFieldStyle(.roundedBorder).frame(width: 100).multilineTextAlignment(.trailing) }
    }
    func inputRowDouble(label: String, value: Binding<Double>, suffix: String, helpText: String) -> some View {
        HStack { Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8); InfoButton(helpText: helpText); Spacer(); HStack(spacing: 2) { TextField("", value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 80).multilineTextAlignment(.trailing); Text(suffix).font(.caption).foregroundColor(.secondary) } }
    }
}

// --- NEW CHART COMPONENT (HEIGHT INCREASED) ---

struct PriceRangeChart: View {
    var currentPrice: Double
    var yearHigh: Double
    var symbol: String
    
    var drawdown: Double {
        guard yearHigh > 0 else { return 0.0 }
        return ((currentPrice - yearHigh) / yearHigh) * 100.0
    }
    
    struct BarData: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }
    
    var data: [BarData] {
        [
            .init(label: "52W High", value: yearHigh, color: .gray.opacity(0.5)),
            .init(label: "Current", value: currentPrice, color: .blue)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.down.right.circle.fill").font(.title2).foregroundColor(.blue)
                Text("Price vs 52-Week High").font(.headline).foregroundColor(.secondary)
                Spacer()
                if drawdown < -0.1 {
                    Text("\(String(format: "%.1f", drawdown))%").font(.title3).bold().foregroundColor(.red)
                }
            }
            
            Chart(data) { item in
                BarMark(
                    x: .value("Price", item.value),
                    y: .value("Type", item.label)
                )
                .foregroundStyle(item.color.gradient)
                .annotation(position: .trailing) {
                    Text(String(format: "%.2f %@", item.value, symbol))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 160)
            .chartXAxis { AxisMarks(position: .bottom) }
            .chartYAxis { AxisMarks(position: .leading) }
            
            if drawdown < -20 {
                Text("📉 Trading significantly below highs. Potential opportunity if fundamentals are intact.")
                    .font(.caption).italic().foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

// --- EXISTING SUBVIEWS (unchanged logic) ---

struct InfoButton: View {
    let helpText: String
    @State private var show = false
    var body: some View { Button(action: { show.toggle() }) { Image(systemName: "info.circle").foregroundColor(.secondary) }.buttonStyle(.plain).popover(isPresented: $show) { Text(helpText).padding().frame(width: 250) } }
}

struct FinancialHealthView: View {
    var cash: Double
    var debt: Double
    var fcfPerShare: Double
    var growthRate: Double
    var symbol: String
    var netCash: Double { cash - debt }
    var fcfProjections: [Double] {
        var values: [Double] = []
        var current = fcfPerShare
        for _ in 1...5 {
            current = current * (1 + growthRate / 100.0)
            values.append(current)
        }
        return values
    }
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "shield.checkerboard").font(.title2).foregroundColor(.blue)
                Text("Risk & Growth Check").font(.headline).foregroundColor(.secondary)
                Spacer()
            }
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Balance Sheet").font(.caption).bold().foregroundColor(.secondary)
                    if cash == 0 && debt == 0 {
                        Text("Enter Cash & Debt").font(.caption).italic().foregroundColor(.secondary)
                    } else {
                        HStack(alignment: .bottom, spacing: 15) {
                            VStack {
                                Text(String(format: "%.1fB", cash)).font(.caption2)
                                RoundedRectangle(cornerRadius: 6).fill(Color.green.gradient).frame(width: 30, height: 60 * (cash / max(cash, debt, 1.0)))
                                Text("Cash").font(.tiny).bold()
                            }
                            VStack {
                                Text(String(format: "%.1fB", debt)).font(.caption2)
                                RoundedRectangle(cornerRadius: 6).fill(Color.red.gradient).frame(width: 30, height: 60 * (debt / max(cash, debt, 1.0)))
                                Text("Debt").font(.tiny).bold()
                            }
                        }.frame(height: 80)
                        Text(netCash >= 0 ? "Net Cash (Safe)" : "Net Debt (Leveraged)").font(.tiny).bold().foregroundColor(netCash >= 0 ? .green : .red).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4)
                    }
                }
                .padding().frame(maxWidth: .infinity).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Proj. FCF Growth (5Y)").font(.caption).bold().foregroundColor(.secondary)
                    if fcfPerShare > 0 {
                        HStack(alignment: .bottom, spacing: 8) {
                            let data = fcfProjections
                            let maxVal = (data.max() ?? 1.0) * 1.1
                            ForEach(0..<5) { i in
                                VStack(spacing: 2) {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 4).fill(Color.blue.gradient).frame(height: 60 * (data[i] / maxVal))
                                    Text("\(Int(data[i]))").font(.system(size: 9))
                                    Text("Y\(i+1)").font(.tiny).foregroundColor(.secondary)
                                }
                            }
                        }.frame(height: 80)
                        Text("CAGR: \(String(format: "%.1f", growthRate))%").font(.tiny).bold().foregroundColor(growthRate > 0 ? .green : .red).padding(4).background(Color.gray.opacity(0.1)).cornerRadius(4)
                    } else {
                        Text("Enter Positive FCF").font(.caption).italic().foregroundColor(.secondary)
                    }
                }
                .padding().frame(maxWidth: .infinity).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            }
        }
    }
}

struct BuyBoxView: View {
    var intrinsicValue: Double
    var currentPrice: Double
    @Binding var marginOfSafety: Double
    var symbol: String
    var targetBuyPrice: Double { intrinsicValue * (1.0 - (marginOfSafety / 100.0)) }
    var isBuyable: Bool { currentPrice > 0 && currentPrice <= targetBuyPrice }
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "cart.fill.badge.plus").font(.title2).foregroundColor(isBuyable ? .green : .secondary)
                Text("Entry Price Planner").font(.headline).foregroundColor(.secondary)
                Spacer()
                Text(isBuyable ? "BUY ZONE" : "WAIT").font(.caption).fontWeight(.black).padding(.horizontal, 8).padding(.vertical, 4).background(isBuyable ? Color.green : Color.orange).foregroundColor(.white).cornerRadius(8)
            }
            Divider()
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Margin of Safety").font(.caption).bold().foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(marginOfSafety))%").font(.body).bold().foregroundColor(.blue)
                }
                Slider(value: $marginOfSafety, in: 0...60, step: 5).tint(.blue)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text("Target Buy Price").font(.caption).foregroundColor(.secondary)
                    Text(String(format: "%.2f %@", targetBuyPrice, symbol)).font(.system(size: 32, weight: .bold)).foregroundColor(isBuyable ? .green : .primary)
                }
                Spacer()
                if currentPrice > 0 {
                    VStack(alignment: .trailing) {
                        let delta = (currentPrice - targetBuyPrice) / targetBuyPrice * 100
                        Text(isBuyable ? "Discount" : "Premium").font(.caption).foregroundColor(isBuyable ? .green : .orange)
                        Text(String(format: "%@%.1f%%", isBuyable ? "-" : "+", abs(delta))).font(.title3).bold().foregroundColor(isBuyable ? .green : .orange)
                    }
                }
            }
        }
        .padding().background(ZStack { Color(nsColor: .controlBackgroundColor); if isBuyable { Color.green.opacity(0.05) } }).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isBuyable ? Color.green : Color.gray.opacity(0.2), lineWidth: isBuyable ? 2 : 1))
    }
}

struct ReverseDCFView: View {
    var impliedGrowth: Double; var userGrowth: Double; var currentPrice: Double; var symbol: String
    var isRisky: Bool { impliedGrowth > userGrowth }
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: isRisky ? "exclamationmark.triangle.fill" : "hand.thumbsup.fill").font(.largeTitle).foregroundColor(isRisky ? .orange : .green).frame(width: 50)
            VStack(alignment: .leading, spacing: 5) {
                Text("Reverse DCF (Market Expectations)").font(.headline).foregroundColor(.secondary)
                Text("To justify the price of \(String(format: "%.2f %@", currentPrice, symbol)), the market expects a growth of:").font(.caption).foregroundColor(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f%%", impliedGrowth)).font(.title2).bold().foregroundColor(isRisky ? .orange : .primary)
                    Text("per year").font(.caption).bold().foregroundColor(.secondary)
                    Text(isRisky ? "(Higher than your \(String(format: "%.1f", userGrowth))%)" : "(Lower than your \(String(format: "%.1f", userGrowth))%)").font(.caption).foregroundColor(isRisky ? .red : .green).padding(.leading, 5)
                }
            }
            Spacer()
        }.padding().frame(maxWidth: .infinity).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isRisky ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1))
    }
}

struct ResultHeaderView: View {
    var priceDisplay: String; var intrinsicValue: Double; var currentPrice: Double; var symbol: String
    var body: some View {
        VStack(spacing: 15) {
            HStack(spacing: 50) {
                VStack { Text("Current Price").font(.headline).foregroundColor(.secondary); Text(priceDisplay).font(.system(size: 36, weight: .bold)) }
                Image(systemName: "arrow.right").font(.largeTitle).opacity(0.3)
                VStack { Text("Intrinsic Value").font(.headline).foregroundColor(.secondary); Text(String(format: "%.2f %@", intrinsicValue, symbol)).font(.system(size: 36, weight: .bold)).foregroundColor(intrinsicValue > currentPrice ? .green : .red) }
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

struct SensitivityMatrixView: View {
    let baseGrowth: Double; let baseDiscount: Double; let currentPrice: Double; let calculate: (Double, Double) -> Double
    var growthSteps: [Double] { [baseGrowth-3, baseGrowth-2, baseGrowth-1, baseGrowth, baseGrowth+1, baseGrowth+2, baseGrowth+3] }
    var discountSteps: [Double] { [baseDiscount-3, baseDiscount-2, baseDiscount-1, baseDiscount, baseDiscount+1, baseDiscount+2, baseDiscount+3] }
    func getColor(value: Double) -> Color {
        guard currentPrice > 0 else { return .gray.opacity(0.1) }
        let diff = (value - currentPrice) / currentPrice
        if diff > 0 { return Color.green.opacity(min(diff * 2.5, 0.6) + 0.05) } else { return Color.red.opacity(min(abs(diff) * 2.5, 0.6) + 0.05) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "tablecells").font(.title2).foregroundColor(.blue)
                Text("Sensitivity Matrix (7x7 Heatmap)").font(.headline).foregroundColor(.secondary)
            }
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    Text("Disc. \\ Grwth").font(.caption2).foregroundColor(.secondary).frame(width: 70, alignment: .leading)
                    ForEach(growthSteps, id: \.self) { g in Text("\(String(format: "%.0f", g))%").font(.caption2).bold().foregroundColor(g == baseGrowth ? .blue : .primary) }
                }
                ForEach(discountSteps, id: \.self) { r in
                    GridRow {
                        Text("\(String(format: "%.1f", r))%").font(.caption2).bold().foregroundColor(r == baseDiscount ? .blue : .primary).frame(width: 70, alignment: .leading)
                        ForEach(growthSteps, id: \.self) { g in
                            let val = calculate(g, r)
                            Text(String(format: "%.0f", val)).font(.system(size: 11, weight: .medium)).foregroundColor(.primary).frame(maxWidth: .infinity, minHeight: 30).background(getColor(value: val)).cornerRadius(4).overlay(RoundedRectangle(cornerRadius: 4).stroke((r == baseDiscount && g == baseGrowth) ? Color.blue : Color.clear, lineWidth: 2))
                        }
                    }
                }
            }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12)
    }
}

struct PEComparisonChart: View {
    var currentPE: Double; var historicalPE: Double; var exitMultiple: Double
    var data: [PEDataPoint] {
        [.init(type: "Historical", value: historicalPE, color: .gray.opacity(0.5)),
         .init(type: "Current", value: currentPE, color: .gray),
         .init(type: "Exit (Yr 5)", value: exitMultiple, color: .blue)]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "chart.bar.xaxis").font(.title2).foregroundColor(.blue)
                Text("Valuation Reality Check (P/E Ratios)").font(.headline).foregroundColor(.secondary)
            }
            if currentPE == 0 && historicalPE == 0 && exitMultiple == 0 {
                Text("Enter P/E data to visualize comparison").font(.caption).italic().foregroundColor(.secondary)
            } else {
                Chart(data) { point in
                    BarMark(x: .value("Type", point.type), y: .value("P/E Ratio", point.value)).foregroundStyle(point.color.gradient).annotation(position: .top) { Text(String(format: "%.1fx", point.value)).font(.caption).bold() }
                }.frame(height: 200)
            }
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct PEGRatioGauge: View {
    var currentPE: Double; var growthRate: Double
    var peg: Double { growthRate > 0 ? currentPE / growthRate : 0.0 }
    var pegProgress: CGFloat { CGFloat(min(peg, 3.0) / 3.0) }
    var statusText: String { peg < 1.0 ? "Undervalued (<1.0)" : peg < 1.5 ? "Fair Value (1.0-1.5)" : "Overvalued (>1.5)" }
    var statusColor: Color { peg < 1.0 ? .green : peg < 1.5 ? .yellow : .red }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gauge.with.needle").font(.title2).foregroundColor(.blue)
                Text("PEG Ratio (Lynch Valuation)").font(.headline).foregroundColor(.secondary)
                Spacer(); Text(String(format: "%.2f", peg)).font(.title2).bold().foregroundColor(statusColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(LinearGradient(stops: [.init(color: .green.opacity(0.8), location: 0.0), .init(color: .green.opacity(0.8), location: 0.33), .init(color: .yellow, location: 0.33), .init(color: .yellow, location: 0.5), .init(color: .red.opacity(0.8), location: 0.5), .init(color: .red.opacity(0.8), location: 1.0)], startPoint: .leading, endPoint: .trailing)).frame(height: 20).cornerRadius(10)
                    Image(systemName: "arrowtriangle.down.fill").foregroundColor(.primary).font(.title3).offset(x: (geo.size.width * pegProgress) - 10, y: -20)
                    Text(statusText).font(.caption2).bold().foregroundColor(statusColor).offset(x: (geo.size.width * pegProgress) - 10, y: 22).fixedSize()
                }
            }.frame(height: 50)
            HStack { Text("0.0").font(.tiny); Spacer(); Text("1.0 (Cheap)").font(.tiny).padding(.trailing, 40); Spacer(); Text("3.0+").font(.tiny) }.foregroundColor(.gray)
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

struct FCFYieldGauge: View {
    var fcfPerShare: Double
    var currentPrice: Double
    var yield: Double {
        guard currentPrice > 0 else { return 0.0 }
        return (fcfPerShare / currentPrice) * 100.0
    }
    var yieldProgress: CGFloat {
        let clamped = min(max(yield, 0.0), 10.0)
        return CGFloat(clamped / 10.0)
    }
    var statusText: String {
        if yield < 3.0 { return "Expensive (<3%)" }
        else if yield < 7.0 { return "Fair (3-7%)" }
        else { return "Attractive (>7%)" }
    }
    var statusColor: Color {
        if yield < 3.0 { return .red }
        else if yield < 7.0 { return .yellow }
        else { return .green }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "banknote.fill").font(.title2).foregroundColor(.green)
                Text("FCF Yield (Market Payback)").font(.headline).foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2f%%", yield)).font(.title2).bold().foregroundColor(statusColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(LinearGradient(stops: [
                        .init(color: .red.opacity(0.8), location: 0.0),
                        .init(color: .red.opacity(0.8), location: 0.3),
                        .init(color: .yellow, location: 0.3),
                        .init(color: .yellow, location: 0.7),
                        .init(color: .green.opacity(0.8), location: 0.7),
                        .init(color: .green.opacity(0.8), location: 1.0)
                    ], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 20).cornerRadius(10)
                    
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(.primary)
                        .font(.title3)
                        .offset(x: max(0, (geo.size.width * yieldProgress) - 10), y: -20)
                    
                    Text(statusText)
                        .font(.caption2).bold().foregroundColor(statusColor)
                        .offset(x: max(0, (geo.size.width * yieldProgress) - 10), y: 22)
                        .fixedSize()
                }
            }.frame(height: 50)
            HStack {
                Text("0%").font(.tiny)
                Spacer()
                Text("5% (Avg)").font(.tiny)
                Spacer()
                Text("10%+").font(.tiny)
            }.foregroundColor(.gray)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

extension Font { static let tiny = Font.system(size: 10) }

struct ValuationBarChart: View {
    var marketPrice: Double; var intrinsicValue: Double; var symbol: String
    private var maxValue: Double { max(marketPrice, intrinsicValue) * 1.1 }
    var body: some View {
        GeometryReader { g in
            HStack(alignment: .bottom, spacing: 60) {
                BarView(value: marketPrice, maxValue: maxValue, label: "Market", color: .gray.opacity(0.4), height: g.size.height, symbol: symbol)
                BarView(value: intrinsicValue, maxValue: maxValue, label: "Value", color: intrinsicValue >= marketPrice ? .green : .red, height: g.size.height, symbol: symbol)
            }
        }
    }
}

struct BarView: View {
    var value: Double; var maxValue: Double; var label: String; var color: Color; var height: CGFloat; var symbol: String
    var body: some View {
        VStack {
            Text("\(Int(value)) \(symbol)").font(.headline).foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 8).fill(color.gradient).frame(height: maxValue > 0 ? height * (value / maxValue) : 0).animation(.spring, value: value)
            Text(label).font(.subheadline).fontWeight(.bold).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct ProjectedGrowthChart: View {
    var data: [ProjectionPoint]; var currentPrice: Double; var symbol: String
    @State private var selectedYear: Int?
    var yDomain: ClosedRange<Double> { let all = data.map { $0.value } + [currentPrice]; return ((all.min() ?? 0) * 0.9)...((all.max() ?? 100) * 1.1) }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.title2).foregroundColor(.blue)
                    Text("Value Projection vs Price").font(.headline).foregroundColor(.secondary)
                }
                HStack(spacing: 15) {
                    HStack(spacing: 5) { Image(systemName: "circle.fill").foregroundColor(.blue).font(.caption); Text("Intrinsic Value").font(.caption).bold() }
                    HStack(spacing: 5) { Image(systemName: "line.horizontal.3").foregroundColor(.red).font(.caption); Text("Current Price").font(.caption).bold() }
                }
            }
            Chart {
                RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5])).annotation(position: .top, alignment: .leading) { Text("Price: \(Int(currentPrice))\(symbol)").font(.caption2).foregroundColor(.red) }
                ForEach(data) { point in
                    LineMark(x: .value("Year", point.year), y: .value("Value", point.value)).foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 3)).interpolationMethod(.monotone)
                    PointMark(x: .value("Year", point.year), y: .value("Value", point.value)).foregroundStyle(.blue).symbolSize(60)
                }
                if let selectedYear {
                    RuleMark(x: .value("Year", selectedYear)).foregroundStyle(Color.gray.opacity(0.3)).annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        if let point = data.first(where: { $0.year == selectedYear }) {
                            VStack(alignment: .leading, spacing: 4) { Text("Year \(point.year)").font(.caption).bold().foregroundColor(.secondary); Text("Value: \(Int(point.value)) \(symbol)").font(.caption).bold().foregroundColor(.blue) }.padding(6).background(.regularMaterial).cornerRadius(6).shadow(radius: 2)
                        }
                    }
                }
            }.chartYScale(domain: yDomain).chartXSelection(value: $selectedYear).chartXScale(domain: 0...5).frame(height: 250)
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}
