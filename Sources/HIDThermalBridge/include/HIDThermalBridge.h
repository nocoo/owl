#pragma once

#import <Foundation/Foundation.h>

/// Read all temperature sensors via IOHIDEventSystemClient.
/// Returns dictionary of {sensorName: temperatureInCelsius}.
/// Available on Apple Silicon only; returns nil on Intel or on failure.
NSDictionary<NSString *, NSNumber *> *_Nullable ReadHIDTemperatures(void);
