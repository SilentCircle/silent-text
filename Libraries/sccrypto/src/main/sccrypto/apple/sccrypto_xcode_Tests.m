/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
//
//  sccryptoTests.m
//  sccryptoTests
//
//  Created by Vinnie Moscaritolo on 10/23/14.
//
//

#import <TargetConditionals.h>

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED 
#define OPTEST_IOS_SPECIFIC 1
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#define OPTEST_OSX_SPECIFIC 1
#endif

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import <XCTest/XCTest.h>
#include  "SCcrypto.h"
#include  "crypto_optest.h"

@interface sccryptoTests : XCTestCase

@end

@implementation sccryptoTests

unsigned int gLogLevel	= OPTESTLOG_LEVEL_ERROR;

-(void) CheckError: (SCLError) err
{
    NSString* errorStr = nil;
 
    if(IsSCLError(err))
    {
        char str[256];
        
        if(IsntSCLError( SCCrypto_GetErrorString(err, sizeof(str), str)))
        {
            errorStr = [ NSString stringWithFormat:@"Error %d:  %s\n", err, str ];
        }
        else
        {
            errorStr = [ NSString stringWithFormat:@"Error %d\n", err ];
            
        }
        
        XCTFail(@"Fail: %@", errorStr);
        
    }
    
}

void OutputString(char *s)
{
    
}


- (void)setUp {
    [super setUp];
    
    SCLError err = kSCLError_NoErr;
    
    err = SCCrypto_Init(); CKERR;
     // Put setup code here. This method is called before the invocation of each test method in the class.
    
done:
    
    [self CheckError:err];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}




////////////////////////

- (void)testHash {
    // This is an example of a functional test case.
    SCLError err = kSCLError_NoErr;
    
    err = TestHash();CKERR;
    
done:
    
    [self CheckError:err];
 }



- (void)testHMAC {
    // This is an example of a functional test case.
    SCLError err = kSCLError_NoErr;
    
    err = TestHMAC();CKERR;
    
done:
    
    [self CheckError:err];
}



- (void)testCiphers {
    // This is an example of a functional test case.
    SCLError err = kSCLError_NoErr;
    
    err = TestCiphers();CKERR;
    
done:
    
    [self CheckError:err];
}



- (void)testCCM {
    // This is an example of a functional test case.
    SCLError err = kSCLError_NoErr;
    
    err = TestCCM();CKERR;
    
done:
    
    [self CheckError:err];
}


- (void)testECC {
    // This is an example of a functional test case.
    SCLError err = kSCLError_NoErr;
    
    err = TestECC();CKERR;
    
done:
    
    [self CheckError:err];
}


- (void)testP2K {
    // This is an example of a functional test case.
    SCLError err = kSCLError_NoErr;
    
    err = TestP2K();CKERR;
    
done:
    
    [self CheckError:err];
}


- (void)testSCKeys {
      SCLError err = kSCLError_NoErr;
    
    err = TestSCKeys();CKERR;
    
done:
    
    [self CheckError:err];
}


- (void)testSirenHash {
    SCLError err = kSCLError_NoErr;
    
    err = TestSirenHash();CKERR;
    
done:
    
    [self CheckError:err];
}


- (void)testSCloud {
      SCLError err = kSCLError_NoErr;
    
    err = TestSCloud();CKERR;
    
done:
    
    [self CheckError:err];
}


- (void)testSCIMP {
    SCLError err = kSCLError_NoErr;
    
    err = TestSCIMP();CKERR;
    
done:
    
    [self CheckError:err];
}


@end
