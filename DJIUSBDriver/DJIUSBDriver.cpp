#include "DJIUSBDriver.hpp"
#include <os/log.h>

#define DJI_USB_VID 0x2CA3
#define DJI_USB_PID 0x4006

kern_return_t DJIUSBDriver::Start(IOService *provider) {
    os_log(OS_LOG_DEFAULT, "DJIUSBDriver::Start");
    
    kern_return_t ret = Start(provider, SUPERDISPATCH);
    if (ret != kIOReturnSuccess) {
        os_log(OS_LOG_DEFAULT, "Start super failed: 0x%x", ret);
        return ret;
    }
    
    usbInterface = OSDynamicCast(IOUSBHostInterface, provider);
    if (!usbInterface) {
        os_log(OS_LOG_DEFAULT, "Provider is not IOUSBHostInterface");
        return kIOReturnError;
    }
    
    if (!FindPipes()) {
        os_log(OS_LOG_DEFAULT, "Failed to find pipes");
        return kIOReturnError;
    }
    
    os_log(OS_LOG_DEFAULT, "DJIUSBDriver started successfully");
    return kIOReturnSuccess;
}

kern_return_t DJIUSBDriver::Stop(IOService *provider) {
    os_log(OS_LOG_DEFAULT, "DJIUSBDriver::Stop");
    
    if (inPipe) {
        inPipe->Abort();
        inPipe->release();
        inPipe = nullptr;
    }
    
    if (outPipe) {
        outPipe->Abort();
        outPipe->release();
        outPipe = nullptr;
    }
    
    usbInterface = nullptr;
    
    return Stop(provider, SUPERDISPATCH);
}

bool DJIUSBDriver::FindPipes() {
    IOUSBHostPipe **pipes = nullptr;
    uint32_t pipeCount = 0;
    
    kern_return_t ret = usbInterface->CopyPipeReferences(&pipes, &pipeCount);
    if (ret != kIOReturnSuccess || !pipes || pipeCount == 0) {
        os_log(OS_LOG_DEFAULT, "CopyPipeReferences failed: 0x%x, count: %d", ret, pipeCount);
        return false;
    }
    
    for (uint32_t i = 0; i < pipeCount; i++) {
        IOUSBHostPipe *pipe = pipes[i];
        uint8_t direction = 0;
        uint8_t transferType = 0;
        
        pipe->GetDirection(&direction);
        pipe->GetTransferType(&transferType);
        
        // 批量传输端点
        if (transferType == kUSBHostTransferTypeBulk) {
            if (direction == kUSBHostDirectionIn) {
                inPipe = pipe;
                inPipe->retain();
            } else if (direction == kUSBHostDirectionOut) {
                outPipe = pipe;
                outPipe->retain();
            }
        }
    }
    
    // 释放管道引用数组
    for (uint32_t i = 0; i < pipeCount; i++) {
        pipes[i]->release();
    }
    if (pipes) {
        kfree(pipes);
    }
    
    os_log(OS_LOG_DEFAULT, "Found pipes: in=%p, out=%p", inPipe, outPipe);
    return (inPipe != nullptr && outPipe != nullptr);
}

kern_return_t DJIUSBDriver::SendData(const uint8_t *data, uint32_t length, uint32_t *bytesSent) {
    if (!outPipe || !data || length == 0) {
        return kIOReturnBadArgument;
    }
    
    IOBufferMemoryDescriptor *buffer = nullptr;
    kern_return_t ret = IOBufferMemoryDescriptor::Create(kIOMemoryDirectionOut, length, 0, &buffer);
    if (ret != kIOReturnSuccess || !buffer) {
        return ret;
    }
    
    uint8_t *bufferAddress = nullptr;
    ret = buffer->Map(0, length, 0, (void **)&bufferAddress);
    if (ret != kIOReturnSuccess) {
        buffer->release();
        return ret;
    }
    
    memcpy(bufferAddress, data, length);
    buffer->Unmap(bufferAddress);
    
    uint32_t actualBytesSent = 0;
    ret = outPipe->IO(buffer, 0, length, &actualBytesSent, 1000);
    
    if (bytesSent) {
        *bytesSent = actualBytesSent;
    }
    
    buffer->release();
    return ret;
}

kern_return_t DJIUSBDriver::ReceiveData(uint8_t *buffer, uint32_t bufferLength, uint32_t *bytesReceived) {
    if (!inPipe || !buffer || bufferLength == 0) {
        return kIOReturnBadArgument;
    }
    
    IOBufferMemoryDescriptor *memDescriptor = nullptr;
    kern_return_t ret = IOBufferMemoryDescriptor::Create(kIOMemoryDirectionIn, bufferLength, 0, &memDescriptor);
    if (ret != kIOReturnSuccess || !memDescriptor) {
        return ret;
    }
    
    uint32_t actualBytesReceived = 0;
    ret = inPipe->IO(memDescriptor, 0, bufferLength, &actualBytesReceived, 1000);
    
    if (ret == kIOReturnSuccess && actualBytesReceived > 0) {
        uint8_t *bufferAddress = nullptr;
        ret = memDescriptor->Map(0, actualBytesReceived, 0, (void **)&bufferAddress);
        if (ret == kIOReturnSuccess) {
            memcpy(buffer, bufferAddress, actualBytesReceived);
            memDescriptor->Unmap(bufferAddress);
        }
    }
    
    if (bytesReceived) {
        *bytesReceived = actualBytesReceived;
    }
    
    memDescriptor->release();
    return ret;
}
