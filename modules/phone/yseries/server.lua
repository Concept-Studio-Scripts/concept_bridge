---@diagnostic disable: duplicate-set-field
local resourceName = "yseries"
if GetResourceState(resourceName) ~= 'started' then return end
local PhoneRequests = lib.require('@concept_bridge.lib.security.server.phone')
Phone = Phone or {}

---This will get the name of the Phone system being being used.
---@return string
Phone.GetPhoneName = function()
    return resourceName
end

Phone.GetResourceName = function()
    return resourceName
end

---This will get the phone number of the passed source.
---@param src number
---@return number|boolean
Phone.GetPlayerPhone = function(src)
    return exports.yseries:GetPhoneNumberBySourceId(src) or false
end

---This will send an email to the passed source, email address, title and message.
---@param src number
---@param email string
---@param title string
---@param message string
---@return boolean
local function sendEmail(src, email, title, message, request)
    local phoneNumber = exports.yseries:GetPhoneNumberBySourceId(src)
    if not phoneNumber then return false, print("Could not find phone number for source: " .. tostring(src)) end
    if request and not PhoneRequests.Current(request) then return false end
    -- assuming received is a boolean?
    local _, received = exports.yseries:SendMail({
        title = title,
        sender = email,
        senderDisplayName = email,
        content = message,
    }, 'phoneNumber', phoneNumber)
    return received
end

Phone.SendEmail = function(src, email, title, message)
    return sendEmail(src, email, title, message)
end

RegisterNetEvent('concept_bridge:Server:genericEmail', function(data)
    local src = tonumber(source)
    if not src or src <= 0 or type(data) ~= 'table' then return false end
    return PhoneRequests.Send(src, resourceName, sendEmail, data.email, data.title, data.message)
end)

return Phone