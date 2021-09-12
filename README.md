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



convert -resize 120x120 Konnex.png Konnex-120x120.png
convert -resize 167x167 Konnex.png Konnex-167x167.png
convert -resize 152x152 Konnex.png Konnex-152x152.png
convert -resize 1024x1024 Konnex.png Konnex-1024x1024.png
convert -resize 1024x1024 Konnex.png Konnex-1024x1024.png

#convert -resize 1024x1024 -alpha off Konnex.png Konnex-1024x1024.png
#convert -resize 1024x1024 -alpha off -background white Konnex.png Konnex-1024x1024.png
#convert -resize 1024x1024 -background white Konnex.png Konnex-1024x1024.png
#convert -resize 1024x1024 -background white Konnex.png -alpha off Konnex-1024x1024.png
#convert -resize 1024x1024 -background white Konnex.png -alpha remove Konnex-1024x1024.png
#convert -resize 1024x1024 -background white Konnex.png Konnex-1024x1024.png
#convert -resize 1024x1024 -background white -alpha remove Konnex.png Konnex-1024x1024.png
#convert -resize 1024x1024 -background red -alpha remove Konnex.png Konnex-1024x1024.png
convert -resize 1024x1024 -background white -alpha remove Konnex.png Konnex-1024x1024.png



```

> Notes:
>
> - The 25/50/75 pixel sizes are for TabBar icons.
> - The larger width for the battery icon is to refelct it's non-square shape.
>
> Then drag and drop the png files to the Assests folder in Xcode.

## Export Compliance

__Note: None of the following represents an expert or legal opinion, just my layman's read of the info.  You will need to seek expert advice in this area.__

> Based on what the analysis below this is the proposed short term plan (internal alpha testing/demo only):
>
> * Publish the source code for the demo app to the following public location <https://github.com/UnitCircleInc/ke-iOS>.
> * Send email to BIS and ENC (email sent July 13, 2020 CC'ing <jgrzenda@konnexenterprises.com>) the location of the source code (meeting the Option2/3 below assuming ECCN 5D002.c).
> 
> __Konnex Enterprises Inc. will need to schedule sending a year-end-self-classification report before the end of the year (before Feb. 1 starting in 2021 and every year after).__


For the moment limiting to just the phone app, but there are similar considerations for other components, e.g. the lock, cloud server, and web app - or perhaps the entire things can be done as one "system" - although the components are being exported individually (so not sure what that means).

In the phone app we make use of cryptographic functions (Information Security) from:

* iOS - HTTPS to talk to the server.
* [LibSodium](https://github.com/jedisct1/libsodium) - crypto library used for generating and verifying locks, keys and phone identities (authentication functions).

At a minimum using iOS's (or Android's) HTTPS stack requires sending a [year-end-self-classification report](https://www.bis.doc.gov/index.php/policy-guidance/encryption/4-reports-and-reviews/a-annual-self-classification) for application encryption commodities, software and components export for reexported during a calendar year (Jan1-Dec31) must be received by BIS and ENC no later than Feb 1 of the following year.   This must be sent every year that export or reexport occurs.  This requirement is likely due to [Encryption items NOT Subject to the EAR (1) - Mass market encryption object code software that is made 'publicly available'](https://bis.doc.gov/index.php/policy-guidance/encryption/1-encryption-items-not-subject-to-the-ear).   On reading the [Mass Market section 740.17](https://www.bis.doc.gov/index.php/policy-guidance/encryption/3-license-exception-enc-and-mass-market/a-mass-market) portion of the requirement , I'm not sure this application could be classified under ECCN 5D992.c - I think an argument can be made either way.  Either way it still seems like a good idea to send the year-end-self-classification report.

Continuing with [Encryption items NOT Subject to the EAR](https://bis.doc.gov/index.php/policy-guidance/encryption/1-encryption-items-not-subject-to-the-ear) I believe that the app would be classified as [ECCN 5D002.c](https://bis.doc.gov/index.php/documents/new-encryption/1652-cat-5-part-2-quick-reference-guide/file) as it is software that as it implements Cryptographic functionality:

> If we made the app source code publicly available (Option 2), we could submit to App Store (Option 3 - we are submitting object code to App Store).  The Note 2 clarifies that even though we are incorporating or calling publicly available encryption source code (iOS HTTPS or LibSodium), the app is a new entity and evaluated as a whole under EAR - so we can't just rely on iOS HTTPS stack or LibSodium library being "publicly available".   We would need to email ahead of time BIS and ENC the location of the source code (see [EAR 742.15(b)](https://www.ecfr.gov/cgi-bin/text-idx?SID=00a8f54989eaf101a84eff3db59ac6e9&mc=true&node=se15.2.742_115&rgn=div88)).

This seems to work for Apache which distribute lots of cryptographically enabled software.

There are also exceptions granted under [Cat. 5 Part 2](https://bis.doc.gov/index.php/2-items-in-cat-5-part-2/a-5a002-a-and-5d002-c-1/i-crypto-for-data-confidentiality).  Specifically 1.a "Authentication".   They define "Authentication" as:

> Verifying the identity of user, process or device, often as a prerequisite to allowing access to resources in an information system. This includes verifying the origin or content of a message or other information, and all aspects of access control where there is no encryption of files or text except as directly related to the protection of passwords, Personal Identification Numbers (PINs) or similar data to prevent unauthorized access.

Which sounds like what a lock system is all about, and is certainly the use case for LibSodium portion.  This would allow for classification as EAR99 (if not other classifications apply), with no action required other than the [normal monitoring of screening for restricted parties](https://www.bis.doc.gov/index.php/policy-guidance/lists-of-parties-of-concern), [restricted countries](https://www.bis.doc.gov/index.php/policy-guidance/country-guidance/sanctioned-destinations), and monitoring [red flags](https://www.bis.doc.gov/index.php/enforcement/oee/compliance/23-compliance-a-training/51-red-flag-indicators) (which is always required in every case).

It seems that you can call BIS at and get advise on classification.

As for Canada it appears we do not need an [Export Permit](https://www.international.gc.ca/controls-controles/export-exportation/crypto/Crypto_Intro.aspx?lang=eng) for export cryptography and information security goods or tech form Canada to the US (as we are initially exporting from Canada to Apple's servers in the US - similarly if we were to host the Web server in the US we would be exporting the code there).

Some more links:

* [BIS Reporting Guide](https://bis.doc.gov/index.php/policy-guidance/encryption/4-reports-and-reviews/a-annual-self-classification)
* [BIS Contact Info](https://www.bis.doc.gov/index.php/about-bis/contact-bis)
* [BIS Examples of Investigations](https://www.bis.doc.gov/index.php/documents/enforcement/1005-don-t-let-this-happen-to-you-1/file)
* [BIS EAR Top Level entry to al docs.](https://www.bis.doc.gov/index.php/regulations/export-administration-regulations-ear)
* [BIS Encryptions items not subject to EAR](https://bis.doc.gov/index.php/policy-guidance/encryption/1-encryption-items-not-subject-to-the-ear) - The side bar has lots of good links.
* [EAR 742.15b](https://www.ecfr.gov/cgi-bin/text-idx?SID=03a422b19b284c19380a2a0800174721&mc=true&node=pt15.2.742&rgn=div5#se15.2.742_115)
* [BIS Cat 5 Part 2 Quick Ref for ECCN 5X](https://bis.doc.gov/index.php/documents/new-encryption/1652-cat-5-part-2-quick-reference-guide/file)
* [Section (e) of TSU exemption to export controls](https://www.govinfo.gov/content/pkg/CFR-2006-title15-vol2/xml/CFR-2006-title15-vol2-sec740-13.xml)
* [Apache examples of 5D002](http://www.apache.org/licenses/exports/) and [release docs](http://www.apache.org/dev/crypto.html) [Has some good info and Konnex iOS App would seem to fall under the same process.  Seems like as long as source code for crypto is public (e.g. GITHUB) all that is required is an email to notify BIS.]
* Apple's notes on [Export compliance documentation for encryption](https://help.apple.com/app-store-connect/#/devc3f64248f) and [Complying with Encryption Export Regulations (for Test Flight and App Store)](https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations).




