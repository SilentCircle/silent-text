ZXCVBN
======

This is the ZXCVBN password strength estimation in Obj-C.

The origin version of ZXCVBN was [a coffee script version](https://github.com/lowe/zxcvbn). But this code was based on [the python version by Ryan Pearl](https://github.com/rpearl/python-zxcvbn/). The JSON generator in tools/ also comes from the python version.

Please refer to [the Dropbox Blog article](http://tech.dropbox.com/?p=165) for the full details and motivation behind zxcbvn.


# Install

[CocoaPods](http://cocoapods.org) is a dependency manager for Objective-C, which automates and simplifies the process of using 3rd-party libraries in your projects.

## Podfile

```ruby
platform :ios, '7.0'
pod "ZXCVBN"
```

# Password Strength

```objc
#import <ZXCVBN/BBPasswordStrength.h>

BBPasswordStrength *strength = [[BBPasswordStrength alloc] initWithPassword:@""];
[strength score]; // 0
[strength entropy]; // 0.0
[strength scoreLabel]; // Very Weak
[strength crackTimeDisplay]; // no time

BBPasswordStrength *strength = [[BBPasswordStrength alloc] initWithPassword:@"zxcvbn"];
[strength score]; // 0
[strength entropy]; // 6.845
[strength scoreLabel]; // Very Weak
[strength crackTimeDisplay]; // no time

BBPasswordStrength *strength = [[BBPasswordStrength alloc] initWithPassword:@"qwER43@!"];
[strength score]; // 1
[strength entropy]; // 26.44
[strength scoreLabel]; // Weak
[strength crackTimeDisplay]; // 39 minutes

BBPasswordStrength *strength = [[BBPasswordStrength alloc] initWithPassword:@"Tr0ub4dour&3"];
[strength score]; // 2
[strength entropy]; // 30.435
[strength scoreLabel]; // So-so
[strength crackTimeDisplay]; // 11 hours

BBPasswordStrength *strength = [[BBPasswordStrength alloc] initWithPassword:@"correcthorsebatterystaple"];
[strength score]; // 4
[strength entropy]; // 45.212
[strength scoreLabel]; // Great!
[strength crackTimeDisplay]; // 64 years
```
