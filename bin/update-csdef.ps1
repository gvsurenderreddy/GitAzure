if ((test-path ..\ServiceDefinition.csdef) -ne $true) {
	Write-Host ServiceDefinition.csdef not found in parent directory. 
	Write-Host Make sure you execute this script in the Web Role directory.
	exit -1
}

[xml]$xml = Get-Content ..\ServiceDefinition.csdef
$roleName = [io.path]::GetFileName((get-location))

function getXmlNode($str) {
	$docfrag = $xml.CreateDocumentFragment()
	$docfrag.InnerXml = "<x xmlns=""http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition"">" + $str + "</x>"
	$docfrag.FirstChild.FirstChild
}

$ns = New-Object Xml.XmlNamespaceManager $xml.NameTable
$ns.AddNamespace("e", "http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition" )

$roleNode = $xml.SelectSingleNode("//e:*[substring(name(), string-length(name()) - 3) = 'Role' and @name='$roleName']", $ns)
if ($roleNode -eq $null) {
	Write-Host "ServiceDefinition.csdef seems to be corrupted (it does not contain a node for the current role)."
	exit -1
}

if ($roleNode.SelectNodes("//e:Startup", $ns).Count -le 0) {
	$roleNode.AppendChild((getXmlNode("<Startup></Startup>")))
}

if ($roleNode.SelectNodes("//e:Task[@commandLine='setup_git.cmd']", $ns).Count -le 0) {
	$node = $roleNode.SelectSingleNode("//e:Startup", $ns)
	$node.AppendChild((getXmlNode("<Task commandLine=""setup_git.cmd"" executionContext=""elevated""><Environment><Variable name=""EMULATED""><RoleInstanceValue xpath=""/RoleEnvironment/Deployment/@emulated"" /></Variable><Variable name=""GITPATH""><RoleInstanceValue xpath=""/RoleEnvironment/CurrentInstance/LocalResources/LocalResource[@name='Git']/@path"" /></Variable><Variable name=""GITHOME""><RoleInstanceValue xpath=""/RoleEnvironment/CurrentInstance/LocalResources/LocalResource[@name='GitHome']/@path"" /></Variable></Environment></Task>")))
}

if ($roleNode.SelectNodes("//e:Task[@commandLine='install_nodemodules.cmd']", $ns).Count -le 0) {
	$node = $roleNode.SelectSingleNode("//e:Startup", $ns)
	$node.AppendChild((getXmlNode("<Task commandLine=""install_nodemodules.cmd"" executionContext=""elevated""><Environment><Variable name=""EMULATED""><RoleInstanceValue xpath=""/RoleEnvironment/Deployment/@emulated"" /></Variable></Environment></Task>")))
}

if ($roleNode.SelectNodes("//e:LocalStorage[@name='Git']", $ns).Count -le 0) {
	$node = $roleNode.SelectSingleNode("//e:LocalResources", $ns)
	if ($node -eq $null) {
		$node = $roleNode.SelectSingleNode("//e:Startup", $ns)
		$node = $node.ParentNode.InsertAfter((getXmlNode("<LocalResources />")), $node)
	}
	$node.AppendChild((getXmlNode("<LocalStorage name=""Git"" sizeInMB=""1000"" />")))
}

if ($roleNode.SelectNodes("//e:LocalStorage[@name='GitHome']", $ns).Count -le 0) {
	$node = $roleNode.SelectSingleNode("//e:LocalResources", $ns)
	if ($node -eq $null) {
		$node = $roleNode.SelectSingleNode("//e:Startup", $ns)
		$node = $node.ParentNode.InsertAfter((getXmlNode("<LocalResources />")), $node)
	}
	$node.AppendChild((getXmlNode("<LocalStorage name=""GitHome"" sizeInMB=""10"" />")))
}

$xml.Save((Get-Location).Path + "\..\ServiceDefinition.csdef")
