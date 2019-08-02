# Building

You will need to build swift-sodium first (konnex branch).  Open `File/Project Settings.../Advanced..`. and click on the `Products: ...... right arrow` to open location of build produts in a Finder window.  Copy `Debug-iphoneos/Sodium.framework` and `Debug-iphoneos/Sodium.framework.dYM` to this directory.  Then add  `Sodium.framework` to the project as an `Embedded Binary`.

To use it you will need to `import Sodium`

Note: There is some "suggestion" that if you add the `Sodium.framework.dSYM` directory to the Frameworks folder in Xcode that it will then find the symbols when debugging (if the issue is in Sodium framework).  See https://stackoverflow.com/questions/8584651/xcode-adding-dsym-file-for-a-framework-with-debug-information-in-it.
