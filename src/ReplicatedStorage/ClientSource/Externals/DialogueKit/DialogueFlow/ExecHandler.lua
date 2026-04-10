-- ExecHandler.lua
-- Exec helpers for dialogue layer functions.

local State = require(script.Parent.Parent.State)

local ExecHandler = {}

function ExecHandler.executeLayerFunction(execData)
	if not execData or not execData.Function then
		return
	end

	local success, err = pcall(execData.Function)
	if not success then
		warn("Error executing dialogue function: " .. tostring(err))
	end
end

function ExecHandler.findExecForContent(contentIndex, timing)
	if not State.currentDialogue or not State.currentLayer then
		return nil
	end

	local layerData = State.currentDialogue.Layers[State.currentLayer]
	if not layerData or not layerData.Exec then
		return nil
	end

	local execsToRun = nil

	for _, execData in pairs(layerData.Exec) do
		if
			(execData.ExecContent == "" or tonumber(execData.ExecContent) == contentIndex)
			and execData.ExecTime == timing
		then
			if not execsToRun then
				execsToRun = {}
			end
			table.insert(execsToRun, execData)
		end
	end

	return execsToRun
end

function ExecHandler.findExecForContinue(contentIndex)
	if not State.currentDialogue or not State.currentLayer then
		return nil
	end

	local layerData = State.currentDialogue.Layers[State.currentLayer]
	if not layerData or not layerData.Exec then
		return nil
	end

	local execsToRun = nil
	local continuePattern = "_continue" .. tostring(contentIndex)

	for _, execData in pairs(layerData.Exec) do
		if execData.ExecContent == continuePattern then
			if not execsToRun then
				execsToRun = {}
			end
			table.insert(execsToRun, execData)
		end
	end

	return execsToRun
end

function ExecHandler.findExecForReply(replyName)
	if not State.currentDialogue or not State.currentLayer then
		return nil
	end

	local layerData = State.currentDialogue.Layers[State.currentLayer]
	if not layerData or not layerData.Exec then
		return nil
	end

	local execsToRun = nil

	for _, execData in pairs(layerData.Exec) do
		if execData.ExecContent == replyName then
			if not execsToRun then
				execsToRun = {}
			end
			table.insert(execsToRun, execData)
		end
	end

	return execsToRun
end

return ExecHandler
