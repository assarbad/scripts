$SystemRoot = [System.Runtime.InteropServices.Marshal]::PtrToStringUni((New-Object IntPtr(0x7ffe0030)), 260)
$WinVerMaj = [System.Runtime.InteropServices.Marshal]::ReadInt32((New-Object IntPtr(0x7ffe0000)), 0x026c)
$WinVerMin = [System.Runtime.InteropServices.Marshal]::ReadInt32((New-Object IntPtr(0x7ffe0000)), 0x0270)
$WinVerBld = [System.Runtime.InteropServices.Marshal]::ReadInt32((New-Object IntPtr(0x7ffe0000)), 0x0260)
echo "Windows $WinVerMaj.$WinVerMin (build $WinVerBld)"
echo "SystemRoot: $SystemRoot"
