Function deviceInfo_Initialize(msgPort As Object, userVariables As Object, bsp as Object)
    reg = CreateObject("roRegistrySection", "networking")
    reg.write("telnet","23")

    deviceInfo = {}
    deviceInfo.msgPort = msgPort
    deviceInfo.userVariables = userVariables
    deviceInfo.bsp = bsp
    deviceInfo.ProcessEvent=deviceInfo_ProcessEvent

    deviceInfo.name = "deviceInfo"
    deviceInfo.version = 0.1

    ' --------------- Get the Serial Number of the Unit
    player = CreateObject("roDeviceInfo")
    deviceInfo.uniqueId = player.GetDeviceUniqueId()

    ' --------------- Get the Name of the Unit
    registrySection = CreateObject("roRegistrySection", "networking")
    deviceInfo.unitName = registrySection.Read("un")

    ' --------------- Get the IP Address of the Unit
    net = CreateObject("roNetworkConfiguration", 1) 
    deviceInfo.ip = ""

    if net <> invalid then 
        deviceInfo.ip = net.GetCurrentConfig().ip4_address
	endif

    ' --------------- Get the Channel Url
    currentSync = CreateObject("roSyncSpec")
    deviceInfo.channelUrl = ""

    if not currentSync.ReadFromFile("current-sync.xml") then
	    deviceInfo.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin ### No current sync state available")
    else
        deviceInfo.channelUrl = currentSync.LookupMetadata("client", "base")
	endif

    deviceInfo.bsp.diagnostics.PrintDebug("@deviceInfoPlugin deviceInfo Initialized")

  return deviceInfo
End Function



Function deviceInfo_ProcessEvent(event as Object) as boolean
	retval = false

    m.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Type of event is - " + type(event))
    'm.bsp.diagnostics.PrintDebug( "EventType - " + event["EventType"])
    'm.bsp.diagnostics.PrintDebug( "Send Plugin Message - " + event["EventType"])
    'm.bsp.diagnostics.PrintDebug( "Plugin Name - " + event["PluginName"])
    
	if type(event) = "roAssociativeArray" then
    if type(event["EventType"]) = "roString" 
        if (event["EventType"] = "SEND_PLUGIN_MESSAGE") then
            if event["PluginName"] = "deviceInfo" then
                m.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Event is from DeviceInfo")
                pluginMessage$ = event["PluginMessage"]
                retval = SendDeviceInfo(pluginMessage$, m)
            endif
        endif
    endif
	endif

	if type(event) = "roDatagramEvent" then
	    msg$ = event
	    retval = SendDeviceInfo(msg, m)
	end if
	
	return retval
end Function



Function SendDeviceInfo(msg as string, h as Object) as Object
    h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Sending Device Info")

	h.bsp.diagnostics.PrintDebug("@deviceInfoPlugin Message: " + msg)
    h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Ip: "+ h.ip)
    h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Name: "+ h.unitName)
    h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Channel: "+ h.channelUrl)
    h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Serial Number: "+ h.uniqueId)

	retval = false

    info = CreateObject("roAssociativeArray")

    info.AddReplace("Ip", h.ip)
    info.AddReplace("Name", h.unitName)
    info.AddReplace("Channel", h.channelUrl)
    info.AddReplace("SerialNumber", h.uniqueId)

	if h.userVariables["DeviceInfo_url"]<>invalid
	    DeviceInfo_url=h.userVariables["DeviceInfo_url"].currentValue$
	else
	    DeviceInfo_url=""
    end if

    if DeviceInfo_url<>""
        h.bsp.diagnostics.PrintDebug("@deviceInfoPlugin Device Info Rest Url :" + DeviceInfo_url)

		xfer = CreateObject("roUrlTransfer") 
		
		xfer.SetURL(DeviceInfo_url)
        xfer.AddHeader("Content-Type", "application/json")
		
        h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin POSTING Device Info")
		h.bsp.diagnostics.PrintDebug(FormatJson(info))

		ok = xfer.AsyncPostFromString(FormatJson(info)) 
		
		if(ok) then
			h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Successfully POSTed Device Info!")
			retval = true
		else
			h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin Cannot POST Device Info!")
		endif

	else
	    h.bsp.diagnostics.PrintDebug( "@deviceInfoPlugin No DeviceInfo_url user variable is defined.")
	endif

	return retval
end Function
