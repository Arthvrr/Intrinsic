import SwiftUI
import Charts

// --- DATA STRUCTURES (API V8 - CHART - ROBUSTE POUR LE PRIX) ---
struct YahooResponse: Codable { let chart: YahooChart }
struct YahooChart: Codable { let result: [YahooResult]?; let error: YahooError? }
struct YahooError: Codable { let description: String? }
struct YahooResult: Codable { let meta: YahooMeta }
struct YahooMeta: Codable {
    let symbol: String
    let currency: String?
    let regularMarketPrice: Double?
    let previousClose: Double?
    let chartPreviousClose: Double?
}

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

// --- MAIN VIEW ---

struct ContentView: View {
    // --- STATES ---
    @State private var ticker: String = "NVDA"
    @State private var priceDisplay: String = "---"
    @State private var isLoading = false
    @State private var currentPrice: Double = 0.0
    @State private var currencySymbol: String = "$"
    @State private var isSidebarVisible: Bool = true

    // Inputs (Fundamentals)
    @State private var fcfInput: String = "0.00"
    @State private var sharesInput: String = "0.00"
    @State private var cashInput: String = "0.00"
    @State private var debtInput: String = "0.00"

    // Inputs (P/E Context) - MANUEL
    @State private var currentPEInput: String = "0.00"
    @State private var historicalPEInput: String = "0.00"

    // Estimates
    @State private var growthRate: Double = 0.0
    @State private var discountRate: Double = 0.0
    @State private var exitMultiple: Double = 0.0
    
    // Method
    @State private var selectedMethod: ValuationMethod = .multiples
    @State private var terminalGrowth: Double = 0.0
    
    // Results
    @State private var intrinsicValue: Double = 0.0
    @State private var marketImpliedGrowth: Double = 0.0
    @State private var projectionData: [ProjectionPoint] = []
    @State private var hasCalculated: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            
            // --- LEFT COLUMN (Sidebar) ---
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
                                TextField("Ticker", text: $ticker).onSubmit { fetchPrice() }
                                Button("Load") { fetchPrice() }
                            }
                            HStack {
                                Text("Current Price:"); Spacer()
                                if isLoading { ProgressView().scaleEffect(0.5) }
                                Text(priceDisplay).bold()
                            }
                        }
                        
                        Section(header: Text("Fundamentals"), footer: stockAnalysisLink) {
                            inputRowString(label: "FCF / Share", value: $fcfInput, helpText: "Free Cash Flow per share")
                            inputRowString(label: "Shares (B)", value: $sharesInput, helpText: "Total shares outstanding (Billions)")
                            inputRowString(label: "Cash (B)", value: $cashInput, helpText: "Total Cash & Equivalents (Billions)")
                            inputRowString(label: "Debt (B)", value: $debtInput, helpText: "Total Debt (Billions)")
                        }
                        
                        // SECTION P/E (MANUEL)
                        Section(header: Text("P/E Ratios (Context)")) {
                            inputRowString(label: "Current P/E", value: $currentPEInput, helpText: "Enter the current P/E manually")
                            inputRowString(label: "Historical P/E", value: $historicalPEInput, helpText: "Enter the 5-10y average P/E manually")
                        }
                        
                        Section(header: Text("Estimates")) {
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
            
            // --- RIGHT COLUMN (Results) ---
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
              
                ScrollView {
                    VStack(spacing: 30) {
                        // Header Results
                        ResultHeaderView(priceDisplay: priceDisplay, intrinsicValue: intrinsicValue, currentPrice: currentPrice, symbol: currencySymbol)
                            .padding(.top, 40)
                        
                        // Reverse DCF
                        if hasCalculated && currentPrice > 0 {
                            ReverseDCFView(impliedGrowth: marketImpliedGrowth, userGrowth: growthRate, currentPrice: currentPrice, symbol: currencySymbol)
                                .padding(.horizontal)
                                .id("ReverseDCF-\(marketImpliedGrowth)-\(growthRate)")
                        }
                       
                        // Bar Chart
                        if hasCalculated && currentPrice > 0 {
                            ValuationBarChart(marketPrice: currentPrice, intrinsicValue: intrinsicValue, symbol: currencySymbol)
                                .frame(height: 180).padding(.horizontal)
                        }
                       
                        // Line Chart
                        if !projectionData.isEmpty && hasCalculated {
                            ProjectedGrowthChart(data: projectionData, currentPrice: currentPrice, symbol: currencySymbol)
                                .padding(.horizontal)
                        }
                       
                        // Heatmap
                        if hasCalculated {
                            SensitivityMatrixView(baseGrowth: growthRate, baseDiscount: discountRate, currentPrice: currentPrice, calculate: runSimulation)
                                .padding(.horizontal)
                        }
                        
                        // --- P/E COMPARISON CHART (MANUEL) ---
                        if hasCalculated {
                            PEComparisonChart(
                                currentPE: parseDouble(currentPEInput),
                                historicalPE: parseDouble(historicalPEInput),
                                exitMultiple: exitMultiple
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 50)
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
    
    var stockAnalysisLink: some View {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = cleanTicker.isEmpty ? "https://stockanalysis.com" : "https://stockanalysis.com/stocks/\(cleanTicker)/financials/"
        return Link(destination: URL(string: urlString)!) {
            HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("StockAnalysis Data") }.font(.caption).padding(.top, 5)
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
    
    // --- ANCIENNE FONCTION ROBUSTE POUR LE PRIX ---
    func fetchPrice() {
        let clean = ticker.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").uppercased()
        guard !clean.isEmpty, let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(clean)?interval=1d") else { return }
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { isLoading = false } }
            if let data = data, let resp = try? JSONDecoder().decode(YahooResponse.self, from: data), let res = resp.chart.result?.first {
                let p = res.meta.regularMarketPrice ?? res.meta.previousClose ?? 0.0
                
                // Detection devise
                let currencyCode = res.meta.currency ?? "USD"
                let sym = getCurrencySymbol(code: currencyCode)
                
                DispatchQueue.main.async {
                    self.currentPrice = p
                    self.currencySymbol = sym
                    self.priceDisplay = String(format: "%.2f %@", p, sym) // Affichage propre : 185.04 €
                }
            }
        }.resume()
    }
    
    func inputRowString(label: String, value: Binding<String>, helpText: String) -> some View {
        HStack { Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8); InfoButton(helpText: helpText); Spacer(); TextField("0", text: value).textFieldStyle(.roundedBorder).frame(width: 100).multilineTextAlignment(.trailing) }
    }
    func inputRowDouble(label: String, value: Binding<Double>, suffix: String, helpText: String) -> some View {
        HStack { Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8); InfoButton(helpText: helpText); Spacer(); HStack(spacing: 2) { TextField("", value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 80).multilineTextAlignment(.trailing); Text(suffix).font(.caption).foregroundColor(.secondary) } }
    }
}

// --- SUBVIEWS ---

struct InfoButton: View {
    let helpText: String
    @State private var show = false
    var body: some View { Button(action: { show.toggle() }) { Image(systemName: "info.circle").foregroundColor(.secondary) }.buttonStyle(.plain).popover(isPresented: $show) { Text(helpText).padding().frame(width: 250) } }
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
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(isRisky ? Color.orange.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1))
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
            Text("Sensitivity Matrix (7x7 Heatmap)").font(.headline).foregroundColor(.secondary)
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

// --- NEW CHART: P/E COMPARISON ---
struct PEComparisonChart: View {
    var currentPE: Double
    var historicalPE: Double
    var exitMultiple: Double
    
    var data: [PEDataPoint] {
        [
            .init(type: "Historical", value: historicalPE, color: .gray.opacity(0.5)),
            .init(type: "Current", value: currentPE, color: .gray),
            .init(type: "Exit (Yr 5)", value: exitMultiple, color: .blue)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Valuation Reality Check (P/E Ratios)").font(.headline).foregroundColor(.secondary)
            
            if currentPE == 0 && historicalPE == 0 && exitMultiple == 0 {
                Text("Enter P/E data to visualize comparison").font(.caption).italic().foregroundColor(.secondary)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("Type", point.type),
                        y: .value("P/E Ratio", point.value)
                    )
                    .foregroundStyle(point.color.gradient)
                    .annotation(position: .top) {
                        Text(String(format: "%.1fx", point.value))
                            .font(.caption).bold().foregroundColor(.primary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}

// --- OTHER CHARTS ---
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
                Text("Value Projection vs Price").font(.headline).foregroundColor(.secondary)
                HStack(spacing: 15) {
                    HStack(spacing: 5) { Image(systemName: "circle.fill").foregroundColor(.blue).font(.caption); Text("Intrinsic Value").font(.caption).bold() }
                    HStack(spacing: 5) { Image(systemName: "line.horizontal.3").foregroundColor(.red).font(.caption); Text("Current Price").font(.caption).bold() }
                }
            }
            Chart {
                RuleMark(y: .value("Price", currentPrice)).foregroundStyle(.red).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .leading) { Text("Price: \(Int(currentPrice))\(symbol)").font(.caption2).foregroundColor(.red) }
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
