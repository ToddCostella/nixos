{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # GUI-based photo editing and restoration tools
    gimp-with-plugins      # Full-featured image editor with plugins
    darktable             # Professional photo workflow application
    rawtherapee           # Advanced photo processor
    
    # AI-based restoration
    upscayl               # AI image upscaler and enhancer
    
    # Command-line tools
    imagemagick           # Command-line image processing
    gmic                  # G'MIC framework for image processing
    gmic-qt               # G'MIC Qt interface for GIMP integration
    
    # Additional useful tools
    exiftool              # Read/write image metadata
    hugin                 # Panorama photo stitcher (useful for alignment)
    digikam               # Photo management with basic editing
    
    # Color management
    displaycal            # Display calibration and profiling
    argyllcms             # Color management system
  ];
}