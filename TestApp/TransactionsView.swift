import SwiftUI
import Charts
import PhotosUI
import Vision

// MARK: - Expenses Screen (Ported directly from mobile repo ExpensesScreen.tsx with native iOS enhancements)
struct TransactionsView: View {
    @ObservedObject var store = AppStore.shared
    
    // Category filter state
    @State private var selectedCategoryId: UUID? = nil
    
    // Add Expense Modal states
    @State private var showingAddModal = false
    @State private var formTitle: String = ""
    @State private var formAmount: String = ""
    @State private var formNote: String = ""
    @State private var formCategoryId: UUID? = nil
    @State private var formReceiptImage: UIImage? = nil
    @State private var selectedReceiptPhotoItem: PhotosPickerItem? = nil
    @State private var isScanningReceipt = false
    
    // Delete Confirmation
    @State private var itemToDelete: TransactionItem? = nil
    @State private var showingDeleteAlert = false
    
    // Filtered Expenses
    var expensesList: [TransactionItem] {
        let allExpenses = store.transactions.filter { $0.type == .expense }
        if let catId = selectedCategoryId {
            return allExpenses.filter { $0.categoryId == catId }
        }
        return allExpenses
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0F172A").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Area
                    screenHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                    
                    // Category Filter Bar (Horizontal Chips)
                    categoryFilterBar
                        .padding(.bottom, 12)
                    
                    // Expense Content List
                    if expensesList.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(expensesList) { item in
                                    expenseCard(item)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("Harcamayı Sil", isPresented: $showingDeleteAlert, presenting: itemToDelete) { item in
                Button("Vazgeç", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    store.deleteTransaction(id: item.id)
                }
            } message: { item in
                Text("\"\(item.title)\" harcamasını silmek istediğinize emin misiniz?")
            }
            .sheet(isPresented: $showingAddModal) {
                addExpenseModalView
            }
        }
    }
    
    // MARK: - Header
    private var screenHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TÜM KAYITLAR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .tracking(1)
                
                Text("Harcamalar 💸")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color(hex: "#F8FAFC"))
            }
            
            Spacer()
            
            Button {
                Haptic.medium()
                prepareForm()
                showingAddModal = true
            } label: {
                Text("+ Yeni Ekle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color(hex: "#3B82F6"))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "Tümü" Chip
                Button {
                    Haptic.light()
                    selectedCategoryId = nil
                } label: {
                    Text("Tümü")
                        .font(.system(size: 12, weight: selectedCategoryId == nil ? .bold : .normal))
                        .foregroundColor(selectedCategoryId == nil ? .white : Color(hex: "#94A3B8"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedCategoryId == nil ? Color(hex: "#3B82F6") : Color(hex: "#1E293B"))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedCategoryId == nil ? Color(hex: "#3B82F6") : Color(hex: "#334155"), lineWidth: 1)
                        )
                }
                
                // Categories Chips
                ForEach(store.categories.filter { $0.type == .expense }) { cat in
                    let isSelected = selectedCategoryId == cat.id
                    Button {
                        Haptic.light()
                        selectedCategoryId = isSelected ? nil : cat.id
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: cat.colorHex))
                                .frame(width: 7, height: 7)
                            Text(cat.name)
                        }
                        .font(.system(size: 12, weight: isSelected ? .bold : .normal))
                        .foregroundColor(isSelected ? .white : Color(hex: "#94A3B8"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color(hex: "#3B82F6") : Color(hex: "#1E293B"))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color(hex: "#3B82F6") : Color(hex: "#334155"), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Expense Card (Exact match with mobile repo style)
    private func expenseCard(_ item: TransactionItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Category Vertical Indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: item.categoryColorHex))
                .frame(width: 4, height: 46)
            
            // Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#F8FAFC"))
                    
                    if item.receiptUrl != nil {
                        Text("📸 Fişli")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#10B981"))
                    }
                }
                
                HStack(spacing: 6) {
                    Text(item.categoryName)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#94A3B8"))
                    
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#64748B"))
                    
                    Text(item.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#64748B"))
                }
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11).italic())
                        .foregroundColor(Color(hex: "#64748B"))
                }
            }
            
            Spacer()
            
            // Amount and Delete Action
            VStack(alignment: .trailing, spacing: 4) {
                Text("-₺\(item.amount.formatted(.number.precision(.fractionLength(2))))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#EF4444"))
                
                Button {
                    Haptic.medium()
                    itemToDelete = item
                    showingDeleteAlert = true
                } label: {
                    Text("Sil")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#64748B"))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#1E293B"))
        .cornerRadius(14)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray.fill")
                .font(.system(size: 42))
                .foregroundColor(Color(hex: "#334155"))
            Text("Harcama Bulunamadı")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#94A3B8"))
            Text("Yeni harcama ekleyerek takip etmeye başlayın.")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#64748B"))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    // MARK: - Add Expense Modal (Exact port with receipt photo picking & OCR)
    private var addExpenseModalView: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0F172A").ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // Title Input
                        Text("Başlık / Açıklama")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#94A3B8"))
                        
                        TextField("Örn: Akşam Yemeği, Kahve, Benzin", text: $formTitle)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#1E293B"))
                            .foregroundColor(Color(hex: "#F8FAFC"))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#334155"), lineWidth: 1))
                        
                        // Amount Input
                        Text("Tutar (₺)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#94A3B8"))
                        
                        TextField("0.00", text: $formAmount)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#1E293B"))
                            .foregroundColor(Color(hex: "#F8FAFC"))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#334155"), lineWidth: 1))
                        
                        // Category Selection
                        Text("Kategori")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#94A3B8"))
                        
                        let cats = store.categories.filter { $0.type == .expense }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(cats) { c in
                                let isSelected = formCategoryId == c.id
                                Button {
                                    Haptic.light()
                                    formCategoryId = c.id
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color(hex: c.colorHex))
                                            .frame(width: 8, height: 8)
                                        Text(c.name)
                                            .font(.system(size: 12, weight: isSelected ? .bold : .normal))
                                            .foregroundColor(isSelected ? Color(hex: "#F8FAFC") : Color(hex: "#94A3B8"))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? Color(hex: "#1E293B") : Color(hex: "#1E293B"))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? Color(hex: c.colorHex) : Color(hex: "#334155"), lineWidth: isSelected ? 1.5 : 1)
                                    )
                                }
                            }
                        }
                        
                        // 📸 Receipt / Fiş Fotoğrafı Seçme & OCR
                        PhotosPicker(selection: $selectedReceiptPhotoItem, matching: .images) {
                            HStack(spacing: 8) {
                                if isScanningReceipt {
                                    ProgressView().tint(Color(hex: "#38BDF8"))
                                } else {
                                    Image(systemName: formReceiptImage != nil ? "checkmark.circle.fill" : "camera.viewfinder")
                                        .foregroundColor(formReceiptImage != nil ? Color(hex: "#10B981") : Color(hex: "#38BDF8"))
                                }
                                
                                Text(formReceiptImage != nil ? "✅ Fiş Eklendi (Değiştir)" : "📸 Fiş / Fatura Fotoğrafı Ekle (OCR)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#38BDF8"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#1E293B"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundColor(Color(hex: "#475569"))
                            )
                        }
                        .onChange(of: selectedReceiptPhotoItem) { item in
                            Task {
                                guard let item = item,
                                      let data = try? await item.loadTransferable(type: Data.self),
                                      let uiImage = UIImage(data: data) else { return }
                                
                                await MainActor.run {
                                    formReceiptImage = uiImage
                                    isScanningReceipt = true
                                }
                                
                                // Perform OCR to automatically parse total amount or title from receipt
                                performReceiptOCR(uiImage)
                            }
                        }
                        
                        // Note Input
                        Text("Not (İsteğe bağlı)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#94A3B8"))
                        
                        TextField("Eklemek istediğiniz bir detay...", text: $formNote)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#1E293B"))
                            .foregroundColor(Color(hex: "#F8FAFC"))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#334155"), lineWidth: 1))
                        
                        // Save Button
                        Button {
                            handleSaveExpense()
                        } label: {
                            Text("Kaydet")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "#3B82F6"))
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Yeni Harcama Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        showingAddModal = false
                    }
                    .foregroundColor(Color(hex: "#94A3B8"))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func prepareForm() {
        formTitle = ""
        formAmount = ""
        formNote = ""
        formReceiptImage = nil
        selectedReceiptPhotoItem = nil
        if let firstCat = store.categories.first(where: { $0.type == .expense }) {
            formCategoryId = firstCat.id
        }
    }
    
    private func handleSaveExpense() {
        let cleanAmount = formAmount.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(cleanAmount), amount > 0, !formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Haptic.warning()
            return
        }
        
        let selectedCat = store.categories.first(where: { $0.id == formCategoryId }) ?? store.categories.first(where: { $0.type == .expense })
        
        let newExpense = TransactionItem(
            categoryId: selectedCat?.id,
            categoryName: selectedCat?.name ?? "Genel",
            categoryIcon: selectedCat?.iconSymbol ?? "cart.fill",
            categoryColorHex: selectedCat?.colorHex ?? "#3B82F6",
            amount: amount,
            type: .expense,
            title: formTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            note: formNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : formNote.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptUrl: formReceiptImage != nil ? "local_receipt_\(UUID().uuidString)" : nil,
            date: Date()
        )
        
        store.addTransaction(newExpense)
        showingAddModal = false
    }
    
    private func performReceiptOCR(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            isScanningReceipt = false
            return
        }
        
        let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else {
                Task { @MainActor in isScanningReceipt = false }
                return
            }
            
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            
            Task { @MainActor in
                isScanningReceipt = false
                Haptic.success()
                
                if formTitle.isEmpty {
                    formTitle = "Fiş Harcaması"
                }
                
                // Search for total amount keyword (TOPLAM, TUTAR, TOTAL, ₺)
                for line in lines {
                    let upper = line.uppercased()
                    if upper.contains("TOPLAM") || upper.contains("TUTAR") || upper.contains("TOTAL") {
                        let digitsOnly = line.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted).filter { !$0.isEmpty }
                        if let lastVal = digitsOnly.last {
                            let cleanVal = lastVal.replacingOccurrences(of: ",", with: ".")
                            if let num = Double(cleanVal), num > 0 {
                                if formAmount.isEmpty {
                                    formAmount = String(format: "%.2f", num)
                                }
                                break
                            }
                        }
                    }
                }
            }
        }
        
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}
