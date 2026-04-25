-- BallClient (LocalScript) | StarterPlayerScripts
-- Ball Ч это Part, двигаем через CFrame напр€мую

local RunService = game:GetService("RunService")

local ball = workspace:WaitForChild("Ball", math.huge)

local LERP_SMOOTHNESS = 1  -- 0.85

RunService.RenderStepped:Connect(function(dt)
	local sPos     = ball:GetAttribute("BallPos")
	local tPos     = ball:GetAttribute("TargetPos")
	local velocity = ball:GetAttribute("CurrentVelocity")
	if not sPos or not tPos or not velocity then return end

	local predictedPos = sPos + (velocity * dt)

	local lookAtPos
	local dist = (tPos - predictedPos).Magnitude
	if dist < 0 then
		lookAtPos = predictedPos + ball.CFrame.LookVector
	elseif tPos.Y < predictedPos.Y - 0 then
		lookAtPos = Vector3.new(tPos.X, predictedPos.Y, tPos.Z)
	else
		lookAtPos = tPos
	end

	local targetCF = CFrame.lookAt(predictedPos, lookAtPos)
	local alpha    = math.clamp(LERP_SMOOTHNESS * (dt / (1/20)), 0, 1) -- (dt / (1/60)), 0, 1) or (dt / (1/20)), 0, 50)
	ball.CFrame    = ball.CFrame:Lerp(targetCF, alpha)
end)