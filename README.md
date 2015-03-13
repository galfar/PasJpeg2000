**JPEG 2000 for Pascal** is a free library for Object Pascal (_Delphi_ and _Free Pascal_) developers that want to use JPEG 2000 images in their applications. 

It is based on [OpenJpeg](http://www.openjpeg.org/) library written in C language (BSD license). C library is precompiled (using C++ Builder for Delphi and GCC for FPC) for several platforms and Pascal header is provided. Some higher level classes for easier manipulation with JPEG 2000 images are part of the JPEG 2000 for Pascal as well.


## Library Contents

  * Cross-platform Pascal interface to OpenJpeg – low level access to precompiled library. Currently supported platforms: Windows 32bit, Linux 32/64bit, and Mac OS X.
  * VCL wrapper for Delphi (TBitmap descendant) enabling easy loading and saving of JPEG 2000 images.
  * Samples that demonstrate usage of all library interfaces and few test images in various data formats.

## Installation

_Delphi_: Just add some of JPEG 2000 for Pascal units you want to use to your uses clause (must be in you search path) and precompiled library will be linked automatically.

_Free_ _Pascal_: `OpenJpeg` is compiled into static libraries so you have to set library search path when compiling your project. Libraries are located in J2KObjects directory.


More info: http://galfar.vevb.net/pasjpeg2000
