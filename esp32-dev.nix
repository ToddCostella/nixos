{ config, pkgs, ... }:

{
  # ESP32 development packages
  environment.systemPackages = with pkgs; [
    # ESP-IDF toolchain
    esptool
    espflash
    
    # PlatformIO for ESP32 development
    platformio
    
    # Serial monitor tools
    picocom
    screen
    minicom
    
    # Python packages for ESP32 tools
    python3
    python3Packages.pyserial
  ];

  # USB permissions for ESP32 devices
  services.udev.extraRules = ''
    # ESP32 HUZZAH32 - CP2104 USB to UART
    SUBSYSTEM=="usb", ATTR{idVendor}=="10c4", ATTR{idProduct}=="ea60", MODE="0666", GROUP="dialout"
    
    # Generic ESP32 boards
    SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="7523", MODE="0666", GROUP="dialout"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6001", MODE="0666", GROUP="dialout"
    
    # Allow access to serial ports
    KERNEL=="ttyUSB[0-9]*", MODE="0666", GROUP="dialout"
    KERNEL=="ttyACM[0-9]*", MODE="0666", GROUP="dialout"
  '';
}