# vm.set id=<string> [auto_poweron=<boolean>] [name_label=<string>] [name_description=<string>] [notes=<string|null>] [high_availability=<unknown type>] [CPUs=<integer>] [cpusMax=<integer|string>] [memory=<integer|string>] [memoryMin=<integer|string>] [memoryMax=<integer|string>] [memoryStaticMax=<integer|string>] [PV_args=<string>] [cpuMask=<array>] [cpuWeight=<integer|null>] [cpuCap=<integer|null>] [affinityHost=<string|null>] [vga=<string>] [videoram=<number>] [coresPerSocket=<string|number|null>] [hasVendorDevice=<boolean>] [expNestedHvm=<boolean>] [nestedVirt=<boolean>] [resourceSet=<string|null>] [share=<boolean>] [startDelay=<integer>] [secureBoot=<boolean>] [nicType=<string|null>] [hvmBootFirmware=<string|null>] [virtualizationMode=<string>] [viridian=<boolean>] [blockedOperations=<object>] [creation=<object>] [suspendSr=<string|null>] [uefiMode=<unknown type>] [xenStoreData=<object>]





xo-cli register --allowUnauthorized https://192.168.1.20:8443 admin m3gaFox50
xo-cli vif.set id=<string> txChecksumming=false
xo-cli vm.stats id=ced56d99-14bc-7dc3-bbf5-94989c138dcc
