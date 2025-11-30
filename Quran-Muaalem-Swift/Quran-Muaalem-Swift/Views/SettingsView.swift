//
//  SettingsView.swift
//  Quran-Muaalem-Swift
//
//  Created by Tarek Mansour on 11/29/25.
//

import SwiftUI

struct SettingsView: View {
    
    @AppStorage("rewaya") private var rewaya = "hafs"
    @AppStorage("madd_monfasel_len") private var maddMonfaselLen = 2
    @AppStorage("madd_mottasel_len") private var maddMottaselLen = 4
    @AppStorage("madd_mottasel_waqf") private var maddMottaselWaqf = 4
    @AppStorage("madd_aared_len") private var maddAaredLen = 2
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Rewaya Section
                Section {
                    Picker("الرواية", selection: $rewaya) {
                        Text("حفص").tag("hafs")
                        Text("ورش").tag("warsh")
                        Text("قالون").tag("qaloon")
                    }
                } header: {
                    Text("الرواية")
                } footer: {
                    Text("اختر رواية القراءة المستخدمة")
                }
                
                // Madd Settings Section
                Section {
                    // Madd Monfasel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("مد منفصل")
                            Spacer()
                            Text("\(maddMonfaselLen) حركات")
                                .foregroundStyle(.secondary)
                        }
                        
                        Picker("مد منفصل", selection: $maddMonfaselLen) {
                            ForEach(2...6, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("مثال: وَمَآ أَنزَلْنَا")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // Madd Mottasel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("مد متصل")
                            Spacer()
                            Text("\(maddMottaselLen) حركات")
                                .foregroundStyle(.secondary)
                        }
                        
                        Picker("مد متصل", selection: $maddMottaselLen) {
                            ForEach(4...6, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("مثال: جَآءَ، سُوٓءُ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // Madd Mottasel Waqf
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("مد متصل (وقف)")
                            Spacer()
                            Text("\(maddMottaselWaqf) حركات")
                                .foregroundStyle(.secondary)
                        }
                        
                        Picker("مد متصل وقف", selection: $maddMottaselWaqf) {
                            ForEach(4...6, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("المد المتصل عند الوقف")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    // Madd Aared
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("مد عارض للسكون")
                            Spacer()
                            Text("\(maddAaredLen) حركات")
                                .foregroundStyle(.secondary)
                        }
                        
                        Picker("مد عارض", selection: $maddAaredLen) {
                            ForEach(2...6, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text("مثال: نَسْتَعِينْ، الرَّحِيمْ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                } header: {
                    Label("إعدادات المد", systemImage: "waveform.path")
                } footer: {
                    Text("اضبط أطوال المد حسب طريقة القراءة التي تتبعها. القيم الافتراضية مناسبة لأغلب القراء.")
                }
                
                // Reset Section
                Section {
                    Button(action: resetToDefaults) {
                        Label("إعادة الضبط للافتراضي", systemImage: "arrow.counterclockwise")
                    }
                    .foregroundStyle(.red)
                }
                
                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(title: "المد المنفصل", description: "حرف مد في آخر كلمة وهمزة في أول الكلمة التالية")
                        Divider()
                        InfoRow(title: "المد المتصل", description: "حرف مد وبعده همزة في نفس الكلمة")
                        Divider()
                        InfoRow(title: "المد العارض", description: "حرف مد وبعده حرف ساكن سكونًا عارضًا للوقف")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("معلومات عن المد", systemImage: "info.circle")
                }
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func resetToDefaults() {
        rewaya = "hafs"
        maddMonfaselLen = 2
        maddMottaselLen = 4
        maddMottaselWaqf = 4
        maddAaredLen = 2
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
}

