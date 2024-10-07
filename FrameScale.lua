local addonName, AddonNS = ...

FrameParametersOverride = {};

function FrameParametersOverride:OverrideScale(frame, ignoreFile)
    local oldSetScale = frame.SetScale;
    function frame:SetScale(scale)
        local stack = debugstack(2, 1, 0) -- Skip 2 levels to get the caller's stack trace
        if string.find(stack, ignoreFile) then
            scale = frame:GetScale(); -- ignore the change
        end
        scale = scale > 0.75 and 0.75 or scale;
        return oldSetScale(self, scale);
    end
end

FrameParametersOverride:OverrideScale(ContainerFrameCombinedBags, "ContainerFrame.lua")
