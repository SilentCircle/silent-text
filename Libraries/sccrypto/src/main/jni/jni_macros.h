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
#ifndef __JNI_MACROS_H__
#define __JNI_MACROS_H__ 1
#include <jni.h>

#include <android/log.h>
#define LOGE(...) __android_log_print( ANDROID_LOG_DEBUG, "libsccrypto-jni", __VA_ARGS__ );

#define VERIFY_JNI_ALLOC( jname, name ) ( ( (jname != NULL) && (name != NULL) ) || ( (jname == NULL) && (name == NULL) ) )

#define NEW_BYTES( jname, name, nameSize ) jbyte *name = (jname == NULL) ? NULL : (*jni)->GetByteArrayElements( jni, jname, NULL ); size_t nameSize = (jname == NULL) ? 0 : (size_t) (*jni)->GetArrayLength( jni, jname );
#define FREE_BYTES( jname, name ) if ( (jname != NULL) && (name != NULL) ) (*jni)->ReleaseByteArrayElements( jni, jname, name, JNI_ABORT );
#define VERIFY_BYTES( jname, name ) VERIFY_JNI_ALLOC( jname, name )

#define NEW_STRING( jname, name ) const char *name = (jname == NULL) ? NULL : (*jni)->GetStringUTFChars( jni, jname, NULL );
#define FREE_STRING( jname, name ) if ( (jname != NULL) && (name != NULL) ) { (*jni)->ReleaseStringUTFChars( jni, jname, name ); }
#define VERIFY_STRING( jname, name ) VERIFY_JNI_ALLOC( jname, name )

#define NEW_OUT_STRING( jname, name ) jstring jname = (name == NULL) ? NULL : (*jni)->NewStringUTF( jni, name );
#define FREE_OUT_STRING( jname ) if( jname != NULL ) { (*jni)->DeleteLocalRef( jni, jname ); }
#define VERIFY_OUT_STRING( jname, name ) VERIFY_JNI_ALLOC( jname, name )

#define NEW_OUT_BYTES( jname, name ) jbyteArray jname = (name == NULL) ? NULL : (*jni)->NewByteArray( jni, name->size ); if ( (name != NULL) && (jname != NULL) ) { (*jni)->SetByteArrayRegion( jni, jname, 0, name->size, (jbyte*) name->items ); }
#define FREE_OUT_BYTES( jname ) ;
#define VERIFY_OUT_BYTES( jname, name ) VERIFY_JNI_ALLOC( jname, name )
#endif
