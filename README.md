
Introduction
============

This repository contains the sources for Silent Circle's Silent Text for iOS project.

### Overview 

Silent Text is a secure text messaging application built on strong cryptography and XMPP.

### Prerequisites

To build Silent Text you need Xcode 6.3 or higher and the Command Line Tools.

### How to Build

- Download the repository
- create a terminal window
- cd to the top of the repository
- bash build-release/SilentTextBuild.sh 2>&1 | tee -a xcodebuild.log 

The build produces SilentText.xcarchive which contains the app and can be use to make an ipa.
