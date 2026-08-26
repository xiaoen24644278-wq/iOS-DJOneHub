import SwiftUI

// MARK: - 通话中界面
struct ActiveCallView: View {
    @StateObject var viewModel: PhoneViewModel
    @State private var isDTMFPanelVisible = false
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // 通话状态和号码
                VStack(spacing: 8) {
                    Text(callStatusText)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(displayNumber)
                        .font(.system(size: 28, weight: .medium))
                        .multilineTextAlignment(.center)
                    
                    if case .active = viewModel.callState {
                        Text(viewModel.formattedCallDuration)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // DTMF 面板（通话中显示）
                if isDTMFPanelVisible {
                    DTMFPanel { digit in
                        viewModel.sendDTMF(digit)
                    }
                    .transition(.opacity)
                }
                
                // 操作按钮
                if !isDTMFPanelVisible {
                    callControlButtons
                }
                
                Spacer()
                
                // 挂断按钮
                Button {
                    viewModel.hangup()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - 通话控制按钮
    private var callControlButtons: some View {
        HStack(spacing: 30) {
            // 静音
            CallControlButton(
                systemImage: viewModel.isMuted ? "mic.slash.fill" : "mic.fill",
                isActive: viewModel.isMuted,
                activeColor: .white,
                activeBackground: .accentColor
            ) {
                viewModel.toggleMute()
            }
            
            // 键盘（DTMF）
            CallControlButton(
                systemImage: "grid.circle.fill",
                isActive: isDTMFPanelVisible,
                activeColor: .white,
                activeBackground: .accentColor
            ) {
                withAnimation {
                    isDTMFPanelVisible.toggle()
                }
            }
            
            // 扬声器
            CallControlButton(
                systemImage: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                isActive: viewModel.isSpeakerOn,
                activeColor: .white,
                activeBackground: .accentColor
            ) {
                viewModel.toggleSpeaker()
            }
        }
    }
    
    // MARK: - 显示号码
    private var displayNumber: String {
        switch viewModel.callState {
        case .dialing(let number), .connecting(let number), .active(let number, _, _, _):
            return viewModel.contactName(for: number)
        case .incoming(let number, _):
            return viewModel.contactName(for: number)
        default:
            return "-"
        }
    }
    
    // MARK: - 通话状态文本
    private var callStatusText: String {
        switch viewModel.callState {
        case .dialing: return "正在拨号..."
        case .connecting: return "正在连接..."
        case .active: return "通话中"
        case .incoming: return "来电"
        case .held: return "保持中"
        case .ended(let reason):
            switch reason {
            case .normal: return "通话结束"
            case .missed: return "未接来电"
            case .rejected: return "已拒接"
            case .failed: return "通话失败"
            case .busy: return "对方正在通话"
            }
        default: return ""
        }
    }
}

// MARK: - 通话控制按钮
struct CallControlButton: View {
    let systemImage: String
    let isActive: Bool
    let activeColor: Color
    let activeBackground: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundColor(isActive ? activeColor : .primary)
                .frame(width: 56, height: 56)
                .background(isActive ? activeBackground : Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DTMF 面板
struct DTMFPanel: View {
    let onDigit: (String) -> Void
    
    private let keys: [String] = [
        "1", "2", "3",
        "4", "5", "6",
        "7", "8", "9",
        "*", "0", "#"
    ]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(keys, id: \.self) { key in
                Button {
                    onDigit(key)
                } label: {
                    Text(key)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 60)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 60)
    }
}

// MARK: - 来电界面（独立显示）
struct IncomingCallView: View {
    let phoneNumber: String
    let contactName: String?
    let onAnswer: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("来电")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(contactName ?? phoneNumber.formattedPhoneNumber)
                        .font(.system(size: 28, weight: .medium))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                HStack(spacing: 60) {
                    // 拒接
                    Button {
                        onReject()
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    
                    // 接听
                    Button {
                        onAnswer()
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - 预览
struct ActiveCallView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveCallView(viewModel: PhoneViewModel())
    }
}
