import SwiftUI
import Charts

// --- STRUCTURES DE DONNÉES ---

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
    case gordon = "Conservateur (Perpétuel)"
    case multiples = "Marché (Multiples)"
    var id: Self { self }
}

struct ProjectionPoint: Identifiable {
    let id = UUID()
    let year: Int
    let value: Double
}

// --- VUE PRINCIPALE ---

struct ContentView: View {
    // --- ÉTATS ---
    @State private var ticker: String = "NVDA"
    @State private var priceDisplay: String = "---"
    @State private var isLoading = false
    @State private var currentPrice: Double = 0.0

    // Saisie
    @State private var fcfInput: String = "3.15"
    @State private var sharesInput: String = "24.30"
    @State private var cashInput: String = "11.486"
    @State private var debtInput: String = "10.822"

    // Hypothèses
    @State private var growthRate: Double = 20.0
    @State private var discountRate: Double = 9.0
    
    // Méthode
    @State private var selectedMethod: ValuationMethod = .multiples
    @State private var terminalGrowth: Double = 2.5
    @State private var exitMultiple: Double = 45.0
    
    // Résultats
    @State private var intrinsicValue: Double = 0.0
    @State private var projectionData: [ProjectionPoint] = []

    var body: some View {
        HSplitView {
            // --- COLONNE GAUCHE (Paramètres + Bouton Calculer) ---
            VStack(spacing: 0) {
                // 1. Titre
                Text("Paramètres DCF")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
               
                // 2. Formulaire (Scrollable)
                Form {
                    Section(header: Text("Recherche")) {
                        HStack {
                            TextField("Ticker", text: $ticker).onSubmit { fetchPrice() }
                            Button("Charger") { fetchPrice() }
                        }
                        HStack {
                            Text("Prix actuel du Marché :")
                            Spacer()
                            if isLoading { ProgressView().scaleEffect(0.5) }
                            Text(priceDisplay).bold()
                        }
                    }
                    
                    // --- AJOUT DU LIEN DANS LE FOOTER DE CETTE SECTION ---
                    Section(header: Text("Fondamentaux"), footer: stockAnalysisLink) {
                        inputRowString(label: "FCF / Action", value: $fcfInput, helpText: "Free Cash Flow par action")
                        inputRowString(label: "Nombre d'actions", value: $sharesInput, helpText: "Nombre total d'actions en circulation (en Milliards)")
                        inputRowString(label: "Cash Total", value: $cashInput, helpText: "Cash + Placements à court terme (en Milliards)")
                        inputRowString(label: "Dette Totale", value: $debtInput, helpText: "Dette Totale (en Milliards)")
                    }
                    
                    Section(header: Text("Estimations Voulues")) {
                        
                        inputRowDouble(label: "Croissance FCF", value: $growthRate, suffix: "%",
                                       helpText: "À quelle vitesse le Free Cash Flow va augmenter chaque année pendant 5 ans ?")
                            
                        inputRowDouble(label: "Taux d'Actualisation", value: $discountRate, suffix: "%",
                                       helpText: "Le retour sur investissement annuel que VOUS voulez.\nPlus ce chiffre est haut, plus le prix d'achat doit être bas.")

                        inputRowDouble(label: "Multiple de Sortie", value: $exitMultiple, suffix: "x",
                           helpText: "Dans 5 ans, à quel multiple de ses bénéfices (PER) l'entreprise se revendra-t-elle ?")
                    }
                }
                .formStyle(.grouped)
             
                // 3. LE BOUTON CALCULER
                Divider()
                Button(action: {
                    calculateIntrinsicValue()
                }) {
                    Text("CALCULER")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(minWidth: 320, maxWidth: 400)
            
            // --- COLONNE DROITE (Résultats) ---
            ZStack(alignment: .top) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
             
                ScrollView {
                    VStack(spacing: 30) {
                        
                        // En-tête Chiffres
                        ResultHeaderView(
                            priceDisplay: priceDisplay,
                            intrinsicValue: intrinsicValue,
                            currentPrice: currentPrice
                        )
                        .padding(.top, 40)
                        
                        // Graphique à Barres
                        if currentPrice > 0 && intrinsicValue > 0 {
                            ValuationBarChart(marketPrice: currentPrice, intrinsicValue: intrinsicValue)
                                .frame(height: 180)
                                .padding(.horizontal)
                        }
                        
                        // Graphique Linéaire INTERACTIF
                        if !projectionData.isEmpty && intrinsicValue > 0 {
                            ProjectedGrowthChart(data: projectionData)
                                .padding(.horizontal)
                        }
                        
                        // Matrice de Sensibilité
                        if intrinsicValue > 0 {
                            SensitivityMatrixView(
                                baseGrowth: growthRate,
                                baseDiscount: discountRate,
                                currentPrice: currentPrice,
                                calculate: runSimulation
                            )
                            .padding(.horizontal)
                        }

                        // Marge de sécurité
                        if currentPrice > 0 && intrinsicValue > 0 {
                            let margin = ((intrinsicValue - currentPrice) / intrinsicValue) * 100
                            VStack(spacing: 5) {
                                Text(margin > 0 ? "Sous-évalué de" : "Surévalué de")
                                    .font(.caption).fontWeight(.bold)
                                    .foregroundColor(margin > 0 ? .green : .red)
                                    .textCase(.uppercase)
                             
                                Text(String(format: "%.1f %%", abs(margin)))
                                    .font(.title2).bold()
                                    .foregroundColor(margin > 0 ? .green : .red)
                                    .padding(.horizontal, 15).padding(.vertical, 5)
                                    .background(margin > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .padding(.bottom, 50)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    // --- COMPOSANT LIEN WEB ---
    var stockAnalysisLink: some View {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        // Construit le lien dynamique vers la page Financials
        let urlString = cleanTicker.isEmpty
            ? "https://stockanalysis.com"
            : "https://stockanalysis.com/stocks/\(cleanTicker)/financials/"
        
        return Link(destination: URL(string: urlString)!) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.square")
                Text("Récupérer les données sur StockAnalysis.com")
            }
            .font(.caption)
            .padding(.top, 5)
        }
    }
    
    // --- LOGIQUE CALCUL ---

    func parseDouble(_ input: String) -> Double {
        let clean = input.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(clean) ?? 0.0
    }

    func calculateIntrinsicValue() {
        let fcf = parseDouble(fcfInput)
        let shares = parseDouble(sharesInput)
        let cash = parseDouble(cashInput)
        let debt = parseDouble(debtInput)
        
        let result = computeDCF(
            fcfPerShare: fcf, shares: shares, cash: cash, debt: debt,
            g: growthRate, r: discountRate,
            method: selectedMethod, tg: terminalGrowth, exitMult: exitMultiple
        )
        
        var newProjections: [ProjectionPoint] = []
        let startValue = currentPrice > 0 ? currentPrice : result
        newProjections.append(ProjectionPoint(year: 0, value: startValue))
        var projectedValue = startValue
        
        for i in 1...5 {
            projectedValue = projectedValue * (1 + (growthRate / 100.0))
            newProjections.append(ProjectionPoint(year: i, value: projectedValue))
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            self.intrinsicValue = result
            self.projectionData = newProjections
        }
    }
    
    func runSimulation(g: Double, r: Double) -> Double {
        return computeDCF(
            fcfPerShare: parseDouble(fcfInput),
            shares: parseDouble(sharesInput),
            cash: parseDouble(cashInput),
            debt: parseDouble(debtInput),
            g: g, r: r, method: selectedMethod, tg: terminalGrowth, exitMult: exitMultiple
        )
    }
    
    func computeDCF(fcfPerShare: Double, shares: Double, cash: Double, debt: Double,
                    g: Double, r: Double, method: ValuationMethod, tg: Double, exitMult: Double) -> Double {
        
        let gDec = g / 100.0
        let rDec = r / 100.0
        
        var currentFCF = fcfPerShare
        var sumPV = 0.0
        
        for i in 1...5 {
            currentFCF = currentFCF * (1 + gDec)
            let discountFactor = pow(1 + rDec, Double(i))
            sumPV += (currentFCF / discountFactor)
        }
        
        var terminalValue = 0.0
        if method == .gordon {
            let tgDec = tg / 100.0
            if rDec > tgDec { terminalValue = (currentFCF * (1 + tgDec)) / (rDec - tgDec) }
        } else {
            terminalValue = currentFCF * exitMult
        }
        
        let terminalValuePV = terminalValue / pow(1 + rDec, 5.0)
        let netCashPerShare = (shares > 0) ? (cash - debt) / shares : 0.0
        
        return sumPV + terminalValuePV + netCashPerShare
    }
    
    func fetchPrice() {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").uppercased()
        guard !cleanTicker.isEmpty else { return }
        
        isLoading = true
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(cleanTicker)?interval=1d"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { isLoading = false } }
            guard let data = data else { return }
            if let response = try? JSONDecoder().decode(YahooResponse.self, from: data),
               let result = response.chart.result?.first {
                let price = result.meta.regularMarketPrice ?? result.meta.previousClose ?? 0.0
                let currency = result.meta.currency ?? "USD"
                DispatchQueue.main.async {
                    self.currentPrice = price
                    self.priceDisplay = String(format: "%.2f %@", price, currency)
                }
            }
        }.resume()
    }
    
    // --- UPDATE : HELPERS UI AVEC BOUTON INFO ---
    
    func inputRowString(label: String, value: Binding<String>, helpText: String) -> some View {
        HStack {
            Text(label)
                .help(helpText) // Garde le tooltip natif (délai)
            
            // Nouveau Bouton Info Interactif
            InfoButton(helpText: helpText)
            
            Spacer()
            TextField("0", text: value)
                .textFieldStyle(.roundedBorder).frame(width: 100).multilineTextAlignment(.trailing)
        }
    }
    
    func inputRowDouble(label: String, value: Binding<Double>, suffix: String, helpText: String) -> some View {
        HStack {
            Text(label)
                .help(helpText)
            
            // Nouveau Bouton Info Interactif
            InfoButton(helpText: helpText)
            
            Spacer()
            HStack(spacing: 2) {
                TextField("", value: value, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 60).multilineTextAlignment(.trailing)
                Text(suffix).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// --- NOUVEAU COMPOSANT : BOUTON INFO (POPOVER) ---
struct InfoButton: View {
    let helpText: String
    @State private var showPopover = false
    
    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .contentShape(Rectangle()) // Rend la zone de clic un peu plus confortable
        }
        .buttonStyle(.plain) // Enlève le style bouton classique pour garder juste l'icône
        .popover(isPresented: $showPopover) {
            Text(helpText)
                .padding()
                .frame(width: 250) // Largeur de la bulle d'aide
                .multilineTextAlignment(.leading)
        }
    }
}


// --- AUTRES COMPOSANTS (Inchangés) ---

struct ResultHeaderView: View {
    var priceDisplay: String
    var intrinsicValue: Double
    var currentPrice: Double
    
    var body: some View {
        HStack(spacing: 50) {
            VStack {
                Text("Prix Actuel").font(.headline).foregroundColor(.secondary)
                Text(priceDisplay).font(.system(size: 36, weight: .bold))
            }
            Image(systemName: "arrow.right").font(.largeTitle).opacity(0.3)
            VStack {
                Text("Valeur Intrinsèque").font(.headline).foregroundColor(.secondary)
                Text(String(format: "%.2f $", intrinsicValue))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(intrinsicValue > currentPrice ? .green : .red)
            }
        }
    }
}

struct SensitivityMatrixView: View {
    let baseGrowth: Double
    let baseDiscount: Double
    let currentPrice: Double
    let calculate: (Double, Double) -> Double
    
    var growthSteps: [Double] { [baseGrowth - 2, baseGrowth, baseGrowth + 2] }
    var discountSteps: [Double] { [baseDiscount - 1, baseDiscount, baseDiscount + 1] }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Matrice de Sensibilité")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Taux Act. \\ Croiss.")
                        .font(.caption).foregroundColor(.secondary)
                    ForEach(growthSteps, id: \.self) { g in
                        Text("\(Int(g))%")
                            .font(.headline)
                            .foregroundColor(g == baseGrowth ? .blue : .primary)
                    }
                }
                
                ForEach(discountSteps, id: \.self) { r in
                    GridRow {
                        Text("\(Int(r))%")
                            .font(.headline)
                            .foregroundColor(r == baseDiscount ? .blue : .primary)
                        
                        ForEach(growthSteps, id: \.self) { g in
                            let val = calculate(g, r)
                            let isProfitable = val > currentPrice
                            
                            VStack {
                                Text(String(format: "%.0f $", val))
                                    .fontWeight(.bold)
                                    .foregroundColor(isProfitable ? .green : .red)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isProfitable ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        (r == baseDiscount && g == baseGrowth) ? Color.blue : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

struct ValuationBarChart: View {
    var marketPrice: Double
    var intrinsicValue: Double
    private var maxValue: Double { max(marketPrice, intrinsicValue) * 1.1 }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 60) {
                BarView(value: marketPrice, maxValue: maxValue, label: "Marché", color: Color.gray.opacity(0.4), height: geometry.size.height)
                BarView(value: intrinsicValue, maxValue: maxValue, label: "Valeur", color: intrinsicValue >= marketPrice ? Color.green : Color.red, height: geometry.size.height)
            }
        }
    }
}

struct BarView: View {
    var value: Double; var maxValue: Double; var label: String; var color: Color; var height: CGFloat
    var barHeight: CGFloat { guard maxValue > 0 else { return 0 }; return height * (value / maxValue) }
    
    var body: some View {
        VStack {
            Text("\(Int(value)) $").font(.headline).foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 8).fill(color.gradient).frame(height: barHeight)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: value)
            Text(label).font(.subheadline).fontWeight(.bold).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProjectedGrowthChart: View {
    var data: [ProjectionPoint]
    
    @State private var selectedYear: Int?
    
    var isPositiveGrowth: Bool {
        guard let first = data.first, let last = data.last else { return true }
        return last.value >= first.value
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Projection du prix (Impliquée par la croissance)")
                .font(.headline).foregroundColor(.secondary)
            
            Chart(data) { point in
                LineMark(x: .value("Année", point.year), y: .value("Valeur", point.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(isPositiveGrowth ? Color.green.gradient : Color.red.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(x: .value("Année", point.year), yStart: .value("Base", data.first?.value ?? 0), yEnd: .value("Valeur", point.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(isPositiveGrowth ? Color.green.opacity(0.1).gradient : Color.red.opacity(0.1).gradient)
                
                if let selectedYear, selectedYear == point.year {
                    RuleMark(x: .value("Année", selectedYear))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            VStack(spacing: 2) {
                                Text("Année \(point.year)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(point.value)) $")
                                    .font(.body)
                                    .bold()
                                    .foregroundColor(.primary)
                            }
                            .padding(6)
                            .background(.regularMaterial)
                            .cornerRadius(6)
                            .shadow(radius: 2)
                        }
                    
                    PointMark(x: .value("Année", point.year), y: .value("Valeur", point.value))
                        .foregroundStyle(Color.primary)
                }
            }
            .chartXSelection(value: $selectedYear)
            .chartXScale(domain: 0...5)
            .frame(height: 150)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}
