# Building

You will need to build swift-sodium first (konnex branch).  Open `File/Project Settings.../Advanced..`. and click on the `Products: ...... right arrow` to open location of build produts in a Finder window.  Copy `Debug-iphoneos/Sodium.framework` and `Debug-iphoneos/Sodium.framework.dYM` to this directory.  Then add  `Sodium.framework` to the project as an `Embedded Binary`.

To use it you will need to `import Sodium`

Note: There is some "suggestion" that if you add the `Sodium.framework.dSYM` directory to the Frameworks folder in Xcode that it will then find the symbols when debugging (if the issue is in Sodium framework).  See https://stackoverflow.com/questions/8584651/xcode-adding-dsym-file-for-a-framework-with-debug-information-in-it.

# iOS 13 SF Symbols back ported to iOS 12

Use [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols/overview/) application to export the desired icons to a SVG file.

Then use Safari developer tools to identify the "Medium/Regular" version.
Copy the corresponding SVG code and wrap in appropriate `<svg>` top level tag.

You will need to adjust the X/Y offsets in the `<g>` tagged matrix transform.
You will also need to ajust the window size in the `<svg>` tag.

Then run [CarioSVG](https://cairosvg.org) tool.  e.g.:

```bash
$ pip install cariosvg

$ cairosvg plus.svg --output-width 25 --output-height 25 -o plus.png
$ cairosvg plus.svg --output-width 50 --output-height 50 -o plus@2.png
$ cairosvg plus.svg --output-width 75 --output-height 75 -o plus@3.png
$ cairosvg lock.svg --output-width 25 --output-height 25 -o lock.png
$ cairosvg lock.svg --output-width 50 --output-height 50 -o lock@2.png
$ cairosvg lock.svg --output-width 75 --output-height 75 -o lock@3.png
$ cairosvg battery25.svg --output-width 45 --output-height 25 -o battery25.png
$ cairosvg battery25.svg --output-width 90 --output-height 50 -o battery25@2.png
$ cairosvg battery25.svg --output-width 135 --output-height 75 -o battery25@3.png

```

Notes:

- The 25/50/75 pixel sizes are for TabBar icons.
- The larger width for the battery icon is to refelct it's non-square shape.

Then drag and drop the png files to the Assests folder in Xcode.

