import SwiftUI
import Charts

// --- STRUCTURES DE DONNÉES (Inchangées) ---

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

    // UI States
    @State private var isSidebarVisible: Bool = true // Pour replier la sidebar

    // Saisie
    @State private var fcfInput: String = "0.00"
    @State private var sharesInput: String = "0.00"
    @State private var cashInput: String = "0.00"
    @State private var debtInput: String = "0.00"

    // Hypothèses
    @State private var growthRate: Double = 0.0
    @State private var discountRate: Double = 0.0
    
    // Méthode
    @State private var selectedMethod: ValuationMethod = .multiples
    @State private var terminalGrowth: Double = 0.0
    @State private var exitMultiple: Double = 0.0
    
    // Résultats
    @State private var intrinsicValue: Double = 0.0
    @State private var projectionData: [ProjectionPoint] = []

    var body: some View {
        HStack(spacing: 0) {
            
            // --- COLONNE GAUCHE (Paramètres) - REPLIABLE ---
            if isSidebarVisible {
                VStack(spacing: 0) {
                    // 1. Titre + BOUTON FERMETURE
                    HStack {
                        Text("Paramètres DCF")
                            .font(.headline)
                        
                        Spacer()
                        
                        // Bouton pour fermer la sidebar (DÉPLACÉ ICI)
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isSidebarVisible = false
                            }
                        }) {
                            Image(systemName: "sidebar.left")
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        .help("Masquer la barre latérale")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    
                    // 2. Formulaire
                    Form {
                        Section(header: Text("Recherche")) {
                            HStack {
                                TextField("Ticker", text: $ticker).onSubmit { fetchPrice() }
                                Button("Charger") { fetchPrice() }
                            }
                            HStack {
                                Text("Prix actuel :")
                                Spacer()
                                if isLoading { ProgressView().scaleEffect(0.5) }
                                Text(priceDisplay).bold()
                            }
                        }
                        
                        Section(header: Text("Fondamentaux"), footer: stockAnalysisLink) {
                            inputRowString(label: "FCF / Action", value: $fcfInput, helpText: "Free Cash Flow par action")
                            inputRowString(label: "Nb Actions (B)", value: $sharesInput, helpText: "Nombre total d'actions (Milliards)")
                            inputRowString(label: "Cash (B)", value: $cashInput, helpText: "Cash total")
                            inputRowString(label: "Dette (B)", value: $debtInput, helpText: "Dette totale")
                        }
                        
                        Section(header: Text("Estimations")) {
                            inputRowDouble(label: "Croissance FCF", value: $growthRate, suffix: "%", helpText: "Croissance annuelle estimée sur 5 ans")
                            inputRowDouble(label: "Taux Actualisation", value: $discountRate, suffix: "%", helpText: "Votre retour sur investissement souhaité")
                            inputRowDouble(label: "Multiple Sortie", value: $exitMultiple, suffix: "x", helpText: "PER attendu à la revente dans 5 ans")
                        }
                    }
                    .formStyle(.grouped)
                  
                    // 3. Bouton Calculer
                    Divider()
                    Button(action: { calculateIntrinsicValue() }) {
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
                .frame(width: 320) // Largeur fixe pour la sidebar
                .transition(.move(edge: .leading)) // Animation de glissement
            }
            
            // Séparateur visuel (si sidebar ouverte)
            if isSidebarVisible {
                Divider()
            }
            
            // --- COLONNE DROITE (Résultats) ---
            ZStack(alignment: .topLeading) {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
              
                ScrollView {
                    VStack(spacing: 30) {
                       
                        // Header avec résultats + Badge Marge de sécurité intégré
                        ResultHeaderView(
                            priceDisplay: priceDisplay,
                            intrinsicValue: intrinsicValue,
                            currentPrice: currentPrice
                        )
                        .padding(.top, 40)
                       
                        // Bar Chart
                        if currentPrice > 0 && intrinsicValue > 0 {
                            ValuationBarChart(marketPrice: currentPrice, intrinsicValue: intrinsicValue)
                                .frame(height: 180)
                                .padding(.horizontal)
                        }
                       
                        // Line Chart Pro
                        if !projectionData.isEmpty && intrinsicValue > 0 {
                            ProjectedGrowthChart(data: projectionData, currentPrice: currentPrice)
                                .padding(.horizontal)
                        }
                       
                        // Matrice Heatmap 5x5
                        if intrinsicValue > 0 {
                            SensitivityMatrixView(
                                baseGrowth: growthRate,
                                baseDiscount: discountRate,
                                currentPrice: currentPrice,
                                calculate: runSimulation
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 50)
                        }
                    }
                    .frame(maxWidth: .infinity) // Prend toute la largeur dispo
                    .padding(.horizontal, 20)
                }
                
                // BOUTON OUVERTURE SIDEBAR (Visible SEULEMENT si sidebar fermée)
                if !isSidebarVisible {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isSidebarVisible = true
                        }
                    }) {
                        Image(systemName: "sidebar.right") // Icône pour rouvrir
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                    }
                    .padding()
                    .buttonStyle(.plain)
                    .help("Afficher les paramètres")
                }
            }
        }
    }
    
    // --- HELPERS & LOGIQUE ---
    
    var stockAnalysisLink: some View {
        let cleanTicker = ticker.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = cleanTicker.isEmpty ? "https://stockanalysis.com" : "https://stockanalysis.com/stocks/\(cleanTicker)/financials/"
        return Link(destination: URL(string: urlString)!) {
            HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("Données StockAnalysis") }.font(.caption).padding(.top, 5)
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
        }
    }
    
    func runSimulation(g: Double, r: Double) -> Double {
        return computeDCF(
            fcfPerShare: parseDouble(fcfInput), shares: parseDouble(sharesInput), cash: parseDouble(cashInput), debt: parseDouble(debtInput),
            g: g, r: r, method: selectedMethod, tg: terminalGrowth, exitMult: exitMultiple
        )
    }
    
    func computeDCF(fcfPerShare: Double, shares: Double, cash: Double, debt: Double, g: Double, r: Double, method: ValuationMethod, tg: Double, exitMult: Double) -> Double {
        let gDec = g / 100.0; let rDec = r / 100.0
        var currentFCF = fcfPerShare; var sumPV = 0.0
        for i in 1...5 {
            currentFCF = currentFCF * (1 + gDec)
            sumPV += (currentFCF / pow(1 + rDec, Double(i)))
        }
        let terminalValue = method == .gordon ? (currentFCF * (1 + tg/100.0)) / (rDec - tg/100.0) : currentFCF * exitMult
        let netCashPerShare = shares > 0 ? (cash - debt) / shares : 0.0
        return sumPV + (terminalValue / pow(1 + rDec, 5.0)) + netCashPerShare
    }
    
    func fetchPrice() {
        let clean = ticker.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").uppercased()
        guard !clean.isEmpty, let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(clean)?interval=1d") else { return }
        isLoading = true
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer { DispatchQueue.main.async { isLoading = false } }
            if let data = data, let resp = try? JSONDecoder().decode(YahooResponse.self, from: data), let res = resp.chart.result?.first {
                let p = res.meta.regularMarketPrice ?? res.meta.previousClose ?? 0.0
                DispatchQueue.main.async { self.currentPrice = p; self.priceDisplay = String(format: "%.2f %@", p, res.meta.currency ?? "USD") }
            }
        }.resume()
    }
    
    // --- HELPERS UI : CORRECTION LARGEUR TEXTFIELD ---
    
    func inputRowString(label: String, value: Binding<String>, helpText: String) -> some View {
        HStack {
            Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8)
            InfoButton(helpText: helpText)
            Spacer()
            // LARGEUR AUGMENTÉE DE 80 à 100
            TextField("0", text: value)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)
                .multilineTextAlignment(.trailing)
        }
    }
    
    func inputRowDouble(label: String, value: Binding<Double>, suffix: String, helpText: String) -> some View {
        HStack {
            Text(label).help(helpText).lineLimit(1).minimumScaleFactor(0.8)
            InfoButton(helpText: helpText)
            Spacer()
            HStack(spacing: 2) {
                // LARGEUR AUGMENTÉE DE 60 à 80
                TextField("", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                Text(suffix).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// --- BOUTON INFO ---
struct InfoButton: View {
    let helpText: String
    @State private var showPopover = false
    var body: some View {
        Button(action: { showPopover.toggle() }) { Image(systemName: "info.circle").foregroundColor(.secondary) }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) { Text(helpText).padding().frame(width: 250).multilineTextAlignment(.leading) }
    }
}


// --- 1. HEADER IMPROVED (Avec Badge intégré) ---

struct ResultHeaderView: View {
    var priceDisplay: String
    var intrinsicValue: Double
    var currentPrice: Double
    
    var body: some View {
        VStack(spacing: 15) {
            // Ligne des Prix
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
            
            // Badge "Sous-évalué / Surévalué" intégré proprement
            if currentPrice > 0 && intrinsicValue > 0 {
                let margin = ((intrinsicValue - currentPrice) / intrinsicValue) * 100
                HStack(spacing: 8) {
                    Image(systemName: margin > 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    Text(margin > 0 ? "Sous-évalué de" : "Surévalué de")
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                    Text(String(format: "%.1f %%", abs(margin)))
                        .fontWeight(.black)
                }
                .font(.callout)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(margin > 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .foregroundColor(margin > 0 ? .green : .red)
                .cornerRadius(20) // Forme de pilule
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(margin > 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// --- 2. MATRICE HEATMAP 5x5 ---

struct SensitivityMatrixView: View {
    let baseGrowth: Double
    let baseDiscount: Double
    let currentPrice: Double
    let calculate: (Double, Double) -> Double
    
    // 5 Étapes : -2%, -1%, Base, +1%, +2%
    var growthSteps: [Double] { [baseGrowth - 2, baseGrowth - 1, baseGrowth, baseGrowth + 1, baseGrowth + 2] }
    var discountSteps: [Double] { [baseDiscount - 1, baseDiscount - 0.5, baseDiscount, baseDiscount + 0.5, baseDiscount + 1] }
    
    // Fonction pour générer la couleur (Heatmap)
    func getColor(value: Double) -> Color {
        guard currentPrice > 0 else { return .gray.opacity(0.1) }
        let diff = (value - currentPrice) / currentPrice
        
        if diff > 0 {
            // Vert : Plus c'est haut, plus c'est foncé (max à +40%)
            let intensity = min(diff * 2.5, 0.6) + 0.05
            return Color.green.opacity(intensity)
        } else {
            // Rouge : Plus c'est bas, plus c'est foncé
            let intensity = min(abs(diff) * 2.5, 0.6) + 0.05
            return Color.red.opacity(intensity)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Matrice de Sensibilité (Heatmap)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Grid(horizontalSpacing: 5, verticalSpacing: 5) {
                // En-tête Colonnes (Croissance)
                GridRow {
                    Text("Taux Act. \\ Croiss.")
                        .font(.caption2).foregroundColor(.secondary).frame(width: 80, alignment: .leading)
                    ForEach(growthSteps, id: \.self) { g in
                        Text("\(String(format: "%.1f", g))%")
                            .font(.caption).bold()
                            .foregroundColor(g == baseGrowth ? .blue : .primary)
                    }
                }
                
                // Lignes (Taux d'actualisation)
                ForEach(discountSteps, id: \.self) { r in
                    GridRow {
                        Text("\(String(format: "%.1f", r))%")
                            .font(.caption).bold()
                            .foregroundColor(r == baseDiscount ? .blue : .primary)
                            .frame(width: 80, alignment: .leading)
                        
                        ForEach(growthSteps, id: \.self) { g in
                            let val = calculate(g, r)
                            
                            Text(String(format: "%.0f", val))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary) // Texte toujours lisible
                                .frame(maxWidth: .infinity, minHeight: 35)
                                .background(getColor(value: val)) // Couleur de fond dynamique
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            (r == baseDiscount && g == baseGrowth) ? Color.blue : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// --- AUTRES CHARTS ---

struct ValuationBarChart: View {
    var marketPrice: Double; var intrinsicValue: Double
    private var maxValue: Double { max(marketPrice, intrinsicValue) * 1.1 }
    var body: some View {
        GeometryReader { g in
            HStack(alignment: .bottom, spacing: 60) {
                BarView(value: marketPrice, maxValue: maxValue, label: "Marché", color: .gray.opacity(0.4), height: g.size.height)
                BarView(value: intrinsicValue, maxValue: maxValue, label: "Valeur", color: intrinsicValue >= marketPrice ? .green : .red, height: g.size.height)
            }
        }
    }
}
struct BarView: View {
    var value: Double; var maxValue: Double; var label: String; var color: Color; var height: CGFloat
    var body: some View {
        VStack {
            Text("\(Int(value)) $").font(.headline).foregroundColor(.secondary)
            RoundedRectangle(cornerRadius: 8).fill(color.gradient).frame(height: maxValue > 0 ? height * (value / maxValue) : 0)
                .animation(.spring, value: value)
            Text(label).font(.subheadline).fontWeight(.bold).foregroundColor(.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct ProjectedGrowthChart: View {
    var data: [ProjectionPoint]; var currentPrice: Double
    @State private var selectedYear: Int?
    var yDomain: ClosedRange<Double> {
        let all = data.map { $0.value } + [currentPrice]
        return ((all.min() ?? 0) * 0.9)...((all.max() ?? 100) * 1.1)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Projection Valeur vs Prix").font(.headline).foregroundColor(.secondary)
                HStack(spacing: 15) {
                    HStack(spacing: 5) { Image(systemName: "circle.fill").foregroundColor(.blue).font(.caption); Text("Valeur Intrinsèque").font(.caption).bold() }
                    HStack(spacing: 5) { Image(systemName: "line.horizontal.3").foregroundColor(.red).font(.caption); Text("Prix Actuel").font(.caption).bold() }
                }
            }
            Chart {
                RuleMark(y: .value("Prix", currentPrice)).foregroundStyle(.red).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .annotation(position: .top, alignment: .leading) { Text("Prix: \(Int(currentPrice))$").font(.caption2).foregroundColor(.red) }
                ForEach(data) { point in
                    LineMark(x: .value("Année", point.year), y: .value("Valeur", point.value)).foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 3)).interpolationMethod(.monotone)
                    PointMark(x: .value("Année", point.year), y: .value("Valeur", point.value)).foregroundStyle(.blue).symbolSize(60)
                }
                if let selectedYear {
                    RuleMark(x: .value("Année", selectedYear)).foregroundStyle(Color.gray.opacity(0.3))
                        .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                            if let point = data.first(where: { $0.year == selectedYear }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Année \(point.year)").font(.caption).bold().foregroundColor(.secondary)
                                    Text("Valeur: \(Int(point.value)) $").font(.caption).bold().foregroundColor(.blue)
                                }.padding(6).background(.regularMaterial).cornerRadius(6).shadow(radius: 2)
                            }
                        }
                }
            }
            .chartYScale(domain: yDomain).chartXSelection(value: $selectedYear).chartXScale(domain: 0...5).frame(height: 250)
        }.padding().background(Color(nsColor: .controlBackgroundColor)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
    }
}
