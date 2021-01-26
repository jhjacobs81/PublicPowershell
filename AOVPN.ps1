############################################
#Create Always-ON VPN Variables
############################################
$ProfileName = 'Always-On VPN'
$Server = 'vpn.google.nl'
$DnsSuffix = 'local.lan'
$DomainName = '.local.lan'
$DNSServers = '8.8.4.4,8.8.8.8'
$TrustedNetwork = 'local.lan'

###############################
#Start Script
###############################
$ProfileNameEscaped = $ProfileName -replace ' ', '%20'

$ProfileXML = '
<VPNProfile>
   <APNBinding>
      <AuthenticationType>None</AuthenticationType>
   </APNBinding>
   <NativeProfile>
      <Servers>'+$Server+'</Servers>
      <Authentication>
         <UserMethod>Mschapv2</UserMethod>
      </Authentication>
   </NativeProfile>
     <AlwaysOn>true</AlwaysOn>
   <RememberCredentials>true</RememberCredentials>
   <TrustedNetworkDetection>'+$TrustedNetwork+'</TrustedNetworkDetection>
<DomainNameInformation>
   <DomainName>'+$DomainName+'</DomainName>
   <DnsServers>'+$DNSServers+'</DnsServers>
</DomainNameInformation>
</VPNProfile>
'
           

$ProfileNameEscaped = $ProfileName -replace ' ', '%20'

$Version = 201606090004

$ProfileXML = $ProfileXML -replace '<', '&lt;'
   $ProfileXML = $ProfileXML -replace '>', '&gt;'
   $ProfileXML = $ProfileXML -replace '"', '&quot;'

   $nodeCSPURI = "./Vendor/MSFT/VPNv2"
   $namespaceName = "root\cimv2\mdm\dmmap"
   $className = "MDM_VPNv2_01"

   try
   {
   $CurrentUser = ((Get-CimInstance -ClassName CIM_ComputerSystem).username | Split-Path -Leaf)
   $SidValue = (New-Object System.Security.Principal.NTAccount($currentuser)).Translate([System.Security.Principal.SecurityIdentifier]).value
   $Message = "User SID is $SidValue."
   $Message >> 'c:\systeembeheer\logs\vpnlog.txt'
   }
   catch [Exception]
   {
   $Message = "Unable to get user SID. User may be logged on over Remote Desktop: $_"
   $Message >> 'c:\systeembeheer\logs\vpnlog.txt'
   exit
   }

   $session = New-CimSession
   $options = New-Object Microsoft.Management.Infrastructure.Options.CimOperationOptions
   $options.SetCustomOption("PolicyPlatformContext_PrincipalContext_Type", "PolicyPlatform_UserContext", $false)
   $options.SetCustomOption("PolicyPlatformContext_PrincipalContext_Id", "$SidValue", $false)

   try
   {
  $deleteInstances = $session.EnumerateInstances($namespaceName, $className, $options)
  foreach ($deleteInstance in $deleteInstances)
  {
      $InstanceId = $deleteInstance.InstanceID
      if ("$InstanceId" -eq "$ProfileNameEscaped")
      {
          $session.DeleteInstance($namespaceName, $deleteInstance, $options)
          $Message = "Removed $ProfileName profile $InstanceId"
          $Message >> 'c:\systeembeheer\logs\vpnlog.txt'
      } else {
          $Message = "Ignoring existing VPN profile $InstanceId"
          $Message >> 'c:\systeembeheer\logs\vpnlog.txt'
      }
  }
   }
   catch [Exception]
   {
  $Message = "Unable to remove existing outdated instance(s) of $ProfileName profile: $_"
  $Message >> 'c:\systeembeheer\logs\vpnlog.txt'
  exit
   }

   try
   {
  $newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance $className, $namespaceName
  $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ParentID", "$nodeCSPURI", "String", "Key")
  $newInstance.CimInstanceProperties.Add($property)
  $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("InstanceID", "$ProfileNameEscaped", "String", "Key")
  $newInstance.CimInstanceProperties.Add($property)
  $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ProfileXML", "$ProfileXML", "String", "Property")
  $newInstance.CimInstanceProperties.Add($property)
  $session.CreateInstance($namespaceName, $newInstance, $options)
  $Message = "Created $ProfileName profile."

  $Message >> 'c:\systeembeheer\logs\vpnlog.txt'
   }
   catch [Exception]
   {
  $Message = "Unable to create $ProfileName profile: $_"
  $Message >> 'c:\systeembeheer\logs\vpnlog.txt'
  exit
   }

   $Message = "Added VPN!"
   $Message >> 'c:\systeembeheer\logs\vpnlog.txt'