# Building

You will need to build swift-sodium first (konnex branch).  Then right-click on Products -> Sodium.framework to get path to built framework.  Typically this is in  `~/Library/Developer/Xcode/DerivedData/Sodium-bwecexhzkbwvoqerivnoxkgxgghs/Build/Products/Debug-iphoneos`.  Copy `Sodium.framwork` and `Socium.framework.dYM` from that directory to this directory.  Then add the framework to the project as an `Embedded Binary`.

To use it you will need to `import Sodium`
