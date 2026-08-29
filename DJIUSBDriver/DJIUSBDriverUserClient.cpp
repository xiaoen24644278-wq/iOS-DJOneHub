#include "DJIUSBDriverUserClient.hpp"
#include <os/log.h>

bool DJIUSBDriverUserClient::init() {
    if (!IOUserClient::init()) {
        return false;
    }
    os_log(OS_LOG_DEFAULT, "DJIUSBDriverUserClient::init");
    return true;
}

kern_return_t DJIUSBDriverUserClient::Start(IOService *provider) {
    os_log(OS_LOG_DEFAULT, "DJIUSBDriverUserClient::Start");
    
    kern_return_t ret = Start(provider, SUPERDISPATCH);
    if (ret != kIOReturnSuccess) {
        return ret;
    }
    
    driver = OSDynamicCast(DJIUSBDriver, provider);
    if (!driver) {
        return kIOReturnError;
    }
    
    return kIOReturnSuccess;
}

void DJIUSBDriverUserClient::Stop(IOService *provider) {
    os_log(OS_LOG_DEFAULT, "DJIUSBDriverUserClient::Stop");
    driver = nullptr;
    Stop(provider, SUPERDISPATCH);
}

void DJIUSBDriverUserClient::free() {
    os_log(OS_LOG_DEFAULT, "DJIUSBDriverUserClient::free");
    IOUserClient::free();
}

kern_return_t DJIUSBDriverUserClient::ExternalMethod(uint64_t selector,
                                                        IOUserClientMethodArguments *arguments,
                                                        IOUserClientMethodDispatch *dispatch,
                                                        OSObject *completion) {
    if (!driver) {
        return kIOReturnNotOpen;
    }
    
    switch (selector) {
        case kDJIUserClientMethodSendData:
            return SendData(arguments);
        case kDJIUserClientMethodReceiveData:
            return ReceiveData(arguments);
        case kDJIUserClientMethodGetStatus:
            return GetStatus(arguments);
        default:
            return kIOReturnBadArgument;
    }
}

kern_return_t DJIUSBDriverUserClient::SendData(IOUserClientMethodArguments *arguments) {
    if (!arguments->structureInput || arguments->structureInputSize == 0) {
        return kIOReturnBadArgument;
    }
    
    const uint8_t *data = (const uint8_t *)arguments->structureInput;
    uint32_t length = (uint32_t)arguments->structureInputSize;
    uint32_t bytesSent = 0;
    
    kern_return_t ret = driver->SendData(data, length, &bytesSent);
    
    if (arguments->structureOutput && arguments->structureOutputSize >= sizeof(uint32_t)) {
        uint32_t *output = (uint32_t *)arguments->structureOutput;
        *output = bytesSent;
        arguments->structureOutputSize = sizeof(uint32_t);
    }
    
    return ret;
}

kern_return_t DJIUSBDriverUserClient::ReceiveData(IOUserClientMethodArguments *arguments) {
    if (!arguments->structureOutput || arguments->structureOutputSize == 0) {
        return kIOReturnBadArgument;
    }
    
    uint8_t *buffer = (uint8_t *)arguments->structureOutput;
    uint32_t bufferLength = (uint32_t)arguments->structureOutputSize;
    uint32_t bytesReceived = 0;
    
    kern_return_t ret = driver->ReceiveData(buffer, bufferLength, &bytesReceived);
    
    arguments->structureOutputSize = bytesReceived;
    return ret;
}

kern_return_t DJIUSBDriverUserClient::GetStatus(IOUserClientMethodArguments *arguments) {
    if (!arguments->structureOutput || arguments->structureOutputSize < sizeof(uint32_t)) {
        return kIOReturnBadArgument;
    }
    
    uint32_t *status = (uint32_t *)arguments->structureOutput;
    *status = driver ? 1 : 0;
    arguments->structureOutputSize = sizeof(uint32_t);
    
    return kIOReturnSuccess;
}
