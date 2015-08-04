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
/**
 * There are a LOT of conversions from NSString to char array.
 * This happens on every insert where we bind text to prepared sqlite3 statements.
 * 
 * It is inefficient to use [key UTF8String] for these situations.
 * The Apple documentation is very explicit concerning the UTF8String method:
 * 
 * > The returned C string is automatically freed just as a returned object would be released;
 * > you should copy the C string if [you need] to store it outside of the
 * > autorelease context in which the C string is created.
 * 
 * In other words, the UTF8String method does a malloc for character buffer, copies the characters,
 * and autoreleases the buffer (just like an autoreleased NSData instance).
 * 
 * Thus we suffer a bunch of malloc's if we use UTF8String.
 * 
 * Considering that many of our strings are relatively small,
 * a much faster technique is to use the stack instead of the heap (with obvious precautions, see below).
 * 
 * Note: This technique was borrowed from YapDatabase (which has been heavily tested).
**/


/**
 * We must be cautious and conservative so as to avoid stack overflow.
 * This is possibe if really huge key names or collection names are used.
 *
 * The number below represents the largest amount of memory (in bytes) that will be allocated on the stack per string.
**/
#define SCDatabaseLoggerStringMaxStackLength (1024 * 4)

/**
 * Struct designed to be allocated on the stack.
 * You then use the inline functions below to "setup" and "teardown" the struct.
 * For example:
 * 
 * > SCDatabaseLoggerString myKeyChar;
 * > MakeSCDatabaseLoggerString(&myKeyChar, myNSStringKey);
 * > ...
 * > sqlite3_bind_text(statement, position, myKeyChar.str, myKeyChar.length, SQLITE_STATIC);
 * > ...
 * > sqlite3_clear_bindings(statement);
 * > sqlite3_reset(statement);
 * > FreeSCDatabaseLoggerString(&myKeyChar);
 *
 * There are 2 "public" fields:
 * str    - Pointer to the char[] string.
 * length - Represents the length (in bytes) of the char[] str (excluding the NULL termination byte, as usual).
 * 
 * The other 2 "private" fields are for internal use:
 * strStack - If the string doesn't exceed SCDatabaseLoggerStringMaxStackLength,
 *            then the bytes are copied here (onto stack storage), and str actually points to strStack.
 * strHeap  - If the string exceeds SCDatabaseLoggerStringMaxStackLength,
 *            the space is allocated on the heap, strHeap holds the pointer, and str has the same pointer.
 * 
 * Thus the "setup" and "teardown" methods below will automatically switch to heap storage (just like UTF8String),
 * if the string is too long, and performance will be equivalent.
 * But in the common case of short strings, we can skip the more expensive heap allocation/deallocation.
**/
struct SCDatabaseLoggerString {
	int length;
	char strStack[SCDatabaseLoggerStringMaxStackLength];
	char *strHeap;
	char *str; // Pointer to either strStack or strHeap
};
typedef struct SCDatabaseLoggerString SCDatabaseLoggerString;

/**
 * Initializes the SCDatabaseLoggerString structure.
 * It will automatically use heap storage if the given NSString is too long.
 * 
 * This method should always be balanced with a call to FreeSCDatabaseLoggerString.
**/
NS_INLINE void MakeSCDatabaseLoggerString(SCDatabaseLoggerString *dbStr, NSString *nsStr)
{
	if (nsStr)
	{
		// We convert to int because the sqlite3_bind_text() function expects an int parameter.
		// So we can change it to int here, or we can cast everywhere throughout the project.
		
		dbStr->length = (int)[nsStr lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	
		if ((dbStr->length + 1) <= SCDatabaseLoggerStringMaxStackLength)
		{
			dbStr->strHeap = NULL;
			dbStr->str = dbStr->strStack;
		}
		else
		{
			dbStr->strHeap = (char *)malloc((dbStr->length + 1));
			dbStr->str = dbStr->strHeap;
		}
	
		[nsStr getCString:dbStr->str maxLength:(dbStr->length + 1) encoding:NSUTF8StringEncoding];
	}
	else
	{
		dbStr->length = 0;
		dbStr->strHeap = NULL;
		dbStr->str = NULL;
	}
}

/**
 * If heap storage was needed (because the string length exceeded SCDatabaseLoggerStringMaxStackLength),
 * this method frees the heap allocated memory.
 *
 * In the common case of stack storage, strHeap will be NULL, and this method is essentially a no-op.
 * 
 * This method should be invoked AFTER sqlite3_clear_bindings (assuming SQLITE_STATIC is used).
**/
NS_INLINE void FreeSCDatabaseLoggerString(SCDatabaseLoggerString *dbStr)
{
	if (dbStr->strHeap)
	{
		free(dbStr->strHeap);
		dbStr->strHeap = NULL;
		dbStr->str = NULL;
	}
}
