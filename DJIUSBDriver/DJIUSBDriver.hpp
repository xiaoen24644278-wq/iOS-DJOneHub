#ifndef DJIUSBDriver_hpp
#define DJIUSBDriver_hpp

#include <DriverKit/DriverKit.h>
#include <DriverKit/IOUserServer.h>
#include <USBDriverKit/USBDriverKit.h>
#include <USBDriverKit/IOUSBHostInterface.h>
#include <USBDriverKit/IOUSBHostPipe.h>
#include <USBDriverKit/IOUSBHostDevice.h>

class DJIUSBDriver : public IOUserServer {
public:
    virtual kern_return_t Start(IOService *provider) override;
    virtual kern_return_t Stop(IOService *provider) override;
    
    // 发送数据到 USB 设备
    kern_return_t SendData(const uint8_t *data, uint32_t length, uint32_t *bytesSent);
    
    // 从 USB 设备接收数据
    kern_return_t ReceiveData(uint8_t *buffer, uint32_t bufferLength, uint32_t *bytesReceived);
    
private:
    IOUSBHostInterface *usbInterface = nullptr;
    IOUSBHostPipe *inPipe = nullptr;
    IOUSBHostPipe *outPipe = nullptr;
    
    bool FindPipes();
};

#endif /* DJIUSBDriver_hpp */
