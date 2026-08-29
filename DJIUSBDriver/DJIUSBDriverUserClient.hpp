#ifndef DJIUSBDriverUserClient_hpp
#define DJIUSBDriverUserClient_hpp

#include <DriverKit/IOUserClient.h>
#include "DJIUSBDriver.hpp"

#define DJI_DRIVER_USERCLIENT_TYPE 0

// 用户客户端方法 ID
enum {
    kDJIUserClientMethodSendData = 0,
    kDJIUserClientMethodReceiveData = 1,
    kDJIUserClientMethodGetStatus = 2,
};

class DJIUSBDriverUserClient : public IOUserClient {
public:
    virtual bool init() override;
    virtual kern_return_t Start(IOService *provider) override;
    virtual void Stop(IOService *provider) override;
    virtual void free() override;
    
    virtual kern_return_t ExternalMethod(uint64_t selector,
                                          IOUserClientMethodArguments *arguments,
                                          IOUserClientMethodDispatch *dispatch,
                                          OSObject *completion) override;
    
private:
    DJIUSBDriver *driver = nullptr;
    
    kern_return_t SendData(IOUserClientMethodArguments *arguments);
    kern_return_t ReceiveData(IOUserClientMethodArguments *arguments);
    kern_return_t GetStatus(IOUserClientMethodArguments *arguments);
};

#endif /* DJIUSBDriverUserClient_hpp */
