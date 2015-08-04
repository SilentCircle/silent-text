# ECPhoneNumberFormatter

NSFormatter subclass for formatting phone numbers.

## Usage

### Format a number

```objc
PhoneNumberFormatter *formatter = [[PhoneNumberFormatter alloc] init];
NSString *formattedNumber = [formatter stringForObjectValue:@"2345677890"]
// formattedNumber = @"(234) 567-7890"
```

### Remove formatting

```objc
PhoneNumberFormatter *formatter = [[PhoneNumberFormatter alloc] init];
id objectValue;
NSString *error;
[formatter getObjectValue:&objectValue forString:@"1 (234) 567-8900" errorDescription:&error];
// objectValue = @"12345678900"
```

### Format a NSTextField 

```objc
PhoneNumberFormatter *formatter = [[PhoneNumberFormatter alloc] init];
textField.cell.formatter = formatter;

// textField.objectValue will be unformatted
// textField.stringValue will be formatted
```

## MIT License

Copyright (c) 2013 Michael Enriquez (http://enriquez.me)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
