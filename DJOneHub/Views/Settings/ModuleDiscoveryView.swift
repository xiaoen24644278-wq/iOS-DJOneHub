import SwiftUI

// MARK: - 模块发现与配置视图
struct ModuleDiscoveryView: View {
    @StateObject private var networkManager = NetworkCommunicationManager.shared
    @State private var manualIP = ""
    @State private var manualPort = "80"
    @State private var isConnecting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        List {
            // 当前连接状态
            Section {
                HStack {
                    Image(systemName: networkManager.isConnected ? "link.circle.fill" : "link.slash")
                        .foregroundColor(networkManager.isConnected ? .green : .gray)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(networkManager.isConnected ? "已连接到模块" : "未连接到模块")
                            .font(.headline)
                        
                        if let ip = networkManager.moduleIP, networkManager.isConnected {
                            Text("IP: \(ip):\(networkManager.modulePort)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if networkManager.isConnected {
                        Button("断开") {
                            networkManager.disconnect()
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("连接状态")
            }
            
            // 自动扫描
            Section {
                Button {
                    Task {
                        await networkManager.scanForModules()
                    }
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("扫描发现模块")
                        Spacer()
                        if networkManager.isScanning {
                            ProgressView()
                        }
                    }
                }
                .disabled(networkManager.isScanning)
                
                if !networkManager.discoveredModules.isEmpty {
                    ForEach(networkManager.discoveredModules) { module in
                        Button {
                            connectToModule(ip: module.ip, port: module.port)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(module.name)
                                        .font(.headline)
                                    Text("\(module.ip):\(module.port)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("自动发现")
            } footer: {
                Text("确保模块已通过 USB 连接到 iPad，并且 ECM 网络已启用")
            }
            
            // 手动配置
            Section {
                HStack {
                    Text("IP 地址")
                    TextField("192.168.225.1", text: $manualIP)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numbersAndPunctuation)
                }
                
                HStack {
                    Text("端口")
                    TextField("80", text: $manualPort)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                
                Button {
                    guard let port = Int(manualPort), !manualIP.isEmpty else {
                        alertMessage = "请输入有效的 IP 地址和端口"
                        showAlert = true
                        return
                    }
                    connectToModule(ip: manualIP, port: port)
                } label: {
                    HStack {
                        Spacer()
                        if isConnecting {
                            ProgressView()
                        } else {
                            Text("连接")
                        }
                        Spacer()
                    }
                }
                .disabled(isConnecting || manualIP.isEmpty)
            } header: {
                Text("手动配置")
            } footer: {
                Text("常见的模块 IP：192.168.225.1、192.168.42.129")
            }
            
            // 通信说明
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("通过 USB ECM 网络通信", systemImage: "network")
                    Text("本应用通过模块侧的 AT/HTTP 桥接服务与模块通信，不使用 MFi 认证。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Label("支持的功能", systemImage: "checkmark.circle")
                    Text("• 模块状态查询\n• AT 指令控制\n• 短信收发\n• GPS 定位\n• 通话控制")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } header: {
                Text("通信说明")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("模块连接")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // 如果有保存的配置，自动填充
            if let ip = networkManager.moduleIP {
                manualIP = ip
            }
            manualPort = String(networkManager.modulePort)
        }
    }
    
    // MARK: - 连接到模块
    private func connectToModule(ip: String, port: Int) {
        isConnecting = true
        
        Task {
            let success = await networkManager.connect(to: ip, port: port)
            
            await MainActor.run {
                isConnecting = false
                if success {
                    alertMessage = "连接成功！"
                } else {
                    alertMessage = "连接失败，请检查 IP 地址和端口是否正确"
                }
                showAlert = true
            }
        }
    }
}

// MARK: - 预览
struct ModuleDiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ModuleDiscoveryView()
        }
    }
}
