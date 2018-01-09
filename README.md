# ruby-run-resize
Simple utility to resize images suitable for web thumbnails and responsive images.

The script reads in directory names from standard input and scans for image files.

New copies of the image are created at various sizes and stored in a subdirectory.

* Optionally recurses into subdirectories.
* Optionally blast existing target image files.
* Allows override of image file extensions.
* Allows specific ignore files to skip.
* Allows configuration of output dimensions.
* Allows configuration of output folder format.

