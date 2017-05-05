REM
REM @title               Device Information Uploader
REM @author              Sabin Maharjan
REM @company	         Port Of Portland
REM @date-created        04/21/2017
REM @date-last-modified  04/26/2017
REM
REM @description         Uploads Device Information Periodically Given the User Variable time value
REM

Function deviceInfoPlugin_Initialize(msgPort As Object, userVariables As Object, bsp as Object)

    deviceInfoPlugin = {}
    deviceInfoPlugin.msgPort = msgPort
    deviceInfoPlugin.userVariables = userVariables
    deviceInfoPlugin.bsp = bsp
    deviceInfoPlugin.ProcessEvent = deviceInfoPlugin_ProcessEvent
	deviceInfoPlugin.timer = CreateObject("roTimer")
    deviceInfoPlugin.reg = CreateObject("roRegistrySection", "networking")
    deviceInfoPlugin.uploadTimerInSeconds = 60

    '----- Get user Variable for debug (if any)
	
    if userVariables["Enable_Telnet"] <> invalid
	    enable$ = userVariables["Enable_Telnet"].currentValue$
        if LCase(enable$) = "yes"
            deviceInfoPlugin.reg.write("telnet", "23")
            print "@deviceInfoPlugin TELNET Enabled."
        else
            deviceInfoPlugin.reg.delete("telnet", "23")
            print "@deviceInfoPlugin TELNET Disabled."
        end if
    end if

    '----- Get user Variable for uplaod Time (if any)
	
    if userVariables["DeviceInfo_Upload_Timer_Value"] <> invalid
	    userVarelapsedTimeInSeconds$ = userVariables["DeviceInfo_Upload_Timer_Value"].currentValue$
        deviceInfoPlugin.uploadTimerInSeconds = userVarelapsedTimeInSeconds$.toint()
        print "@deviceInfoPlugin Upload Timer Set To "; deviceInfoPlugin.uploadTimerInSeconds; " Seconds"
    end if

    '----- Create Message Port and Set Timer
    
    deviceInfoPlugin.timer.SetPort(deviceInfoPlugin.msgPort)
	
	deviceInfoPlugin.timer.SetUserData("SEND_DEVICEINFO")

    deviceInfoPlugin.timer.SetElapsed(deviceInfoPlugin.uploadTimerInSeconds, 0)

    deviceInfoPlugin.timer.Start()

    return deviceInfoPlugin

End Function

Function deviceInfoPlugin_ProcessEvent(event as Object)
	
	retval = false
	
	if type(event) = "roTimerEvent" then
		if event.GetUserData() <> invalid then
			if event.GetUserData() = "SEND_DEVICEINFO" then
			    print "@deviceInfoPlugin Sending Device Info..."
				success = SendDeviceInfo(m)
				retval = success
			end if
		end if
	end if
	
	m.timer.Start()
	
	return retval
	
End Function

Function newDeviceInfo(userVariables As Object)
	
    player = CreateObject("roDeviceInfo")
    registrySection = CreateObject("roRegistrySection", "networking")
    net = CreateObject("roNetworkConfiguration", 1)

    deviceInfo = {}

    deviceInfo.UniqueId = player.GetDeviceUniqueId()
    deviceInfo.Model = player.GetModel()
    deviceInfo.UpTime = player.GetDeviceUptime()
    deviceInfo.Firmware = player.GetVersion()
    deviceInfo.BootVersion = player.GetBootVersion()
    deviceInfo.UnitName = registrySection.Read("un")
    deviceInfo.Ip = net.GetCurrentConfig().ip4_address
    deviceInfo.Link = net.GetCurrentConfig().link
	deviceInfo.Channel = ""
	
    if (userVariables.Channel <> invalid) then 
		deviceInfo.Channel = userVariables.Channel.currentValue$ 
	end if

    return deviceInfo

End Function

Function SendDeviceInfo(h as Object) as Object
	
	retval = false

    info = CreateObject("roAssociativeArray")
	
	deviceinfo = newDeviceInfo(h.userVariables)

    info.AddReplace("SerialNumber", deviceinfo.UniqueId)
	info.AddReplace("Model", deviceinfo.Model)
	info.AddReplace("UpTime", deviceinfo.UpTime)
	info.AddReplace("Firmware", deviceinfo.Firmware)
	info.AddReplace("BootVersion", deviceinfo.BootVersion)
    info.AddReplace("Name", deviceinfo.UnitName)
    info.AddReplace("Ip", deviceinfo.Ip)
    info.AddReplace("Link", deviceinfo.Link)
    info.AddReplace("Channel", deviceinfo.Channel)

	DeviceInfo_url=""
	
	if h.userVariables["DeviceInfo_url"]<>invalid
	    DeviceInfo_url = h.userVariables["DeviceInfo_url"].currentValue$
    end if

    if DeviceInfo_url <> ""
        print "@deviceInfoPlugin POST Url :"; DeviceInfo_url
        print "@deviceInfoPlugin POST-ING Device Info..."
		
		xfer = CreateObject("roUrlTransfer") 
        msgPort = CreateObject("roMessagePort")
		xfer.SetPort(msgPort)
		
		xfer.SetUserData("DEVICEINFO_UPLOADED")
		xfer.SetURL(DeviceInfo_url)
        xfer.AddHeader("Content-Type", "application/json")
		
		dataInfo = FormatJson(info)
		
		print dataInfo

		ok = xfer.AsyncPostFromString(dataInfo) 
				
        if ok = false then 
            return false 
        end if

        gotResult = false
        reason = "Unknown"
        responseCode = 0

        while gotResult = false
            msg = wait(0, msgPort)
			if type(msg) = "roUrlEvent" then
				if msg.GetUserData() = "DEVICEINFO_UPLOADED"
					gotResult = true
					reason = msg.GetFailureReason()
					responseCode = msg.GetResponseCode()
				end if
			end if
        end while

        print "@deviceInfoPlugin Response Code: "; responseCode

		if responseCode >= 200 OR responseCode <= 204 then
			print  "@deviceInfoPlugin Successfully POSTed Device Info!"
			retval = true
		else
			print  "@deviceInfoPlugin Cannot POST Device Info!"
            print reason
		endif

	else
	    print  "@deviceInfoPlugin No DeviceInfo_url user variable is defined."
	endif

	return retval
End Function
