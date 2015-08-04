# libsccrypto

This library packages together all C libraries related to SCimp and SCloud.
It aims to do so in a portable way, such that they can be cross-compiled for
different architectures, such an Mac OS X, Linux, Android, iOS, and Windows.

# Building for the host OS (Mac/Linux)

The simplest way to build this project is simply to run `make host`. This will
perform a build for the host OS, and should work out-of-the-box on most operating
systems, assuming standard C build tools are available.

# Building for Android

Building for Android requires the [Android NDK][NDK].

The `NDK_DIR` environment variable should be set to the path where the NDK
has been extracted. For example, if you extracted the NDK to *~/.android-ndk*,
then you can execute an Android build as follows:

    NDK_DIR=~/.android-ndk make android

[NDK]: https://developer.android.com/tools/sdk/ndk/index.html

# Building for iOS

Building for iOS requires [Xcode](https://developer.apple.com/xcode/downloads/).

An iOS build will only run on Mac OS X, and can be performed via `make ios`.

# Building for Mac OS X

Building for OS X requires [Xcode](https://developer.apple.com/xcode/downloads/).

An OS X build will only run on Mac OS X, and can be performed via `make osx`.

# Troubleshooting

If a build fails, for whatever reason, there should hopefully be some useful
information in the build output to help you recover. If you encounter a problem
that you think may require developer attention, please log a bug in the JIRA
project associated with this library.

Before reporting a bug, please make sure you have the latest version of the
project by performing a `git pull`. It is possible that the issue you are
seeing may have been recently fixed.

# License

Use of this library for any purposes is strictly prohibited except with written
authorization by Silent Circle. All rights reserved.
