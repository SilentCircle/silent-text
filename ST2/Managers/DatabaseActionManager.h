/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
#import <Foundation/Foundation.h>


/**
 * The DatabaseActionManager should be initialized once the database is up and running.
 * It depends on the following database extensions:
 * - Ext_View_Action
 * - Ext_View_Server
 * 
 * The DatabaseActionManager automatically monitors the action view,
 * and creates timers to create process items in the database once their "actionDate" hits.
 * 
 * For example:
 * 
 * - burning STMessage's once shredDate hits
 * - deleting STPublicKey's when they expire
 * - creating new STPublicKey's for local users
 * - removice cached SCloud files
**/
@interface DatabaseActionManager : NSObject

+ (DatabaseActionManager *)sharedInstance;

/**
 * DO NOT ADD PUBLIC METHODS TO THIS CLASS !!!!!
 *
 * The DatabaseActionManager is designed to do exactly one thing:
 * - wait for the next item in the Ext_View_Expire to fire
 * - execute the proper action according to the item
 *
 * Add functionality elsewhere.
 * Add the method to DatabaseManager or STUserManager.
 *
 * But this class already has a method that does what I want.
 * Then move that method to another class, and have both this class and others call it.
 * 
 * Basically, this class should have zero logic,
 * except the logic to invoke other methods when a specific date hits.
**/
@end
