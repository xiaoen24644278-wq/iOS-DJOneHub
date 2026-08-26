import SwiftUI

// MARK: - 电话主视图
struct PhoneView: View {
    @StateObject var viewModel: PhoneViewModel
    @State private var showingDialPad = true
    
    var body: some View {
        ZStack {
            // 通话中全屏界面
            if viewModel.isInCall {
                ActiveCallView(viewModel: viewModel)
                    .transition(.move(edge: .bottom))
            } else {
                // 正常界面
                VStack(spacing: 0) {
                    // 顶部切换
                    Picker("电话", selection: $showingDialPad) {
                        Text("拨号").tag(true)
                        Text("通话记录").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    if showingDialPad {
                        DialPadView(viewModel: viewModel)
                    } else {
                        CallHistoryView(viewModel: viewModel)
                    }
                }
                .navigationTitle("电话")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .animation(.easeInOut, value: viewModel.isInCall)
    }
}

// MARK: - 拨号盘视图
struct DialPadView: View {
    @StateObject var viewModel: PhoneViewModel
    
    private let dialKeys: [DialKey] = [
        DialKey(digit: "1", letters: ""),
        DialKey(digit: "2", letters: "ABC"),
        DialKey(digit: "3", letters: "DEF"),
        DialKey(digit: "4", letters: "GHI"),
        DialKey(digit: "5", letters: "JKL"),
        DialKey(digit: "6", letters: "MNO"),
        DialKey(digit: "7", letters: "PQRS"),
        DialKey(digit: "8", letters: "TUV"),
        DialKey(digit: "9", letters: "WXYZ"),
        DialKey(digit: "*", letters: ""),
        DialKey(digit: "0", letters: "+"),
        DialKey(digit: "#", letters: "")
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // 号码显示
            Text(viewModel.dialedNumber.isEmpty ? "输入号码" : viewModel.dialedNumber.formattedPhoneNumber)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(viewModel.dialedNumber.isEmpty ? .secondary : .primary)
                .frame(height: 60)
                .padding(.top, 20)
            
            // 拨号键盘
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(dialKeys) { key in
                    DialKeyButton(key: key) {
                        viewModel.appendDigit(key.digit)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // 底部操作按钮
            HStack(spacing: 40) {
                // 删除按钮
                Button {
                    viewModel.deleteLastDigit()
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                        .frame(width: 50, height: 50)
                }
                .disabled(viewModel.dialedNumber.isEmpty)
                
                // 拨号按钮
                Button {
                    viewModel.call()
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .disabled(viewModel.dialedNumber.isEmpty)
                .opacity(viewModel.dialedNumber.isEmpty ? 0.5 : 1.0)
                
                // 清空按钮
                Button {
                    viewModel.clearDialedNumber()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 50, height: 50)
                }
                .disabled(viewModel.dialedNumber.isEmpty)
            }
            .padding(.bottom, 20)
            
            Spacer()
        }
    }
}

// MARK: - 拨号键数据
struct DialKey: Identifiable {
    let id = UUID()
    let digit: String
    let letters: String
}

// MARK: - 拨号键按钮
struct DialKeyButton: View {
    let key: DialKey
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(key.digit)
                    .font(.system(size: 28, weight: .regular))
                if !key.letters.isEmpty {
                    Text(key.letters)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            .background(Color(.secondarySystemBackground))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 通话记录视图
struct CallHistoryView: View {
    @StateObject var viewModel: PhoneViewModel
    
    var body: some View {
        List {
            if viewModel.callRecords.isEmpty {
                ContentUnavailableView(
                    "暂无通话记录",
                    systemImage: "phone.arrow.up.right",
                    description: Text("拨打或接听电话后，记录将显示在这里")
                )
            } else {
                ForEach(viewModel.callRecords) { record in
                    CallRecordRow(record: record, viewModel: viewModel)
                }
                .onDelete(perform: deleteRecords)
            }
        }
        .listStyle(.plain)
        .refreshable {
            // 刷新通话记录（从本地加载）
        }
        .toolbar(id: "phoneview") {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        viewModel.clearCallRecords()
                    } label: {
                        Label("清空记录", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteCallRecord(viewModel.callRecords[index])
        }
    }
}

// MARK: - 通话记录行
struct CallRecordRow: View {
    let record: CallRecord
    @StateObject var viewModel: PhoneViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: callIcon)
                .foregroundColor(callColor)
                .frame(width: 30)
            
            // 号码/姓名
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.contactName(for: record.phoneNumber))
                    .font(.system(size: 16, weight: .medium))
                Text(record.timestamp.relativeDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 时长
            if record.callType != .missed && record.duration > 0 {
                Text(record.durationString)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            // 回拨按钮
            Button {
                viewModel.callNumber(record.phoneNumber)
            } label: {
                Image(systemName: "phone.fill")
                    .foregroundColor(.green)
                    .frame(width: 36, height: 36)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
    }
    
    private var callIcon: String {
        switch record.callType {
        case .incoming: return "phone.arrow.down.left"
        case .outgoing: return "phone.arrow.up.right"
        case .missed: return "phone.missed"
        }
    }
    
    private var callColor: Color {
        switch record.callType {
        case .incoming: return .blue
        case .outgoing: return .green
        case .missed: return .red
        }
    }
}

// MARK: - 预览
struct PhoneView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PhoneView(viewModel: PhoneViewModel())
        }
    }
}
