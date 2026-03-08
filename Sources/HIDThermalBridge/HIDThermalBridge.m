#import "include/HIDThermalBridge.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

// Private IOHIDEvent API declarations — stable since macOS 12 / Apple Silicon launch.

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;

#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

#define IOHIDEventFieldBase(type) ((type) << 16)
#define kIOHIDEventTypeTemperature 15

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client,
                                              CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service,
                                                  int64_t type,
                                                  int32_t options,
                                                  int64_t timeout);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service,
                                                 CFStringRef property);
extern IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

NSDictionary<NSString *, NSNumber *> *_Nullable ReadHIDTemperatures(void) {
#if !TARGET_CPU_ARM64
    return nil; // Only available on Apple Silicon
#else
    NSDictionary *matching = @{
        @"PrimaryUsagePage" : @(0xff00), // kHIDPage_AppleVendor
        @"PrimaryUsage" : @(0x0005)      // kHIDUsage_AppleVendor_TemperatureSensor
    };

    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!system) return nil;

    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)matching);
    CFArrayRef services = IOHIDEventSystemClientCopyServices(system);
    if (!services) {
        CFRelease(system);
        return nil;
    }

    NSMutableDictionary<NSString *, NSNumber *> *result = [NSMutableDictionary dictionary];
    for (CFIndex i = 0; i < CFArrayGetCount(services); i++) {
        IOHIDServiceClientRef service =
            (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        NSString *name =
            CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("Product")));
        if (!name) continue;

        IOHIDEventRef event =
            IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;

        double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);

        if (value > 0 && value < 150) { // basic sanity check
            result[name] = @(value);
        }
    }

    CFRelease(services);
    CFRelease(system);
    return result.count > 0 ? [result copy] : nil;
#endif
}
