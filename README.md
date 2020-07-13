# Building

This project uses the Cocoa Pod from the [swift-sodium](https://github.com/jedisct1/swift-sodium) project.

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

> Notes:
>
> - The 25/50/75 pixel sizes are for TabBar icons.
> - The larger width for the battery icon is to refelct it's non-square shape.
>
> Then drag and drop the png files to the Assests folder in Xcode.

## Export Controls

See:

* [Apache Cyrpto](https://www.apache.org/dev/crypto.html) has some good info and Konnex iOS App would seem to fall under the same process.  Seems like as long as source code for crypto is public (e.g. GITHUB) all that is required is an email to notify BIS.
* [EAR 742.15b](https://www.ecfr.gov/cgi-bin/text-idx?SID=03a422b19b284c19380a2a0800174721&mc=true&node=pt15.2.742&rgn=div5#se15.2.742_115)
* [BIS Encryptions items not subject to EAR](https://bis.doc.gov/index.php/policy-guidance/encryption/1-encryption-items-not-subject-to-the-ear) - The side bar has lots of good links.
* [Apple export compliance](https://help.apple.com/app-store-connect/#/devc3f64248f)
* [BIS Quick Reference](https://bis.doc.gov/index.php/documents/new-encryption/1652-cat-5-part-2-quick-reference-guide/file)


