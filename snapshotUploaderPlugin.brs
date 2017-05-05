REM
REM @title               Snapshot Uploader
REM @author              Sabin Maharjan
REM @company	         Port Of Portland
REM @date-created        04/21/2017
REM @date-last-modified  04/26/2017
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
	
    return snapshotUploaderPlugin

End Function

Function snapshotUploaderPlugin_ProcessEvent(event as Object)
    
    retval = false
	
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
