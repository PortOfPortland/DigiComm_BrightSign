REM
REM @title               Snapshot Uploader
REM @author              Sabin Maharjan
REM @company	         Port Of Portland
REM @date-created        04/21/2017
REM @date-last-modified  05/05/2017
REM
REM @description         Uploads Snapshots from BrightSign Device to REST Endpoint
REM

Function snapshotUploaderPlugin_Initialize(msgPort As Object, userVariables As Object, bsp as Object)

    snapshotUploaderPlugin = {}

    snapshotUploaderPlugin.msgPort = msgPort
    snapshotUploaderPlugin.userVariables = userVariables
    snapshotUploaderPlugin.bsp = bsp
    snapshotUploaderPlugin.ProcessEvent = snapshotUploaderPlugin_ProcessEvent
	snapshotUploaderPlugin.snapshotUploadUrl = ""
	snapshotUploaderPlugin.tokenTimer = CreateObject("roTimer")
	snapshotUploaderPlugin.tokenExpire = 1
	snapshotUploaderPlugin.token = "bearer "
	
    
	
	'----- Get user Variable for debug (if any)
	reg = CreateObject("roRegistrySection", "networking")
	
    if userVariables["Enable_Telnet"] <> invalid
	    enable$ = userVariables["Enable_Telnet"].currentValue$
        if LCase(enable$) = "yes"
            reg.write("telnet", "23")
            print "@snapshotUploaderPlugin TELNET Enabled."
        else
            reg.delete("telnet", "23")
            print "@snapshotUploaderPlugin TELNET Disabled."
        end if
    end if
	
	'---- Get Snapshot upload Url
	if userVariables["snapshot_upload_url"]<>invalid then
		snapshotUploaderPlugin.snapshotUploadUrl = userVariables["snapshot_upload_url"].currentValue$
	end if

    '---- Get Player Unit Id and Unit Name
    player = CreateObject("roDeviceInfo")
	
    snapshotUploaderPlugin.unitId = player.GetDeviceUniqueId()
    snapshotUploaderPlugin.unitName = reg.Read("un")

	snapshotUploaderPlugin.userAgent = "BrightSign/" + player.GetDeviceUniqueId() + "/" + player.GetVersion() + " (" + player.GetModel() + ")"
	
	'----- Get Token
	
	snapshotUploaderPlugin.tokenTimer.SetPort(snapshotUploaderPlugin.msgPort)
	
	snapshotUploaderPlugin.tokenTimer.SetUserData("GET_ACCESS_TOKEN")
	
	snapshotUploaderPlugin.tokenTimer.SetElapsed(snapshotUploaderPlugin.tokenExpire , 0)
	
	snapshotUploaderPlugin.tokenTimer.Start()
	
	
    return snapshotUploaderPlugin

End Function

Function snapshotUploaderPlugin_ProcessEvent(event as Object)
    
    retval = false
	
	if type(event) = "roTimerEvent" then
		if event.GetUserData() <> invalid then
			if event.GetUserData() = "GET_ACCESS_TOKEN" then
				print "@snapshotUploaderPlugin Getting Token..."
				STOP
				GetAccessToken(m)
				retval = true
			end if
		end if
	end if
	
	m.tokenTimer.Start()
	
	if type(event) = "roAssociativeArray" then
		if type(event["EventType"]) = "roString" OR type(event["EventType"]) = "String" then
			if event["EventType"] = "SNAPSHOT_CAPTURED" then

                snapshotUploadUrl = m.snapshotUploadUrl
                unitId = m.unitId
				unitName = m.unitName
				snapshotName = event["SnapshotName"]
                filePath = "snapshots/" + snapshotName
                fileSize = 0
					
			    print "@snapshotUploaderPlugin SNAPSHOT filename is :"; snapshotName
				
                '---- Send SnapShot
                if (snapshotUploadUrl <> "" AND unitId <> "" AND unitName <> "") then

                    checkFile = CreateObject("roReadFile", filePath)

                    '---- Get File Size
                    if (checkFile <> invalid) then
                        checkFile.SeekToEnd()
                        fileSize = checkFile.CurrentPosition()
                        checkFile = invalid
                    end if

                    '---- Only Send if File has some Content
                    if fileSize > 0 then
									
                        xfr = CreateObject("roUrlTransfer")
						msgPort = CreateObject("roMessagePort")
						
						xfr.SetUserData("SNAPSHOT_UPLOADED")				
						xfr.SetPort(msgPort)
                        xfr.SetUrl(snapshotUploadUrl + unitId)
						xfr.SetUserAgent(m.userAgent)
						xfr.AddHeader("Content-Length", stri(fileSize))
						xfr.AddHeader("Content-Type", "image/jpeg")
						xfr.AddHeader("unitName", unitName)
						xfr.AddHeader("Authorization", m.token)
						
                        ok = xfr.AsyncPostFromFile(filePath)
						
						if ok = false then 
							return false 
						end if
							
						
						gotResult = false
						reason = "Unknown"
						responseCode = 0
						
						while gotResult = false
							msg = wait(0, msgPort)
							if type(msg) = "roUrlEvent" then
								if msg.GetUserData() = "SNAPSHOT_UPLOADED"
									gotResult = true
									reason = msg.GetFailureReason()
									responseCode = msg.GetResponseCode()
								end if
							end if
						end while
						
						print "@snapshotUploaderPlugin Response Code: "; responseCode

                        if responseCode = 200 then
							
							print "@snapshotUploaderPlugin Successfully Posted the SnapShot "; snapshotName
							retval = true
						else
							print reason
						end if
						
                    else
                        print "@snapshotUploaderPlugin Snapshot is an empty file."
                    end if      
				else
					print "@snapshotUploaderPlugin snapshotUploadUrl OR unitId OR unitName Not Provided."
                end if
			end if
		end if
	end if
		
	return retval

End Function

Function GetAccessToken(h as Object)

	tokenUrl=""
	
	username = ""
	password = ""
	
	if h.userVariables["token_url"]<>invalid
	    tokenUrl = h.userVariables["token_url"].currentValue$
    end if
	
	if h.userVariables["token_user"]<>invalid
	    username = h.userVariables["token_user"].currentValue$
    end if
	
	if h.userVariables["token_password"]<>invalid
	    password = h.userVariables["token_password"].currentValue$
    end if
	
    xfer = CreateObject("roUrlTransfer") 
    msgPort = CreateObject("roMessagePort")

    xfer.SetPort(msgPort)
    xfer.SetUserData("ACCESS_TOKEN_REQUESTED")
    xfer.SetURL(tokenUrl)
    xfer.AddHeader("Content-Type", "application/x-www-form-urlencoded; charset=utf-8")

    aa = {}
	aa.method = "POST"
	aa.request_body_string =  "grant_type=password&username=" + username + "&password=" + password
	aa.response_body_string = true

    ok = xfer.AsyncMethod(aa)

	gotResult = false
	reason = "Unknown"
	responseCode = 0
	responseBody = ""
	
    if ok then 

        while gotResult = false
            msg = wait(0, msgPort)
            if type(msg) = "roUrlEvent" then
                if msg.GetUserData() = "ACCESS_TOKEN_REQUESTED"
                    gotResult = true
                    reason = msg.GetFailureReason()
                    responseCode = msg.GetResponseCode()
					responseBody = msg
                end if
            end if
        end while
		
    end if
	
	if responseCode = 200 then
		print "@snapshotUploaderPlugin  Token Granted Successfully"
		
		jsonObj = ParseJson(responseBody)
		
		h.tokenExpire = jsonObj.expires_in
		h.tokenTimer.SetElapsed(jsonObj.expires_in, 0)
		h.token = jsonObj.token_type + " " + jsonObj.access_token
	else
		print "@snapshotUploaderPlugin  Token Not Granted! Response : "; reason
	end if
	
End Function
